import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';

import 'profile_screen.dart';
// Import Service
import 'package:zalo_app/services/firebase_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String receiverName;
  final String receiverAvatarUrl;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.receiverId = '',
    required this.receiverName,
    this.receiverAvatarUrl = '',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  // Khởi tạo Service
  final FirebaseService _firebaseService = FirebaseService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late Stream<QuerySnapshot> _messagesStream;
  bool _isComposing = false;
  late DateTime _viewOpenTime;
  final Set<String> _shownMessageIds = {};

  // Reply & Highlight
  Map<String, dynamic>? _replyMessage;
  String? _highlightMessageId;
  final Map<String, GlobalKey> _messageKeys = {};

  // Animations
  late AnimationController _optionsController;
  late Animation<double> _rotationAnimation;
  late AnimationController _micScaleController;
  late Animation<double> _micScaleAnimation;
  late AnimationController _recordingModeController;
  late Animation<double> _hidePlusBtnAnimation;
  bool _showAttachmentOptions = false;

  // Recorder
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;

  // Timers
  Timer? _heartbeatTimer;
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Set User Online & Start Heartbeat using Service
    _firebaseService.setUserStatus(true);
    _startHeartbeat();

    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });

    _viewOpenTime = DateTime.now();

    // 2. Mark as read using Service
    _firebaseService.markMessagesAsRead(widget.chatId, widget.receiverId);

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _initRecorder();

    // 3. Init Messages Stream using Service
    _messagesStream = _firebaseService.getMessagesStream(widget.chatId);

    _messageController.addListener(() {
      setState(() {
        _isComposing = _messageController.text.isNotEmpty;
      });
    });

    _initAnimations();
  }

  void _initAnimations() {
    _optionsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _optionsController, curve: Curves.easeInOut),
    );

    _micScaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micScaleController, curve: Curves.easeOutBack),
    );

    _recordingModeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _hidePlusBtnAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _recordingModeController, curve: Curves.easeInOutCubic),
    );
  }

  // --- ONLINE STATUS LOGIC ---
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _firebaseService.setUserStatus(true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _firebaseService.setUserStatus(true);
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _firebaseService.setUserStatus(false);
      _heartbeatTimer?.cancel();
    }
  }

  String? _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return null;
    final DateTime time = timestamp.toDate();
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa mới truy cập';
    if (diff.inMinutes < 60) return 'Hoạt động ${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return 'Hoạt động ${diff.inHours} giờ trước';
    return 'Hoạt động ${DateFormat('dd/MM').format(time)}';
  }

  // --- UI WIDGETS ---
  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text: text),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1))],
        ),
        child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87)),
      ),
    );
  }

  Widget _buildEmptyChatView() {
    // 4. Get User Stream using Service
    return StreamBuilder<DocumentSnapshot>(
      stream: _firebaseService.getUserStream(_currentUser!.uid),
      builder: (context, snapshot) {
        bool isFriend = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> friends = userData['friends'] ?? [];
          isFriend = friends.contains(widget.receiverId);
        }

        if (isFriend) {
          return const Center(child: Text('Bắt đầu cuộc trò chuyện', style: TextStyle(color: Colors.grey)));
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text("Nhấn vào tin nhắn để gửi.", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSuggestionChip("Xin chào 👋"),
                    const SizedBox(width: 6),
                    _buildSuggestionChip("Chào ${widget.receiverName}!"),
                    const SizedBox(width: 6),
                    _buildSuggestionChip("Xin chào ${widget.receiverName}!"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _initRecorder() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return;
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
    } catch (e) {
      debugPrint("Lỗi khởi tạo Recorder: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _firebaseService.setUserStatus(false);

    _messageController.dispose();
    _scrollController.dispose();
    _optionsController.dispose();
    _micScaleController.dispose();
    _recordingModeController.dispose();
    _focusNode.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  // --- MESSAGE ACTIONS ---
  void _setReply(Map<String, dynamic> messageData, String messageId) {
    setState(() {
      _replyMessage = {
        'id': messageId,
        'text': messageData['text'] ?? '',
        'type': messageData['type'] ?? 'text',
        'senderId': messageData['senderId'],
        'senderName': messageData['senderId'] == _currentUser!.uid ? 'Bạn' : widget.receiverName,
      };
    });
  }

  void _cancelReply() => setState(() => _replyMessage = null);

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(key.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.5)
          .then((_) => _highlightMessage(messageId));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tin nhắn gốc không còn trong danh sách tải gần đây.')));
    }
  }

  void _highlightMessage(String messageId) {
    setState(() => _highlightMessageId = messageId);
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightMessageId = null);
    });
  }

  // --- HELPERS ---
  bool _isSameDay(DateTime date1, DateTime date2) => date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);
    if (dateToCheck == today) return 'Hôm nay';
    if (dateToCheck == yesterday) return 'Hôm qua';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // --- SENDING LOGIC (REFACTORED) ---

  // 5. Send Message using Service
  void _sendMessage({String? text, String? imageUrl, String type = 'text'}) async {
    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty && imageUrl == null) return;
    if (_currentUser == null) return;

    _messageController.clear();

    // Copy reply object before clearing
    Map<String, dynamic>? replyToSend;
    if (_replyMessage != null) {
      replyToSend = _replyMessage;
      _cancelReply();
    }

    // Call Service
    await _firebaseService.sendMessage(
      chatId: widget.chatId,
      text: messageText,
      imageUrl: imageUrl,
      type: type,
      replyTo: replyToSend,
      receiverId: widget.receiverId,
    );

    _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _startRecording() async {
    try {
      if (!_isRecorderInitialized) {
        await _initRecorder();
        if (!_isRecorderInitialized) return;
      }
      HapticFeedback.heavyImpact();
      _recordingModeController.forward();
      _micScaleController.forward();
      if (_showAttachmentOptions) {
        setState(() => _showAttachmentOptions = false);
        _optionsController.reverse();
      }
      setState(() => _isRecording = true);

      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/flutter_sound_tmp.aac';
      await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
    } catch (e) {
      _stopUIEffects();
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    _stopUIEffects();
    HapticFeedback.lightImpact();

    try {
      final String? path = await _recorder.stopRecorder();
      if (path != null) {
        File audioFile = File(path);
        if (await audioFile.length() > 1000) {
          _uploadAudioFile(audioFile);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ghi âm quá ngắn!')));
        }
      }
    } catch (e) {
      debugPrint("Lỗi dừng ghi âm: $e");
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _stopUIEffects();
    try { await _recorder.stopRecorder(); } catch (_) {}
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy ghi âm')));
  }

  void _stopUIEffects() {
    _recordingModeController.reverse();
    _micScaleController.reverse();
    setState(() => _isRecording = false);
  }

  // 6. Upload Audio using Service
  Future<void> _uploadAudioFile(File file) async {
    String fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    String path = 'chat_audio/${widget.chatId}/$fileName';

    final downloadUrl = await _firebaseService.uploadFileToStorage(file, path, 'audio/aac');

    if (downloadUrl != null) {
      _sendMessage(imageUrl: downloadUrl, type: 'audio');
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi gửi âm thanh')));
    }
  }

  // 7. Upload Image using Service (Data Upload)
  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      String path = 'chat_images/${widget.chatId}/$fileName';

      try {
        final Uint8List bytes = await pickedFile.readAsBytes();
        final downloadUrl = await _firebaseService.uploadDataToStorage(bytes, path, 'image/jpeg');

        if (downloadUrl != null) {
          _sendMessage(imageUrl: downloadUrl, type: 'image');
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi gửi ảnh: $e')));
      }
    }
  }

  // 8. Upload File using Service
  Future<void> _uploadFile(File file) async {
    String originalFileName = file.path.split(Platform.pathSeparator).last;
    String uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
    String path = 'chat_files/${widget.chatId}/$uniqueFileName';

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang gửi tập tin...'), duration: Duration(milliseconds: 1000)));

    final downloadUrl = await _firebaseService.uploadFileToStorage(file, path, 'application/octet-stream'); // Generic content type

    if (downloadUrl != null) {
      _sendMessage(text: originalFileName, imageUrl: downloadUrl, type: 'file');
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi gửi file')));
    }
  }

  void _showFilePickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              children: [
                Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(5))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text("Chọn tập tin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InAppFileExplorer(
                    scrollController: scrollController,
                    onFileSelected: (file) { Navigator.pop(context); _uploadFile(file); },
                    onSystemPickerRequest: () async {
                      Navigator.pop(context);
                      try {
                        FilePickerResult? result = await FilePicker.platform.pickFiles();
                        if (result != null) _uploadFile(File(result.files.single.path!));
                      } catch (e) { debugPrint("Lỗi mở picker: $e"); }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMessageOptions(BuildContext context, GlobalKey bubbleKey, String messageId, Map<String, dynamic> messageData, bool isMe, MessagePosition position, bool showTime) {
    final RenderBox? renderBox = bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final Size size = renderBox.size;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MessageOptionsOverlay(
            chatId: widget.chatId,
            messageId: messageId,
            messageData: messageData,
            isMe: isMe,
            position: position,
            showTime: showTime,
            originalOffset: offset,
            originalSize: size,
            onReply: () { _setReply(messageData, messageId); Navigator.pop(context); },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: Text(_formatDateHeader(date), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC6E7FF),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: BackgroundWavePainter())),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildMessageList()),
                _buildMessageComposer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFFC6E7FF),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(4, 4)),
          BoxShadow(color: Colors.white.withOpacity(0.7), blurRadius: 10, offset: const Offset(-4, -4)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Image.asset('assets/icon/turn-back_9678505.png', width: 30, height: 30, fit: BoxFit.contain),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[200],
            backgroundImage: widget.receiverAvatarUrl.isNotEmpty ? NetworkImage(widget.receiverAvatarUrl) : null,
            child: widget.receiverAvatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.receiverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                // 9. User Stream for Header Status
                StreamBuilder<DocumentSnapshot>(
                  stream: _firebaseService.getUserStream(widget.receiverId),
                  builder: (context, receiverSnapshot) {
                    String statusText = "";
                    Color statusColor = Colors.grey;
                    bool showStatus = false;

                    if (receiverSnapshot.hasData && receiverSnapshot.data!.exists) {
                      final data = receiverSnapshot.data!.data() as Map<String, dynamic>;
                      final isOnline = data['isOnline'] ?? false;
                      final lastActive = data['lastActive'] as Timestamp?;

                      if (isOnline) {
                        statusText = "Đang hoạt động";
                        statusColor = Colors.green;
                        showStatus = true;
                      } else {
                        final timeAgo = _formatTimeAgo(lastActive);
                        if (timeAgo != null) {
                          statusText = timeAgo;
                          statusColor = Colors.grey;
                          if (statusText == 'Vừa mới truy cập') statusColor = Colors.green;
                          showStatus = true;
                        }
                      }
                    }

                    // Nested Stream: Check Friend Status
                    return StreamBuilder<DocumentSnapshot>(
                      stream: _firebaseService.getUserStream(_currentUser!.uid),
                      builder: (context, userSnapshot) {
                        bool isFriend = true;
                        bool isUserLoaded = userSnapshot.hasData && userSnapshot.data!.exists;
                        if (isUserLoaded) {
                          final myData = userSnapshot.data!.data() as Map<String, dynamic>;
                          final friends = myData['friends'] ?? [];
                          isFriend = friends.contains(widget.receiverId);
                        }

                        if (isUserLoaded && !isFriend) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                            child: const Text("NGƯỜI LẠ", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          );
                        }

                        if (showStatus) {
                          return Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle), margin: const EdgeInsets.only(right: 4)),
                              Flexible(child: Text(statusText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: statusColor == Colors.green ? FontWeight.w500 : FontWeight.normal))),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(icon: Image.asset('assets/icon/calling.png', width: 28, height: 28, fit: BoxFit.contain), iconSize: 28, padding: const EdgeInsets.all(8.0), constraints: const BoxConstraints(), onPressed: () {}),
          IconButton(icon: Image.asset('assets/icon/video (2).png', width: 30, height: 30, fit: BoxFit.contain), iconSize: 28, padding: const EdgeInsets.all(8.0), constraints: const BoxConstraints(), onPressed: () {}),
          IconButton(
            icon: Image.asset('assets/icon/list.png', width: 30, height: 30, fit: BoxFit.contain),
            iconSize: 28,
            padding: const EdgeInsets.all(8.0),
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatOptionsScreen(chatId: widget.chatId, receiverId: widget.receiverId, receiverName: widget.receiverName, receiverAvatarUrl: widget.receiverAvatarUrl)));
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('Lỗi tải tin nhắn'));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyChatView();

        final allDocs = snapshot.data!.docs;

        // Auto mark read if unread messages exist
        final unreadFromOther = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['senderId'] == widget.receiverId && (data['isRead'] == false || data['isRead'] == null);
        }).toList();

        if (unreadFromOther.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _firebaseService.markMessagesAsRead(widget.chatId, widget.receiverId);
          });
        }

        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final deletedBy = List<String>.from(data['deletedBy'] ?? []);
          return !deletedBy.contains(_currentUser!.uid);
        }).toList();

        if (docs.isEmpty) return _buildEmptyChatView();

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final messageDoc = docs[index];
            final messageData = messageDoc.data() as Map<String, dynamic>;
            final isMe = messageData['senderId'] == _currentUser!.uid;
            final Timestamp? timestamp = messageData['timestamp'];
            final DateTime messageDate = timestamp?.toDate() ?? DateTime.now();
            final String messageId = messageDoc.id;

            if (!_messageKeys.containsKey(messageId)) _messageKeys[messageId] = GlobalKey();

            MessageAnimationType animType = MessageAnimationType.none;
            if (!_shownMessageIds.contains(messageId)) {
              _shownMessageIds.add(messageId);
              bool isNew = timestamp == null || timestamp.toDate().isAfter(_viewOpenTime);
              if (isMe && isNew) animType = MessageAnimationType.push;
              else animType = MessageAnimationType.fade;
            }

            bool showDateHeader = false;
            if (index == docs.length - 1) {
              showDateHeader = true;
            } else {
              final nextDoc = docs[index + 1];
              final nextData = nextDoc.data() as Map<String, dynamic>;
              final Timestamp? nextTimestamp = nextData['timestamp'];
              if (nextTimestamp != null) {
                if (!_isSameDay(messageDate, nextTimestamp.toDate())) showDateHeader = true;
              }
            }

            bool showTime = true;
            bool isSameAsOlder = false;
            bool isSameAsNewer = false;

            if (index < docs.length - 1) {
              final prevDoc = docs[index + 1];
              final prevData = prevDoc.data() as Map<String, dynamic>;
              final Timestamp? prevTimestamp = prevData['timestamp'];
              final String prevSenderId = prevData['senderId'];
              final DateTime currentTime = timestamp?.toDate() ?? DateTime.now();
              if (prevTimestamp != null) {
                final difference = currentTime.difference(prevTimestamp.toDate()).inMinutes;
                if (difference < 5 && _isSameDay(currentTime, prevTimestamp.toDate())) {
                  showTime = false;
                  if (prevSenderId == messageData['senderId']) isSameAsOlder = true;
                }
              }
            }

            if (index > 0) {
              final nextDoc = docs[index - 1];
              final nextData = nextDoc.data() as Map<String, dynamic>;
              final Timestamp? nextTimestamp = nextData['timestamp'];
              final String nextSenderId = nextData['senderId'];
              final DateTime nextTime = nextTimestamp?.toDate() ?? DateTime.now();
              final DateTime currentTime = timestamp?.toDate() ?? DateTime.now();
              final difference = nextTime.difference(currentTime).inMinutes;
              if (difference < 5 && nextSenderId == messageData['senderId'] && _isSameDay(nextTime, currentTime)) isSameAsNewer = true;
            }

            MessagePosition position = MessagePosition.single;
            if (!isSameAsOlder && !isSameAsNewer) position = MessagePosition.single;
            else if (!isSameAsOlder && isSameAsNewer) position = MessagePosition.top;
            else if (isSameAsOlder && isSameAsNewer) position = MessagePosition.middle;
            else if (isSameAsOlder && !isSameAsNewer) position = MessagePosition.bottom;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDateHeader) _buildDateHeader(messageDate),
                MessageBubble(
                  key: _messageKeys[messageId],
                  messageId: messageId,
                  messageData: messageData,
                  isMe: isMe,
                  animationType: animType,
                  showTime: showTime,
                  position: position,
                  isHighlighted: _highlightMessageId == messageId,
                  onReplyTap: (originalId) => _scrollToMessage(originalId),
                  onLongPress: (key) => _showMessageOptions(context, key, messageId, messageData, isMe, position, showTime),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMessageComposer() {
    bool isFocused = _focusNode.hasFocus;
    return SafeArea(
      child: Column(
        children: [
          if (_replyMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
              child: Row(
                children: [
                  Container(width: 4, height: 35, color: const Color(0xFF0078FF), margin: const EdgeInsets.only(right: 10)),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Đang trả lời ${_replyMessage!['senderName']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0078FF))),
                    Text(_replyMessage!['type'] == 'text' ? _replyMessage!['text'] : '[Đính kèm]', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                  ])),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: _cancelReply)
                ],
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red.shade50 : Colors.white,
              borderRadius: _replyMessage != null ? const BorderRadius.vertical(bottom: Radius.circular(35)) : BorderRadius.circular(35),
              boxShadow: [
                if (isFocused && !_isRecording) BoxShadow(color: const Color(0xFF0078FF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 4), spreadRadius: 2)
                else BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
              border: _isRecording ? Border.all(color: Colors.red.shade200, width: 2) : (isFocused ? Border.all(color: const Color(0xFF0078FF), width: 2) : Border.all(color: Colors.transparent, width: 2)),
            ),
            child: Row(
              children: <Widget>[
                SizeTransition(
                  sizeFactor: _hidePlusBtnAnimation,
                  axis: Axis.horizontal,
                  axisAlignment: -1.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotationTransition(
                        turns: _rotationAnimation,
                        child: IconButton(
                          icon: Image.asset('assets/icon/plus-button_7904207.png', width: 30, height: 30, fit: BoxFit.contain),
                          iconSize: 30,
                          color: const Color(0xFF0078FF),
                          onPressed: () {
                            setState(() => _showAttachmentOptions = !_showAttachmentOptions);
                            if (_optionsController.isCompleted) _optionsController.reverse(); else _optionsController.forward();
                          },
                        ),
                      ),
                      SizeTransition(
                        sizeFactor: CurvedAnimation(parent: _optionsController, curve: Curves.easeOut),
                        axis: Axis.horizontal,
                        axisAlignment: -1.0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Image.asset('assets/icon/Gallery (1).png', width: 30, height: 30, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 30, color: Color(0xFF0078FF))),
                              iconSize: 30,
                              onPressed: _sendImage,
                            ),
                            IconButton(
                              icon: Image.asset('assets/icon/folder.png', width: 30, height: 30, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.attach_file, size: 30, color: Color(0xFF0078FF))),
                              iconSize: 30,
                              onPressed: _showFilePickerSheet,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _optionsController,
                  builder: (context, child) {
                    final value = CurvedAnimation(parent: _optionsController, curve: Curves.easeOut).value;
                    final factor = 1.0 - value;
                    if (factor <= 0) return const SizedBox.shrink();
                    return Align(alignment: Alignment.centerLeft, widthFactor: factor, child: Opacity(opacity: factor, child: child));
                  },
                  child: ScaleTransition(
                    scale: _micScaleAnimation,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () { ScaffoldMessenger.of(context).hideCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hãy NHẤN GIỮ để ghi âm 🎤'), duration: Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating)); },
                      onLongPress: _startRecording,
                      onLongPressUp: _stopAndSendRecording,
                      onLongPressCancel: _cancelRecording,
                      child: Container(
                        padding: const EdgeInsets.all(4.0),
                        child: Transform.scale(
                          scale: 2.0,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) => ScaleTransition(scale: animation, child: child),
                            child: _isRecording
                                ? Lottie.asset('assets/lottie/voice icon lottie animation (1).json', key: const ValueKey('LottieIcon'), width: 35, height: 35, fit: BoxFit.contain)
                                : Lottie.asset('assets/lottie/voice icon lottie animation (1).json', key: const ValueKey('StaticIcon'), width: 35, height: 35, fit: BoxFit.contain, animate: false),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: _isRecording
                        ? Row(children: [const Icon(Icons.graphic_eq, color: Colors.red), const SizedBox(width: 8), const Text('Đang ghi âm...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), Text('Thả để gửi', style: TextStyle(color: Colors.red.withOpacity(0.6), fontSize: 12))])
                        : TextField(controller: _messageController, focusNode: _focusNode, style: const TextStyle(fontSize: 16), decoration: const InputDecoration.collapsed(hintText: 'Tin nhắn...'), textCapitalization: TextCapitalization.sentences, onSubmitted: (_) => _sendMessage()),
                  ),
                ),
                if (!_isRecording)
                  IconButton(
                    icon: _isComposing ? Image.asset('assets/icon/paper-airplane_2644928.png', width: 38, height: 38, fit: BoxFit.contain) : Image.asset('assets/icon/like_4408732.png', width: 38, height: 38, fit: BoxFit.contain),
                    iconSize: 30,
                    color: const Color(0xFF0078FF),
                    onPressed: () {
                      if (_isComposing) _sendMessage(); else _sendMessage(imageUrl: 'assets/icon/like_4408732.png', type: 'sticker');
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width, size.height * 0.5)..cubicTo(size.width * 0.75, size.height * 0.5 + 40, size.width * 0.25, size.height * 0.5 - 40, 0, size.height * 0.5)..lineTo(0, 0)..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum MessageAnimationType { none, fade, push }
enum MessagePosition { single, top, middle, bottom }

class MessageBubble extends StatefulWidget {
  final String messageId;
  final Map<String, dynamic> messageData;
  final bool isMe;
  final MessageAnimationType animationType;
  final bool showTime;
  final MessagePosition position;
  final Function(GlobalKey) onLongPress;
  final bool isHighlighted;
  final Function(String) onReplyTap;

  const MessageBubble({
    super.key,
    required this.messageId,
    required this.messageData,
    required this.isMe,
    this.animationType = MessageAnimationType.none,
    this.showTime = true,
    this.position = MessagePosition.single,
    required this.onLongPress,
    this.isHighlighted = false,
    required this.onReplyTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _highlightController;
  late Animation<Color?> _highlightAnimation;
  final GlobalKey _bubbleKey = GlobalKey();
  bool _animateReaction = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _highlightController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _highlightAnimation = ColorTween(begin: Colors.transparent, end: Colors.grey.withOpacity(0.5)).animate(CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut));
    _highlightController.addStatusListener((status) { if(status == AnimationStatus.completed) _highlightController.reverse(); });

    if (widget.animationType == MessageAnimationType.push) {
      _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
      _controller.forward();
    } else if (widget.animationType == MessageAnimationType.fade) {
      _scaleAnimation = ConstantTween<double>(1.0).animate(_controller);
      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
      _controller.forward();
    } else {
      _scaleAnimation = ConstantTween<double>(1.0).animate(_controller);
      _fadeAnimation = ConstantTween<double>(1.0).animate(_controller);
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) _highlightController.forward();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final oldReactions = Map<String, dynamic>.from(oldWidget.messageData['reactions'] ?? {});
      final newReactions = Map<String, dynamic>.from(widget.messageData['reactions'] ?? {});
      if (oldReactions[currentUser.uid] != newReactions[currentUser.uid] && newReactions[currentUser.uid] != null) _animateReaction = true; else _animateReaction = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _highlightController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: widget.isMe ? Alignment.bottomRight : Alignment.bottomLeft,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Align(
              alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: GestureDetector(
                onLongPress: () => widget.onLongPress(_bubbleKey),
                child: MessageBubbleContent(
                  key: _bubbleKey,
                  messageData: widget.messageData,
                  isMe: widget.isMe,
                  showTime: widget.showTime,
                  position: widget.position,
                  animateReaction: _animateReaction,
                  onReplyTap: widget.onReplyTap,
                  highlightColor: _highlightAnimation.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MessageBubbleContent extends StatelessWidget {
  final Map<String, dynamic> messageData;
  final bool isMe;
  final bool showTime;
  final MessagePosition position;
  final bool animateReaction;
  final Function(String) onReplyTap;
  final Color? highlightColor;

  const MessageBubbleContent({super.key, required this.messageData, required this.isMe, this.showTime = true, required this.position, this.animateReaction = false, required this.onReplyTap, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    final Timestamp? timestamp = messageData['timestamp'];
    final DateTime displayTime = timestamp != null ? timestamp.toDate() : DateTime.now();
    final String timeString = DateFormat('HH:mm').format(displayTime);
    final bool isRead = messageData['isRead'] ?? false;
    final type = messageData['type'] ?? 'text';
    final bool isSticker = type == 'sticker';
    final bubbleColor = isSticker ? Colors.transparent : (isMe ? const Color(0xFF64B5F6) : Colors.white);
    final textColor = isMe ? Colors.white : Colors.black;
    Color finalBubbleColor = bubbleColor;
    if (highlightColor != null && highlightColor != Colors.transparent) finalBubbleColor = Color.alphaBlend(highlightColor!, bubbleColor);
    final String? imageUrl = messageData['imageUrl'];
    final Map<String, dynamic>? replyData = messageData['replyTo'] != null ? Map<String, dynamic>.from(messageData['replyTo']) : null;
    final Map<String, dynamic> reactions = messageData['reactions'] != null ? Map<String, dynamic>.from(messageData['reactions']) : {};

    BorderRadius borderRadius;
    EdgeInsets margin;
    const double standardMargin = 8.0, tightMargin = 2.0, bubbleRadius = 26.0, sharpRadius = 4.0;
    double bottomMarginAdd = reactions.isNotEmpty ? 10.0 : 0.0;

    switch (position) {
      case MessagePosition.single: margin = EdgeInsets.only(top: standardMargin, bottom: standardMargin + bottomMarginAdd); break;
      case MessagePosition.top: margin = EdgeInsets.only(top: standardMargin, bottom: tightMargin + bottomMarginAdd); break;
      case MessagePosition.middle: margin = EdgeInsets.only(top: tightMargin, bottom: tightMargin + bottomMarginAdd); break;
      case MessagePosition.bottom: margin = EdgeInsets.only(top: tightMargin, bottom: standardMargin + bottomMarginAdd); break;
    }

    if (isMe) {
      switch (position) {
        case MessagePosition.single: borderRadius = const BorderRadius.only(topLeft: Radius.circular(bubbleRadius), topRight: Radius.circular(bubbleRadius), bottomLeft: Radius.circular(bubbleRadius), bottomRight: Radius.zero); break;
        case MessagePosition.top: borderRadius = const BorderRadius.only(topLeft: Radius.circular(bubbleRadius), topRight: Radius.circular(bubbleRadius), bottomLeft: Radius.circular(bubbleRadius), bottomRight: Radius.zero); break;
        case MessagePosition.middle: borderRadius = const BorderRadius.only(topLeft: Radius.circular(bubbleRadius), topRight: Radius.circular(sharpRadius), bottomLeft: Radius.circular(bubbleRadius), bottomRight: Radius.circular(sharpRadius)); break;
        case MessagePosition.bottom: borderRadius = const BorderRadius.only(topLeft: Radius.circular(bubbleRadius), topRight: Radius.zero, bottomLeft: Radius.circular(bubbleRadius), bottomRight: Radius.circular(bubbleRadius)); break;
      }
    } else {
      switch (position) {
        case MessagePosition.single: borderRadius = const BorderRadius.only(topLeft: Radius.circular(bubbleRadius), topRight: Radius.circular(bubbleRadius), bottomLeft: Radius.zero, bottomRight: Radius.circular(bubbleRadius)); break;
        case MessagePosition.top: borderRadius = const BorderRadius.only(topLeft: Radius.circular(bubbleRadius), topRight: Radius.circular(bubbleRadius), bottomLeft: Radius.zero, bottomRight: Radius.circular(bubbleRadius)); break;
        case MessagePosition.middle: borderRadius = const BorderRadius.only(topLeft: Radius.circular(sharpRadius), topRight: Radius.circular(bubbleRadius), bottomLeft: Radius.circular(sharpRadius), bottomRight: Radius.circular(bubbleRadius)); break;
        case MessagePosition.bottom: borderRadius = const BorderRadius.only(topLeft: Radius.zero, topRight: Radius.circular(bubbleRadius), bottomLeft: Radius.circular(bubbleRadius), bottomRight: Radius.circular(bubbleRadius)); break;
      }
    }

    Widget content;
    if (type == 'image' && imageUrl != null) content = ClipRRect(borderRadius: borderRadius, child: Image.network(imageUrl, fit: BoxFit.cover));
    else if (type == 'audio' && imageUrl != null) content = AudioPlayerWidget(audioUrl: imageUrl, isMe: isMe);
    else if (type == 'file' && imageUrl != null) content = _buildFileContent(messageData['text'], imageUrl, isMe, textColor);
    else if (type == 'sticker' && imageUrl != null) content = Image.asset(imageUrl, width: 120, height: 120, fit: BoxFit.contain);
    else content = Text(messageData['text'] ?? '', style: TextStyle(color: textColor, fontSize: 18));

    Widget? replyWidget;
    if (replyData != null) {
      replyWidget = GestureDetector(
        onTap: () { if (replyData['id'] != null) onReplyTap(replyData['id']); },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.reply, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(isMe ? 'Bạn đã trả lời ${replyData['senderName']}' : '${replyData['senderName']} đã trả lời', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: Text(replyData['type'] == 'text' ? replyData['text'] : '[Đính kèm]', style: const TextStyle(color: Colors.black54, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (replyWidget != null) replyWidget,
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMe && showTime) ...[Text(timeString, style: const TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(width: 4), Icon(isRead ? Icons.done_all : Icons.check, size: 16, color: isRead ? Colors.blue : Colors.grey), const SizedBox(width: 4)],
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: finalBubbleColor,
                      borderRadius: borderRadius,
                      border: (isMe || isSticker) ? null : Border.all(color: Colors.black, width: 1.0),
                      boxShadow: isSticker ? [] : [BoxShadow(color: isMe ? const Color(0xFF64B5F6).withOpacity(0.4) : Colors.black.withOpacity(0.15), blurRadius: 3, offset: const Offset(1, 2))],
                    ),
                    child: Padding(padding: (type == 'text' && !isSticker) ? const EdgeInsets.symmetric(horizontal: 22, vertical: 14) : const EdgeInsets.all(0), child: content),
                  ),
                  if (reactions.isNotEmpty) Positioned(bottom: -12, right: isMe ? null : -4, left: isMe ? -4 : null, child: ReactionAnimation(reactions: reactions, animate: animateReaction)),
                ],
              ),
              if (!isMe && showTime) ...[const SizedBox(width: 4), Text(timeString, style: const TextStyle(color: Colors.grey, fontSize: 11))],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileContent(String? text, String imageUrl, bool isMe, Color textColor) {
    return GestureDetector(
      onTap: () async {
        final Uri url = Uri.parse(imageUrl);
        try { if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication); } catch (e) { debugPrint('Error launching url: $e'); }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        width: 280,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[200], shape: BoxShape.circle), child: Icon(Icons.insert_drive_file, color: isMe ? Colors.white : Colors.blue, size: 24)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(text ?? 'File đính kèm', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis), Text('Nhấn để mở', style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 11, fontStyle: FontStyle.italic))])),
          ],
        ),
      ),
    );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  const AudioPlayerWidget({super.key, required this.audioUrl, required this.isMe});
  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) { if (mounted) setState(() => _isPlaying = state == ap.PlayerState.playing); });
    _audioPlayer.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
    _audioPlayer.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
  }

  @override
  void dispose() { _audioPlayer.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: widget.isMe ? Colors.white : Colors.blue, size: 35),
            onPressed: () async { if (_isPlaying) await _audioPlayer.pause(); else await _audioPlayer.play(ap.UrlSource(widget.audioUrl)); },
          ),
          Expanded(child: SliderTheme(data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 3, thumbColor: widget.isMe ? Colors.white : Colors.blue, activeTrackColor: widget.isMe ? Colors.white.withOpacity(0.8) : Colors.blueAccent, inactiveTrackColor: widget.isMe ? Colors.white.withOpacity(0.3) : Colors.grey[300]), child: Slider(min: 0, max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0, value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0), onChanged: (value) async { final position = Duration(seconds: value.toInt()); await _audioPlayer.seek(position); }))),
          Text("${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}", style: TextStyle(color: widget.isMe ? Colors.white70 : Colors.grey[600], fontSize: 10)),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class ReactionAnimation extends StatefulWidget {
  final Map<String, dynamic> reactions;
  final bool animate;
  const ReactionAnimation({super.key, required this.reactions, this.animate = false});
  @override
  State<ReactionAnimation> createState() => _ReactionAnimationState();
}

class _ReactionAnimationState extends State<ReactionAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _translateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _scaleAnimation = TweenSequence<double>([TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.5).chain(CurveTween(curve: Curves.easeOut)), weight: 40), TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 60)]).animate(_controller);
    _translateAnimation = TweenSequence<double>([TweenSequenceItem(tween: Tween(begin: 0.0, end: -20.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40), TweenSequenceItem(tween: Tween(begin: -20.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 60)]).animate(_controller);
    if (widget.animate) _controller.forward(); else _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant ReactionAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) { _controller.reset(); _controller.forward(); }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(offset: Offset(0, _translateAnimation.value), child: Transform.scale(scale: _scaleAnimation.value, alignment: Alignment.bottomCenter, child: child)),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    final reactionCounts = <String, int>{};
    widget.reactions.forEach((_, emoji) { reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1; });
    final sortedReactions = reactionCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final displayReactions = sortedReactions.take(3).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: displayReactions.map((entry) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2.0), child: Text('${entry.key}${entry.value > 1 ? ' ${entry.value}' : ''}', style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500)))).toList(),
      ),
    );
  }
}

class MessageOptionsOverlay extends StatefulWidget {
  final String chatId;
  final String messageId;
  final Map<String, dynamic> messageData;
  final bool isMe;
  final MessagePosition position;
  final bool showTime;
  final Offset originalOffset;
  final Size originalSize;
  final VoidCallback onReply;

  const MessageOptionsOverlay({super.key, required this.chatId, required this.messageId, required this.messageData, required this.isMe, required this.position, required this.showTime, required this.originalOffset, required this.originalSize, required this.onReply});

  @override
  State<MessageOptionsOverlay> createState() => _MessageOptionsOverlayState();
}

class _MessageOptionsOverlayState extends State<MessageOptionsOverlay> {
  final _firebaseService = FirebaseService();
  bool _showDeleteOptions = false;

  // 10. Toggle Reaction using Service
  Future<void> _toggleReaction(String emoji) async {
    // [EDITED] Đóng menu NGAY LẬP TỨC để người dùng thấy animation bên dưới
    if (mounted) Navigator.pop(context);

    // Sau đó mới gọi Firebase cập nhật (chạy ngầm)
    final currentReactions = Map<String, dynamic>.from(widget.messageData['reactions'] ?? {});
    await _firebaseService.toggleReaction(widget.chatId, widget.messageId, emoji, currentReactions);
  }

  // 11. Unsend using Service
  Future<void> _unsendForEveryone() async {
    Navigator.pop(context);
    await _firebaseService.unsendMessage(widget.chatId, widget.messageId);
  }

  // 12. Delete for me using Service
  Future<void> _deleteForMe() async {
    Navigator.pop(context);
    await _firebaseService.deleteMessageForMe(widget.chatId, widget.messageId);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final paddingTop = MediaQuery.of(context).padding.top;
    double bubbleTop = widget.originalOffset.dy;
    double bubbleLeft = widget.originalOffset.dx;
    const double reactionBarHeight = 60, gap = 8;
    double contextMenuHeight = _showDeleteOptions ? 160 : 230;
    double menuBottom = bubbleTop + widget.originalSize.height + gap + contextMenuHeight;
    double safeBottom = screenHeight - paddingBottom - 20;
    double verticalShift = 0;
    if (menuBottom > safeBottom) verticalShift = menuBottom - safeBottom;
    double proposedBubbleTop = bubbleTop - verticalShift;
    double reactionTop = proposedBubbleTop - reactionBarHeight - gap;
    if (reactionTop < paddingTop + 10) verticalShift -= ((paddingTop + 10) - reactionTop);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: verticalShift),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, animatedShift, child) {
        double currentBubbleTop = bubbleTop - animatedShift;
        double currentReactionTop = currentBubbleTop - reactionBarHeight - gap;
        double currentMenuTop = currentBubbleTop + widget.originalSize.height + gap;
        return Stack(
          children: [
            GestureDetector(onTap: () => Navigator.of(context).pop(), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.2)))),
            Positioned(top: currentBubbleTop, left: bubbleLeft, child: Material(color: Colors.transparent, child: MessageBubbleContent(messageData: widget.messageData, isMe: widget.isMe, showTime: widget.showTime, position: widget.position, onReplyTap: (id) {}))),
            Positioned(top: currentReactionTop, left: widget.isMe ? null : bubbleLeft, right: widget.isMe ? (screenWidth - (bubbleLeft + widget.originalSize.width)) : null, child: _buildReactionBar(context)),
            Positioned(top: currentMenuTop, left: widget.isMe ? null : bubbleLeft, right: widget.isMe ? (screenWidth - (bubbleLeft + widget.originalSize.width)) : null, child: _buildContextMenu(context)),
          ],
        );
      },
    );
  }

  Widget _buildReactionBar(BuildContext context) {
    final List<String> reactions = ['❤️', '😆', '😮', '😢', '😡', '👍'];
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(30)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...reactions.map((e) => GestureDetector(onTap: () => _toggleReaction(e), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(e, style: const TextStyle(fontSize: 24))))),
            const SizedBox(width: 8),
            Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)), child: const Icon(Icons.add, color: Colors.white, size: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenu(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Container(
          width: 220,
          decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: _showDeleteOptions ? _buildDeleteMenu() : _buildMainMenu()),
        ),
      ),
    );
  }

  Widget _buildMainMenu() {
    return Column(
      key: const ValueKey('MainMenu'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMenuItem(Icons.reply, 'Trả lời', widget.onReply),
        const Divider(height: 1, color: Colors.grey, thickness: 0.2),
        _buildMenuItem(Icons.copy, 'Sao chép', () { if (widget.messageData['text'] != null) { Clipboard.setData(ClipboardData(text: widget.messageData['text'])); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép'))); } }),
        const Divider(height: 1, color: Colors.grey, thickness: 0.2),
        _buildMenuItem(Icons.translate, 'Dịch', () {}),
        const Divider(height: 1, color: Colors.grey, thickness: 0.2),
        _buildMenuItem(Icons.more_horiz, 'Khác', () { setState(() { _showDeleteOptions = true; }); }, showArrow: true),
      ],
    );
  }

  Widget _buildDeleteMenu() {
    return Column(
      key: const ValueKey('DeleteMenu'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isMe) ...[_buildMenuItem(Icons.delete_forever, 'Thu hồi', _unsendForEveryone, color: Colors.redAccent), const Divider(height: 1, color: Colors.grey, thickness: 0.2)],
        _buildMenuItem(Icons.delete_outline, 'Xoá ở phía tôi', _deleteForMe),
        const Divider(height: 1, color: Colors.grey, thickness: 0.2),
        InkWell(onTap: () { setState(() { _showDeleteOptions = false; }); }, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, child: const Text("Huỷ", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)))),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white, bool showArrow = false}) {
    return InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: color, fontSize: 16)), Row(children: [Icon(icon, color: color, size: 20), if (showArrow) ...[const SizedBox(width: 5), const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12)]])])));
  }
}

class InAppFileExplorer extends StatefulWidget {
  final ScrollController scrollController;
  final Function(File) onFileSelected;
  final VoidCallback onSystemPickerRequest;
  const InAppFileExplorer({super.key, required this.scrollController, required this.onFileSelected, required this.onSystemPickerRequest});
  @override
  State<InAppFileExplorer> createState() => _InAppFileExplorerState();
}

class _InAppFileExplorerState extends State<InAppFileExplorer> {
  Directory? _currentDir;
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() { super.initState(); _initDirectory(); }

  Future<void> _initDirectory() async {
    var status = await Permission.storage.status;
    var manageStatus = await Permission.manageExternalStorage.status;
    if (!status.isGranted && !manageStatus.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) manageStatus = await Permission.manageExternalStorage.request();
    }

    if (status.isGranted || manageStatus.isGranted) {
      Directory? rootDir = Platform.isAndroid ? Directory('/storage/emulated/0') : await getApplicationDocumentsDirectory();
      if (rootDir != null) _changeDirectory(rootDir); else setState(() { _isLoading = false; _errorMessage = 'Không tìm thấy bộ nhớ thiết bị.'; });
    } else {
      setState(() { _isLoading = false; _errorMessage = 'Ứng dụng chưa có quyền truy cập bộ nhớ.\nHãy cấp quyền trong Cài đặt.'; });
    }
  }

  void _changeDirectory(Directory dir) {
    setState(() { _isLoading = true; _currentDir = dir; _errorMessage = ''; });
    try {
      final files = dir.listSync()..sort((a, b) { bool aIsDir = FileSystemEntity.isDirectorySync(a.path); bool bIsDir = FileSystemEntity.isDirectorySync(b.path); if (aIsDir && !bIsDir) return -1; if (!aIsDir && bIsDir) return 1; return a.path.compareTo(b.path); });
      setState(() { _files = files; _isLoading = false; });
    } catch (e) { setState(() { _isLoading = false; _errorMessage = 'Không thể mở thư mục này (Bị từ chối quyền).\nHãy dùng Thư viện hệ thống.'; }); }
  }

  void _goBack() {
    if (_currentDir == null) return;
    final parent = _currentDir!.parent;
    if (parent.path == '/storage/emulated' || parent.path == '/') return;
    _changeDirectory(parent);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty) return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 16)), const SizedBox(height: 20), ElevatedButton(onPressed: () => openAppSettings(), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), child: const Text("Cấp quyền trong Cài đặt")), const SizedBox(height: 12), ElevatedButton.icon(onPressed: widget.onSystemPickerRequest, icon: const Icon(Icons.folder_open), label: const Text("Mở Thư viện Hệ thống"), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), backgroundColor: Colors.white, foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue))), const SizedBox(height: 12), TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy bỏ", style: TextStyle(color: Colors.grey)))])));

    return Column(
      children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.grey[100], child: Row(children: [if (_currentDir != null && _currentDir!.path != '/storage/emulated/0') IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack, padding: EdgeInsets.zero, constraints: const BoxConstraints()), const SizedBox(width: 8), Expanded(child: Text(_currentDir?.path.split('/').last ?? 'Bộ nhớ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis)), TextButton(onPressed: widget.onSystemPickerRequest, child: const Text("Hệ thống", style: TextStyle(fontSize: 12)))])),
        Expanded(child: ListView.separated(controller: widget.scrollController, itemCount: _files.length, separatorBuilder: (ctx, i) => const Divider(height: 1), itemBuilder: (context, index) { final entity = _files[index]; final isDir = FileSystemEntity.isDirectorySync(entity.path); final name = entity.path.split('/').last; if (name.startsWith('.')) return const SizedBox.shrink(); return ListTile(leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file, color: isDir ? Colors.amber : Colors.blueGrey, size: 30), title: Text(name), onTap: () { if (isDir) _changeDirectory(Directory(entity.path)); else widget.onFileSelected(File(entity.path)); }); })),
      ],
    );
  }
}

class ChatOptionsScreen extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String receiverName;
  final String receiverAvatarUrl;
  const ChatOptionsScreen({super.key, required this.chatId, required this.receiverId, required this.receiverName, required this.receiverAvatarUrl});
  @override
  State<ChatOptionsScreen> createState() => _ChatOptionsScreenState();
}

class _ChatOptionsScreenState extends State<ChatOptionsScreen> {
  final _firebaseService = FirebaseService();
  final GlobalKey _optionsKey = GlobalKey();

  void _showMoreMenu() {
    final RenderBox? renderBox = _optionsKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    showMenu(context: context, elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: Colors.white, position: RelativeRect.fromLTRB(offset.dx - 80, offset.dy + size.height, offset.dx + size.width, 0), items: [PopupMenuItem(value: 'restrict', child: _buildPopupItem(Icons.remove_circle_outline, "Hạn chế", Colors.black87)), PopupMenuItem(value: 'block', child: _buildPopupItem(Icons.block, "Chặn", Colors.red)), PopupMenuItem(value: 'report', child: _buildPopupItem(Icons.report_gmailerrorred, "Báo cáo", Colors.red))]);
  }

  void _showThemePicker() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => Container(height: 350, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Column(children: [const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))), const SizedBox(height: 20), const Text("Chủ đề", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 30), Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildThemeOption(id: 'monochrome', name: 'Đơn sắc', colors: [Colors.grey.shade200, Colors.grey.shade300]), _buildThemeOption(id: 'default', name: 'Mặc định', colors: [const Color(0xFF0078FF), const Color(0xFF9C27B0)]), _buildThemeOption(id: 'berry', name: 'Quả mọng', colors: [Colors.pinkAccent, Colors.redAccent])])), const SizedBox(height: 20)])));
  }

  void _showThemePreview(String themeId, String themeName, List<Color> colors) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) {
      final isMonochrome = themeId == 'monochrome';
      final meBubbleDecoration = isMonochrome ? BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(20)) : BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.circular(20));
      final meTextColor = isMonochrome ? Colors.black : Colors.white;
      return Container(height: MediaQuery.of(context).size.height * 0.75, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Column(children: [const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))), const SizedBox(height: 20), Text("Đang xem trước $themeName", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [_buildPreviewBubble(text: "Mỗi chủ đề một trải nghiệm độc đáo.", isMe: true, decoration: meBubbleDecoration, textColor: meTextColor), _buildPreviewBubble(text: "Tin nhắn bạn gửi sẽ có màu này.", isMe: true, decoration: meBubbleDecoration, textColor: meTextColor), const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: Text("08:21", style: TextStyle(fontSize: 12, color: Colors.grey)))), _buildPreviewBubble(text: "Còn tin nhắn mà người khác gửi cho bạn sẽ có màu này.", isMe: false, decoration: BoxDecoration(color: Colors.grey[100], border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(20)), textColor: Colors.black), _buildPreviewBubble(text: "Hãy nhấn vào Áp dụng để chọn chủ đề này hoặc Hủy để xem trước các chủ đề khác.", isMe: true, decoration: meBubbleDecoration, textColor: meTextColor)])), Padding(padding: const EdgeInsets.all(20), child: Row(children: [Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("Hủy", style: TextStyle(fontWeight: FontWeight.bold)))), const SizedBox(width: 16), Expanded(child: ElevatedButton(onPressed: () { _firebaseService.updateChatTheme(widget.chatId, themeId); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã áp dụng chủ đề: $themeName'))); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B67F2), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("Áp dụng", style: TextStyle(fontWeight: FontWeight.bold))))]))]));
    });
  }

  Widget _buildPreviewBubble({required String text, required bool isMe, required BoxDecoration decoration, required Color textColor}) {
    return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), constraints: const BoxConstraints(maxWidth: 280), decoration: decoration, child: Text(text, style: TextStyle(color: textColor, fontSize: 15))));
  }

  Widget _buildThemeOption({required String id, required String name, required List<Color> colors}) {
    return GestureDetector(onTap: () { Navigator.pop(context); _showThemePreview(id, name, colors); }, child: Column(children: [Container(width: 80, height: 120, decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))])), const SizedBox(height: 12), Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))]));
  }

  Widget _buildPopupItem(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, color: color, size: 24), const SizedBox(width: 12), Text(text, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500))]);
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF2F8FF);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(backgroundColor: backgroundColor, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black), onPressed: () => Navigator.pop(context)), title: const Text("Tùy chọn", style: TextStyle(color: Colors.black, fontSize: 18)), centerTitle: true),
      // 13. Get Chat Stream using Service
      body: StreamBuilder<DocumentSnapshot>(
          stream: _firebaseService.getChatStream(widget.chatId),
          builder: (context, snapshot) {
            bool isMuted = false;
            String currentThemeName = "Mặc định";
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final List<dynamic> mutedBy = data['mutedBy'] ?? [];
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null) isMuted = mutedBy.contains(currentUser.uid);
              final String themeId = data['themeId'] ?? 'default';
              if (themeId == 'monochrome') currentThemeName = "Đơn sắc"; else if (themeId == 'berry') currentThemeName = "Quả mọng"; else currentThemeName = "Mặc định";
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Center(child: Column(children: [Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: CircleAvatar(radius: 50, backgroundColor: Colors.grey[300], backgroundImage: widget.receiverAvatarUrl.isNotEmpty ? NetworkImage(widget.receiverAvatarUrl) : null, child: widget.receiverAvatarUrl.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.grey) : null)), const SizedBox(height: 12), Text(widget.receiverName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black))])),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickAction(Icons.person_outline, "Trang cá nhân", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: widget.receiverId)))),
                        _buildQuickAction(Icons.search, "Tìm kiếm", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatSearchScreen(chatId: widget.chatId, receiverName: widget.receiverName)))),
                        _buildQuickAction(isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, isMuted ? "Bật thông báo" : "Tắt thông báo", onTap: () async {
                          await _firebaseService.toggleMuteChat(widget.chatId, isMuted);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isMuted ? 'Đã bật thông báo' : 'Đã tắt thông báo')));
                        }),
                        _buildQuickAction(Icons.more_horiz, "Lựa chọn", key: _optionsKey, onTap: _showMoreMenu),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [_buildOptionItem(icon: Icons.favorite, iconColor: Colors.pinkAccent, title: "Chủ đề", subtitle: currentThemeName, onTap: _showThemePicker), _buildOptionItem(icon: Icons.edit_note, iconColor: Colors.blue, title: "Biệt danh"), _buildOptionItem(icon: Icons.timer_outlined, iconColor: Colors.orange, title: "Tin nhắn tự hủy", subtitle: "Tắt"), _buildOptionItem(icon: Icons.lock_outline, iconColor: Colors.grey, title: "Quyền riêng tư và an toàn"), _buildOptionItem(icon: Icons.group_add_outlined, iconColor: Colors.blueGrey, title: "Tạo nhóm chat"), _buildOptionItem(icon: Icons.image_outlined, iconColor: Colors.green, title: "Ảnh & File đã gửi"), _buildOptionItem(icon: Icons.report_problem_outlined, iconColor: Colors.redAccent, title: "Báo cáo / Chặn")]),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, {VoidCallback? onTap, Key? key}) {
    return GestureDetector(onTap: onTap, child: Column(key: key, children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))]), child: Icon(icon, color: Colors.black87, size: 24)), const SizedBox(height: 8), SizedBox(width: 70, child: Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12, color: Colors.black54)))]));
  }

  Widget _buildOptionItem({required IconData icon, required Color iconColor, required String title, String? subtitle, VoidCallback? onTap}) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]), child: Row(children: [Icon(icon, color: iconColor, size: 26), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)), if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey))]])), const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)])));
  }
}

class ChatSearchScreen extends StatefulWidget {
  final String chatId;
  final String receiverName;

  const ChatSearchScreen({super.key, required this.chatId, required this.receiverName});

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _firebaseService = FirebaseService(); // Use service for stream
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { FocusScope.of(context).requestFocus(_focusNode); }); }
  @override
  void dispose() { _searchController.dispose(); _focusNode.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FF),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 1, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black), onPressed: () => Navigator.pop(context)), title: TextField(controller: _searchController, focusNode: _focusNode, decoration: const InputDecoration(hintText: "Tìm kiếm nội dung...", border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: Colors.black, fontSize: 17), onChanged: (value) { setState(() { _searchQuery = value.toLowerCase().trim(); }); }), actions: [if (_searchQuery.isNotEmpty) IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() { _searchQuery = ""; }); })]),
      // 14. Use Service Stream for Search
      body: _searchQuery.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search, size: 60, color: Colors.grey[300]), const SizedBox(height: 10), Text("Nhập từ khóa để tìm kiếm", style: TextStyle(color: Colors.grey[500]))])) : StreamBuilder<QuerySnapshot>(
        stream: _firebaseService.getMessagesStream(widget.chatId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Không có dữ liệu"));
          final allDocs = snapshot.data!.docs;
          final searchResults = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? 'text';
            if (type == 'text' || type == 'file') { final text = (data['text'] ?? '').toString().toLowerCase(); return text.contains(_searchQuery); }
            return false;
          }).toList();
          if (searchResults.isEmpty) return Center(child: Text("Không tìm thấy kết quả nào.", style: TextStyle(color: Colors.grey[600])));
          return ListView.separated(padding: const EdgeInsets.symmetric(vertical: 10), itemCount: searchResults.length, separatorBuilder: (ctx, i) => const Divider(height: 1), itemBuilder: (context, index) {
            final doc = searchResults[index];
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp? timestamp = data['timestamp'];
            final DateTime date = timestamp?.toDate() ?? DateTime.now();
            final String timeString = DateFormat('dd/MM HH:mm').format(date);
            final String text = data['text'] ?? '';
            final bool isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
            final String displayName = isMe ? "Tôi" : widget.receiverName;
            return ListTile(tileColor: Colors.white, leading: CircleAvatar(backgroundColor: isMe ? Colors.blue[100] : Colors.grey[200], child: Icon(isMe ? Icons.person : Icons.person_outline, color: isMe ? Colors.blue : Colors.grey, size: 20)), title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 4), Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[800], fontSize: 15)), const SizedBox(height: 4), Text(timeString, style: const TextStyle(fontSize: 11, color: Colors.grey))]), onTap: () {});
          });
        },
      ),
    );
  }
}
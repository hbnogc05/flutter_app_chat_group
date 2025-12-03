import 'dart:ui'; // Cần import để làm hiệu ứng mờ (blur)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart'; // Import Cupertino cho icon giống iOS
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// --- ĐẢM BẢO IMPORT ĐÚNG CÁC FILE CỦA BẠN ---
// Lưu ý: Nếu báo lỗi import, hãy kiểm tra lại đường dẫn file trong project của bạn
import 'package:zalo_app/widgets/status_section.dart';
import 'package:zalo_app/screens/chat_screen.dart';

enum _Filter { all, unread }

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with AutomaticKeepAliveClientMixin {
  final _currentUser = FirebaseAuth.instance.currentUser;
  _Filter _selectedFilter = _Filter.all;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ChatListBackgroundWavePainter(),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB0D8FF),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(4, 4),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.7),
                          blurRadius: 10,
                          offset: const Offset(-4, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Tin nhắn',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(-1),
                              icon: Image.asset(
                                'assets/icon/camera.png',
                                width: 26,
                                height: 26,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.camera_alt_outlined,
                                      color: Colors.blue.shade700);
                                },
                              ),
                              onPressed: () {},
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(2.0),
                              icon: Image.asset(
                                'assets/icon/edit.png',
                                width: 25,
                                height: 25,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.edit_outlined,
                                      color: Colors.blue.shade700);
                                },
                              ),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSearchBar(),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10.0, bottom: 5.0),
                    child: StatusSection(),
                  ),
                  _buildFilterChips(),
                  Expanded(child: _buildChatList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toLowerCase();
          });
        },
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: Colors.grey[600]),
          hintText: 'Tìm kiếm bạn bè...',
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          isDense: true,
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
            onTap: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
            child: Icon(Icons.close, color: Colors.grey[600], size: 20),
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFB0D8FF),
        borderRadius: BorderRadius.circular(25.0),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: _selectedFilter == _Filter.all
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                margin: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = _Filter.all;
                    });
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Center(
                    child: Text(
                      'Tất cả',
                      style: TextStyle(
                        color: _selectedFilter == _Filter.all
                            ? Colors.black
                            : Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = _Filter.unread;
                    });
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Center(
                    child: Text(
                      'Chưa đọc',
                      style: TextStyle(
                        color: _selectedFilter == _Filter.unread
                            ? Colors.black
                            : Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    if (_currentUser == null) {
      return const Center(child: Text('Vui lòng đăng nhập để xem tin nhắn.'));
    }

    Query query = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _currentUser!.uid)
        .orderBy('lastMessageTimestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Đã xảy ra lỗi!'));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Bạn chưa có cuộc trò chuyện nào.'));
        }

        // Tạo một list có thể chỉnh sửa để sort
        var docs = List<DocumentSnapshot>.from(snapshot.data!.docs);

        // --- [MỚI] Lọc bỏ các cuộc trò chuyện chưa có tin nhắn (timestamp là null) ---
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          // Nếu lastMessageTimestamp là null hoặc lastMessage rỗng thì coi như chưa có tin nhắn
          final timestamp = data?['lastMessageTimestamp'];
          final lastMsg = data?['lastMessage'];
          return timestamp != null && lastMsg != null && lastMsg.toString().isNotEmpty;
        }).toList();

        // 1. Lọc tin nhắn chưa đọc nếu cần
        if (_selectedFilter == _Filter.unread) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final unreadCount = data?['unreadCount']?[_currentUser!.uid] ?? 0;
            return unreadCount > 0;
          }).toList();
        }

        // 2. Sắp xếp: Đưa tin nhắn ĐÃ GHIM lên đầu
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;

          final List<dynamic> aPinnedBy = aData?['pinnedBy'] ?? [];
          final List<dynamic> bPinnedBy = bData?['pinnedBy'] ?? [];

          final bool aIsPinned = aPinnedBy.contains(_currentUser!.uid);
          final bool bIsPinned = bPinnedBy.contains(_currentUser!.uid);

          if (aIsPinned && !bIsPinned) return -1; // a lên trước
          if (!aIsPinned && bIsPinned) return 1; // b lên trước
          return 0; // Giữ nguyên thứ tự thời gian
        });

        if (docs.isEmpty) {
          return Center(
            child: Text(_selectedFilter == _Filter.unread
                ? 'Không có tin nhắn chưa đọc.'
                : 'Bạn chưa có cuộc trò chuyện nào.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: ChatListItem(
                key: ValueKey(doc.id),
                chatDoc: doc,
                searchQuery: _searchQuery,
              ),
            );
          },
        );
      },
    );
  }
}

class ChatListBackgroundWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB0D8FF)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);

    final double heightFactor = 0.39;

    path.lineTo(size.width, size.height * heightFactor);

    path.cubicTo(
        size.width * 0.75,
        size.height * heightFactor + 20,
        size.width * 0.25,
        size.height * heightFactor - 20,
        0,
        size.height * heightFactor);

    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class ChatListItem extends StatefulWidget {
  final DocumentSnapshot chatDoc;
  final String searchQuery;

  const ChatListItem({
    super.key,
    required this.chatDoc,
    this.searchQuery = '',
  });

  @override
  State<ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<ChatListItem> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  String? _otherUserId;
  String _otherUserName = '...';
  String _otherUserPhotoUrl = '';
  bool _isLoadingInfo = true;

  @override
  void initState() {
    super.initState();
    _getOtherUserInfo();
  }

  @override
  void didUpdateWidget(covariant ChatListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatDoc.id != widget.chatDoc.id) {
      _getOtherUserInfo();
    }
  }

  void _getOtherUserInfo() async {
    final chatData = widget.chatDoc.data() as Map<String, dynamic>?;
    if (chatData == null || _currentUser == null) return;

    final List<dynamic> participants = chatData['participants'] ?? [];
    _otherUserId = participants.firstWhere((id) => id != _currentUser!.uid,
        orElse: () => null);

    if (_otherUserId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_otherUserId)
          .get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data()!;
        setState(() {
          _otherUserName =
              userData['displayName'] ?? userData['email'] ?? 'Người dùng';
          _otherUserPhotoUrl = userData['photoURL'] ?? '';
          _isLoadingInfo = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    if (now.year == messageTime.year &&
        now.month == messageTime.month &&
        now.day == messageTime.day) {
      return DateFormat.Hm().format(messageTime);
    }
    if (now.year == messageTime.year &&
        now.month == messageTime.month &&
        now.day - messageTime.day == 1) {
      return 'Hôm qua';
    }
    return DateFormat.yMd().format(messageTime);
  }

  Widget _buildHighlightedName(String name, String query, bool isUnread) {
    TextStyle normalStyle = TextStyle(
      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
      fontSize: 16,
      color: isUnread ? Colors.blue.shade900 : Colors.black87,
    );

    if (query.isEmpty) {
      return Text(name, style: normalStyle);
    }

    List<TextSpan> spans = [];
    String lowerName = name.toLowerCase();
    String lowerQuery = query.toLowerCase();
    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerName.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(
          text: name.substring(start, indexOfMatch),
          style: normalStyle,
        ));
      }

      spans.add(TextSpan(
        text: name.substring(indexOfMatch, indexOfMatch + lowerQuery.length),
        style: normalStyle.copyWith(
          backgroundColor: Colors.blue.shade800,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ));

      start = indexOfMatch + lowerQuery.length;
    }

    if (start < name.length) {
      spans.add(TextSpan(
        text: name.substring(start),
        style: normalStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
    );
  }

  // --- CẬP NHẬT: Hiển thị Context Menu ngay tại vị trí item ---
  void _showContextMenu(
      BuildContext context,
      String lastMessage,
      String? lastMessageTime,
      bool isUnread,
      int unreadCount,
      bool isMenuAbove,
      Rect itemRect,
      bool isMuted,
      bool isPinned) {
    // Thêm tham số isPinned
    // Khoảng cách "nhấc lên"
    const double liftOffset = 10.0;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        // 1. Widget Preview (Đoạn chat)
        final previewWidget = Material(
          color: Colors.transparent,
          child: Container(
            // Đảm bảo kích thước box preview giống hệt item cũ
            width: itemRect.width,
            height: itemRect.height,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: _otherUserPhotoUrl.isNotEmpty
                      ? NetworkImage(_otherUserPhotoUrl)
                      : null,
                  child: _otherUserPhotoUrl.isEmpty
                      ? const Icon(Icons.person, size: 28)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Căn giữa dọc
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _otherUserName,
                        style: TextStyle(
                          fontWeight:
                          isUnread ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnread ? Colors.black87 : Colors.grey[600],
                          fontWeight:
                          isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (lastMessageTime != null)
                      Text(
                        lastMessageTime,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      const SizedBox(height: 24),
                  ],
                ),
              ],
            ),
          ),
        );

        // 2. Widget Menu Chức Năng
        final menuWidget = Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    // --- ICON MAIL ---
                    _buildMenuItem(
                      title: isUnread
                          ? 'Đánh dấu đã đọc'
                          : 'Đánh dấu là chưa đọc',
                      icon: null,
                      customIcon: Image.asset(
                        isUnread
                            ? 'assets/icon/mail.png'
                            : 'assets/icon/Mail V2.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          isUnread
                              ? CupertinoIcons.envelope_open
                              : CupertinoIcons.envelope,
                          size: 22,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        FirebaseFirestore.instance
                            .collection('chats')
                            .doc(widget.chatDoc.id)
                            .update({
                          'unreadCount.${_currentUser!.uid}': isUnread ? 0 : 1
                        });
                      },
                    ),
                    const Divider(height: 1, color: Colors.grey),

                    // --- CHỨC NĂNG GHIM/BỎ GHIM ---
                    _buildMenuItem(
                      title: isPinned ? 'Bỏ ghim' : 'Ghim',
                      icon: null,
                      customIcon: Image.asset(
                        'assets/icon/ghim.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(CupertinoIcons.pin, size: 22),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final chatRef = FirebaseFirestore.instance
                            .collection('chats')
                            .doc(widget.chatDoc.id);

                        if (isPinned) {
                          // Bỏ ghim
                          await chatRef.update({
                            'pinnedBy':
                            FieldValue.arrayRemove([_currentUser!.uid])
                          });
                        } else {
                          // Ghim
                          await chatRef.update({
                            'pinnedBy':
                            FieldValue.arrayUnion([_currentUser!.uid])
                          });
                        }
                      },
                    ),
                    const Divider(height: 1, color: Colors.grey),

                    // --- CHỨC NĂNG TẮT/BẬT THÔNG BÁO (ĐÃ CẬP NHẬT) ---
                    _buildMenuItem(
                      title: isMuted ? 'Bật thông báo' : 'Tắt thông báo',
                      // Nếu isMuted (Đang tắt) -> Hiển thị "Bật thông báo" -> Dùng Custom Icon (battbao.png)
                      // Nếu !isMuted (Đang bật) -> Hiển thị "Tắt thông báo" -> Dùng Custom Icon (tattbao.png)
                      icon: null, // Đặt icon là null để dùng customIcon
                      customIcon: Image.asset(
                        isMuted
                            ? 'assets/icon/battbao.png' // Icon Bật thông báo
                            : 'assets/icon/tattbao.png', // Icon Tắt thông báo
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                            isMuted
                                ? CupertinoIcons.bell
                                : CupertinoIcons.bell_slash,
                            size: 22),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final chatRef = FirebaseFirestore.instance
                            .collection('chats')
                            .doc(widget.chatDoc.id);

                        if (isMuted) {
                          await chatRef.update({
                            'mutedBy':
                            FieldValue.arrayRemove([_currentUser!.uid])
                          });
                        } else {
                          await chatRef.update({
                            'mutedBy':
                            FieldValue.arrayUnion([_currentUser!.uid])
                          });
                        }
                      },
                    ),

                    const Divider(height: 1, color: Colors.grey),
                    // --- CẬP NHẬT: ICON XÓA ---
                    _buildMenuItem(
                      title: 'Xóa',
                      icon: null, // Bỏ icon mặc định
                      customIcon: Image.asset(
                        'assets/icon/thungrac.png', // Icon thùng rác mới
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(CupertinoIcons.trash,
                            size: 22, color: Colors.red),
                      ),
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        return Stack(
          children: [
            // Lớp nền Blur
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                },
                child: FadeTransition(
                  opacity: anim1,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.black.withOpacity(0.1)),
                  ),
                ),
              ),
            ),

            // --- Đặt nội dung dựa trên vị trí thực tế của Item ---
            Positioned(
              left: itemRect.left,
              width: itemRect.width,
              top: isMenuAbove ? null : itemRect.top - liftOffset,
              bottom: isMenuAbove
                  ? (MediaQuery.of(context).size.height - itemRect.bottom) +
                  liftOffset
                  : null,

              child: FadeTransition(
                opacity: anim1,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                    CrossAxisAlignment.start, // Menu căn trái
                    children: isMenuAbove
                        ? [
                      menuWidget,
                      const SizedBox(height: 12),
                      previewWidget,
                    ]
                        : [
                      previewWidget,
                      const SizedBox(height: 12),
                      menuWidget,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Hàm helper hỗ trợ cả IconData và Custom Widget ---
  Widget _buildMenuItem({
    required String title,
    IconData? icon,
    Widget? customIcon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                color: isDestructive ? Colors.red : Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (customIcon != null)
              customIcon
            else if (icon != null)
              Icon(
                icon,
                size: 22,
                color: isDestructive ? Colors.red : Colors.black87,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.searchQuery.isNotEmpty && !_isLoadingInfo) {
      if (!_otherUserName.toLowerCase().contains(widget.searchQuery)) {
        return const SizedBox.shrink();
      }
    }

    final chatData = widget.chatDoc.data() as Map<String, dynamic>?;
    if (chatData == null || _currentUser == null) {
      return const SizedBox.shrink();
    }

    final String lastMessage = chatData['lastMessage'] ?? '...';
    final Timestamp? lastMessageTimestamp = chatData['lastMessageTimestamp'];
    final String? lastSenderId = chatData['lastSenderId'];

    // Lấy thông tin trạng thái thông báo (mutedBy)
    final List<dynamic> mutedBy = chatData['mutedBy'] ?? [];
    final bool isMuted = mutedBy.contains(_currentUser!.uid);

    // Lấy thông tin trạng thái ghim (pinnedBy)
    final List<dynamic> pinnedBy = chatData['pinnedBy'] ?? [];
    final bool isPinned = pinnedBy.contains(_currentUser!.uid);

    final int unreadCount =
        chatData['unreadCount']?['${_currentUser!.uid}'] ?? 0;
    final bool isUnread = unreadCount > 0;
    final bool isMe = lastSenderId == _currentUser!.uid;

    bool isSeenByReceiver = false;
    if (isMe) {
      final List<dynamic> participants = chatData['participants'] ?? [];
      final String? receiverId = participants.firstWhere(
            (id) => id != _currentUser!.uid,
        orElse: () => null,
      );

      if (receiverId != null) {
        final int receiverUnreadCount =
            chatData['unreadCount']?[receiverId] ?? 0;
        isSeenByReceiver = receiverUnreadCount == 0;
      }
    }

    return InkWell(
      onTap: () async {
        if (_otherUserId != null) {
          if (isUnread) {
            await FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatDoc.id)
                .update({
              'unreadCount.${_currentUser!.uid}': 0,
            });
          }

          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: widget.chatDoc.id,
                  receiverId: _otherUserId!,
                  receiverName: _otherUserName,
                  receiverAvatarUrl: _otherUserPhotoUrl,
                ),
              ),
            );
          }
        }
      },
      onLongPress: () {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Offset offset = renderBox.localToGlobal(Offset.zero);
        final Size size = renderBox.size;
        final Rect itemRect = offset & size;
        final double screenHeight = MediaQuery.of(context).size.height;
        final bool isMenuAbove = offset.dy > screenHeight / 2;

        String timeStr = _formatTimestamp(lastMessageTimestamp);

        // Truyền trạng thái isMuted và isPinned vào menu
        _showContextMenu(context, lastMessage, timeStr, isUnread, unreadCount,
            isMenuAbove, itemRect, isMuted, isPinned);
      },
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: const Color(0xFFB0D8FF),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(4, 4),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.7),
              blurRadius: 10,
              offset: const Offset(-4, -4),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: _otherUserPhotoUrl.isNotEmpty
                    ? NetworkImage(_otherUserPhotoUrl)
                    : null,
                child: _otherUserPhotoUrl.isEmpty
                    ? const Icon(Icons.person, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedName(
                        _otherUserName, widget.searchQuery, isUnread),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                        isUnread ? FontWeight.bold : FontWeight.normal,
                        color: isUnread
                            ? Colors.blue.shade800
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatTimestamp(lastMessageTimestamp),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),

                  // --- LOGIC HIỂN THỊ ICON TRẠNG THÁI (Mới) ---
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Icon Ghim
                      if (isPinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Image.asset(
                            'assets/icon/ghim.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              CupertinoIcons.pin_fill,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                      // 2. Icon Tắt thông báo
                      if (isMuted)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Image.asset(
                            'assets/icon/tattbao.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              CupertinoIcons.bell_slash_fill,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                      // 3. Badge chưa đọc hoặc tick đã xem
                      if (isUnread)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      else if (isMe && isSeenByReceiver)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.done_all,
                            size: 16,
                            color: Colors.blue,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
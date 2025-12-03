import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/account_switcher_screen.dart';
import 'package:zalo_app/screens/chat_screen.dart';
import 'package:zalo_app/screens/gallery_screen.dart';
import 'package:zalo_app/screens/settings_screen.dart';
import 'package:zalo_app/services/chat_service.dart';
import 'package:zalo_app/services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  late String _targetUserId;
  late bool _isMyProfile;

  // [CẬP NHẬT] Khai báo biến Stream
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _targetUserStream;
  late Stream<DocumentSnapshot> _currentUserStream;
  late Stream<QuerySnapshot> _friendRequestStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.userId ?? currentUser!.uid;
    _isMyProfile = (_targetUserId == currentUser!.uid);

    _targetUserStream = FirebaseFirestore.instance.collection('users').doc(_targetUserId).snapshots();
    if (currentUser != null) {
      _currentUserStream = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots();

      _friendRequestStream = FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUser!.uid)
          .where('recipientId', isEqualTo: _targetUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots();
    } else {
      _currentUserStream = const Stream.empty();
      _friendRequestStream = const Stream.empty();
    }
  }

  Future<void> _openGalleryAndUpdateImage(String imageType) async {
    if (!_isMyProfile || !mounted) return;

    final selectedImageUrl = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => GalleryScreen(userId: _targetUserId),
      ),
    );

    if (selectedImageUrl != null && selectedImageUrl.isNotEmpty) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        String fieldToUpdate = imageType == 'avatar' ? 'photoURL' : 'coverPhotoURL';
        await _userService.updateUserData(_targetUserId, {fieldToUpdate: selectedImageUrl});
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Cập nhật ảnh thành công!')));
      } catch (e) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Cập nhật ảnh thất bại: $e')));
      }
    }
  }

  Future<void> _navigateToChat(String userName, String userAvatar) async {
    if (currentUser == null) return;
    final chatRoomId = await _chatService.getOrCreateChatRoom(
      currentUser!.uid,
      _targetUserId,
    );

    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).get();

    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).set({
        'participants': [currentUser!.uid, _targetUserId],
        'lastMessage': '',
        'unreadCount': {
          currentUser!.uid: 0,
          _targetUserId: 0,
        },
      }, SetOptions(merge: true));
    }

    if (!mounted) return;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ChatScreen(
        chatId: chatRoomId,
        receiverId: _targetUserId,
        receiverName: userName,
        receiverAvatarUrl: userAvatar,
      ),
    ));
  }

  Future<void> _sendFriendRequest() async {
    if (currentUser == null) return;

    try {
      final existingRequests = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUser!.uid)
          .where('recipientId', isEqualTo: _targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequests.docs.isNotEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi lời mời trước đó.')));
        return;
      }

      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      final senderName = senderDoc.data()?['displayName'] ?? 'Một người dùng';

      await FirebaseFirestore.instance.collection('friend_requests').add({
        'senderId': currentUser!.uid,
        'recipientId': _targetUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(_targetUserId).collection('notifications').add({
        'title': '$senderName đã gửi cho bạn một lời mời kết bạn',
        'body': 'Hãy vào danh bạ để xem nhé.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'friend_request',
        'senderId': currentUser!.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi lời mời kết bạn.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _cancelFriendRequest() async {
    if (currentUser == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUser!.uid)
          .where('recipientId', isEqualTo: _targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      final notificationQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(_targetUserId)
          .collection('notifications')
          .where('type', isEqualTo: 'friend_request')
          .where('senderId', isEqualTo: currentUser!.uid)
          .get();

      for (var doc in notificationQuery.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy lời mời kết bạn.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (currentUser == null) {
      return const Center(child: Text("Vui lòng đăng nhập"));
    }

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _targetUserStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Không thể tải thông tin.'));
          }

          final userData = snapshot.data!.data()!;
          final String displayName = userData['displayName'] ?? 'Người dùng';
          final String? photoURL = userData['photoURL'];
          final String? coverPhotoURL = userData['coverPhotoURL'];

          // Stream để xác định mối quan hệ bạn bè
          return StreamBuilder<DocumentSnapshot>(
              stream: _currentUserStream,
              builder: (context, currentUserSnapshot) {
                // [LOGIC MỚI] Sử dụng biến nullable bool? để xử lý trạng thái loading
                bool? isFriend;

                // Chỉ cập nhật isFriend khi đã có dữ liệu thực sự
                if (currentUserSnapshot.hasData && currentUserSnapshot.data!.exists) {
                  final currentUserData = currentUserSnapshot.data!.data() as Map<String, dynamic>;
                  final List<dynamic> friends = currentUserData['friends'] ?? [];
                  isFriend = friends.contains(_targetUserId);
                }
                // Nếu currentUserSnapshot đang loading (waiting), isFriend sẽ là null

                return Stack(
                  children: [
                    _buildBody(displayName, photoURL, coverPhotoURL, isFriend),
                    if (_isMyProfile)
                      Positioned(
                        top: 40,
                        right: 10,
                        child: IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Colors.blueGrey, size: 28),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const SettingsScreen()),
                            );
                          },
                        ),
                      ),
                  ],
                );
              }
          );
        },
      ),
    );
  }

  // [CẬP NHẬT] Hàm nhận vào bool? isFriend thay vì bool
  Widget _buildBody(String displayName, String? photoURL, String? coverPhotoURL, bool? isFriend) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(displayName, photoURL, coverPhotoURL),
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_isMyProfile)
                const Text('Cập nhật giới thiệu bản thân', style: TextStyle(color: Colors.blue, fontSize: 16)),
              const SizedBox(height: 20),

              // [LOGIC HIỂN THỊ NÚT]
              if (_isMyProfile) ...[
                // 1. Nếu là profile của tôi -> Hiện nút quản lý ảnh
                _buildActionButtons(),
              ] else if (isFriend == true) ...[
                // 2. Nếu ĐÃ LÀ BẠN BÈ -> Hiện nút xem khoảnh khắc/ảnh ngay lập tức
                _buildActionButtons(),
              ] else if (isFriend == false) ...[
                // 3. Nếu CHẮC CHẮN KHÔNG PHẢI BẠN -> Hiện nút Kết bạn / Nhắn tin
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToChat(displayName, photoURL ?? ''),
                          icon: const Icon(Icons.message, color: Colors.blue),
                          label: const Text('Nhắn tin', style: TextStyle(color: Colors.blue)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: const BorderSide(color: Colors.blue, width: 1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _friendRequestStream,
                          builder: (context, snapshot) {
                            bool hasSentRequest = false;
                            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                              hasSentRequest = true;
                            }

                            if (hasSentRequest) {
                              return ElevatedButton.icon(
                                onPressed: _cancelFriendRequest,
                                icon: const Icon(Icons.cancel_outlined, color: Colors.black87),
                                label: const Text('Hủy kết bạn', style: TextStyle(color: Colors.black87)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              );
                            } else {
                              return ElevatedButton.icon(
                                onPressed: _sendFriendRequest,
                                icon: const Icon(Icons.person_add, color: Colors.white),
                                label: const Text('Kết bạn', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                )
              ] else ...[
                // 4. Nếu isFriend == NULL (đang tải) -> Hiện khoảng trống hoặc Loading
                // Điều này ngăn chặn việc hiện nhầm nút "Kết bạn"
                const SizedBox(
                  height: 48, // Chiều cao tương đương nút bấm để tránh nhảy layout quá nhiều
                  child: Center(
                      child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2)
                      )
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _buildEmptyState(),

              if (_isMyProfile)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const AccountSwitcherScreen()),
                            (Route<dynamic> route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
                  ),
                ),
            ],
          ),
        )
      ],
    );
  }

  SliverAppBar _buildSliverAppBar(String displayName, String? photoURL, String? coverPhotoURL) {
    return SliverAppBar(
      expandedHeight: 250.0,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: widget.userId != null ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()) : null,
      flexibleSpace: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cover Photo
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _isMyProfile ? _openGalleryAndUpdateImage('cover') : null,
              child: (coverPhotoURL != null && coverPhotoURL.isNotEmpty)
                  ? Image.network(
                coverPhotoURL,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300]),
              )
                  : Container(color: Colors.grey[300]),
            ),
          ),
          // Avatar
          Positioned(
            bottom: -50,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _isMyProfile ? _openGalleryAndUpdateImage('avatar') : null,
              child: Center(
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: (photoURL != null && photoURL.isNotEmpty) ? NetworkImage(photoURL) : null,
                    child: (photoURL == null || photoURL.isEmpty)
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(Icons.photo_library_outlined, 'Ảnh của tôi'),
          _buildActionButton(Icons.history_toggle_off, 'Khoảnh khắc'),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.blue.shade700),
      label: Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.8), // Semi-transparent white
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        elevation: 2,
      ),
      onPressed: () { /* TODO: Implement action */ },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
      child: Column(
        children: [
          Icon(Icons.note_alt_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'Hôm nay có gì vui?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Đây là Nhật ký của bạn - Hãy làm đầy Nhật ký với những dấu ấn cuộc đời và kỷ niệm đáng nhớ nhé!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          if (_isMyProfile)
            ElevatedButton(
              onPressed: () { /* TODO: Navigate to create post */ },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text('Đăng bài ngay', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
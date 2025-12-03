// lib/screens/friend_search_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/chat_screen.dart';
import 'package:zalo_app/screens/profile_screen.dart';
import 'package:zalo_app/services/chat_service.dart';

class FriendSearchScreen extends StatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  State<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen> {
  final _searchController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  List<DocumentSnapshot> _results = [];
  bool _isLoading = false;
  final Set<String> _sentRequests = {};
  final ChatService _chatService = ChatService();

  // Đã tăng độ đậm của màu xanh để nhìn rõ hơn
  final Color _backgroundColor = const Color(0xFFC0DFFF);

  // Khai báo biến Stream để giữ kết nối, tránh reload khi setState
  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _friendRequestsStream;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .snapshots();
      
      _friendRequestsStream = FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots();
    } else {
      // Fallback nếu chưa đăng nhập (thường không xảy ra ở màn hình này)
      _userStream = const Stream.empty();
      _friendRequestsStream = const Stream.empty();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty || _currentUser == null) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);

    final lowerCaseQuery = query.toLowerCase();
    final usersRef = FirebaseFirestore.instance.collection('users');

    // Tìm theo tên
    final nameQuery = usersRef
        .where('displayName_lowercase', isGreaterThanOrEqualTo: lowerCaseQuery)
        .where('displayName_lowercase', isLessThanOrEqualTo: '$lowerCaseQuery\uf8ff')
        .get();

    // Tìm theo email
    final emailQuery = usersRef
        .where('email', isGreaterThanOrEqualTo: lowerCaseQuery)
        .where('email', isLessThanOrEqualTo: '$lowerCaseQuery\uf8ff')
        .get();

    final List<QuerySnapshot> snapshots = await Future.wait([nameQuery, emailQuery]);
    final Map<String, DocumentSnapshot> userMap = {};

    // Gộp kết quả và loại bỏ bản thân
    for (var doc in snapshots[0].docs) {
      if (doc.id != _currentUser!.uid) userMap[doc.id] = doc;
    }
    for (var doc in snapshots[1].docs) {
      if (doc.id != _currentUser!.uid) userMap[doc.id] = doc;
    }

    setState(() {
      _results = userMap.values.toList();
      _isLoading = false;
    });
  }

  Future<void> _sendFriendRequest(String recipientId) async {
    if (_currentUser == null) return;
    
    if (_sentRequests.contains(recipientId)) return;

    setState(() {
      _sentRequests.add(recipientId);
    });

    try {
      // Kiểm tra xem đã có lời mời nào đang chờ chưa (remote check)
      final existingRequests = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: _currentUser!.uid)
          .where('recipientId', isEqualTo: recipientId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequests.docs.isNotEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi lời mời trước đó.')));
        return;
      }

      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      final senderName = senderDoc.data()?['displayName'] ?? 'Một người dùng';

      await FirebaseFirestore.instance.collection('friend_requests').add({
        'senderId': _currentUser!.uid,
        'recipientId': recipientId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(recipientId).collection('notifications').add({
        'title': '$senderName đã gửi cho bạn một lời mời kết bạn',
        'body': 'Hãy vào danh bạ để xem nhé.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'friend_request',
        'senderId': _currentUser!.uid,
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi lời mời kết bạn.')));
    } catch (e) {
      setState(() {
        _sentRequests.remove(recipientId);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  // [CẬP NHẬT] Hàm hủy lời mời kết bạn
  Future<void> _cancelFriendRequest(String recipientId) async {
    if (_currentUser == null) return;

    // Xóa khỏi danh sách tạm thời để update UI ngay (optimistic)
    if (_sentRequests.contains(recipientId)) {
       setState(() {
         _sentRequests.remove(recipientId);
       });
    }

    try {
      // 1. Xóa lời mời kết bạn
      final querySnapshot = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: _currentUser!.uid)
          .where('recipientId', isEqualTo: recipientId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      // 2. [MỚI] Xóa thông báo tương ứng bên phía người nhận
      final notificationQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .where('type', isEqualTo: 'friend_request')
          .where('senderId', isEqualTo: _currentUser!.uid)
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
      // Nếu lỗi, có thể add lại vào _sentRequests nếu cần, nhưng ở đây user có thể thử lại
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor, // Màu nền xanh
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _backgroundColor, // AppBar cùng màu nền để tạo cảm giác liền mạch
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48, // Increased height to 48
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15), // Increased border radius to 15
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2), // changes position of shadow
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm bạn bè',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12), // Adjusted content padding
                      isDense: true,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.black),
                    onChanged: _searchUsers,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Hủy',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              // Sử dụng stream đã khởi tạo
              stream: _userStream,
              builder: (context, userSnapshot) {
                // Chỉ hiện loading nếu chưa có data và đang waiting.
                // Nếu data đã có (từ cache hoặc update), thì hiển thị.
                if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
                   return const SizedBox.shrink();
                }
                
                // Nếu có lỗi hoặc không có data sau khi load xong
                if (!userSnapshot.hasData || userSnapshot.data!.data() == null) return const SizedBox.shrink();
                
                final currentUserData = userSnapshot.data!.data() as Map<String, dynamic>;
                final List<dynamic> friends = currentUserData['friends'] ?? [];

                return StreamBuilder<QuerySnapshot>(
                  // Sử dụng stream đã khởi tạo
                  stream: _friendRequestsStream,
                  builder: (context, requestSnapshot) {
                    
                    // [QUAN TRỌNG] Xử lý trạng thái loading để tránh flicker
                    // Nếu đang loading và chưa có data, hiện loading hoặc khoảng trắng
                    if (requestSnapshot.connectionState == ConnectionState.waiting && !requestSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final Set<String> sentRequestIds = requestSnapshot.data?.docs
                            .map((doc) => doc['recipientId'] as String)
                            .toSet() ??
                        {};
                    
                    // Combine with local state for optimistic UI
                    sentRequestIds.addAll(_sentRequests);

                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final userDoc = _results[index];
                        final bool isFriend = friends.contains(userDoc.id);
                        final bool hasSentRequest = sentRequestIds.contains(userDoc.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: (userDoc['photoURL'] != null && userDoc['photoURL'].isNotEmpty)
                                  ? NetworkImage(userDoc['photoURL'])
                                  : null,
                              child: (userDoc['photoURL'] == null || userDoc['photoURL'].isEmpty)
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                            title: Text(
                              userDoc['displayName'] ?? 'Người dùng',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              userDoc['email'] ?? '',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // [CẬP NHẬT] Thay đổi UI nút kết bạn
                            trailing: isFriend
                                ? const Chip(
                              label: Text('Bạn bè', style: TextStyle(color: Colors.blue, fontSize: 12)),
                              backgroundColor: Color(0xFFE5F0FF),
                            )
                                : hasSentRequest
                                ? ElevatedButton(
                              onPressed: () => _cancelFriendRequest(userDoc.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300], // Màu xám nhạt
                                foregroundColor: Colors.black87,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                minimumSize: const Size(80, 32),
                              ),
                              child: const Text('Hủy kết bạn', style: TextStyle(fontSize: 13)),
                            )
                                : ElevatedButton(
                              onPressed: () => _sendFriendRequest(userDoc.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0091FF), // Màu xanh chuẩn Zalo
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                minimumSize: const Size(80, 32),
                              ),
                              child: const Text('Kết bạn', style: TextStyle(fontSize: 13)),
                            ),
                            onTap: () async {
                              if (isFriend) {
                                // Navigate to Chat Screen
                                final chatRoomId = await _chatService.getOrCreateChatRoom(
                                  _currentUser!.uid,
                                  userDoc.id,
                                );
                                
                                final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).get();

                                // [CẬP NHẬT] Nếu chưa có doc chat, hoặc chưa có tin nhắn nào, đảm bảo tạo doc nhưng KHÔNG set lastMessageTimestamp
                                // Điều này giúp ẩn chat khỏi danh sách chat cho đến khi tin nhắn đầu tiên được gửi.
                                if (!chatDoc.exists) {
                                    await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).set({
                                        'participants': [_currentUser!.uid, userDoc.id],
                                        'lastMessage': '',
                                        // KHÔNG set lastMessageTimestamp ở đây
                                        'unreadCount': {
                                            _currentUser!.uid: 0,
                                            userDoc.id: 0,
                                        },
                                    }, SetOptions(merge: true));
                                }

                                if (!mounted) return;

                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatId: chatRoomId,
                                    receiverId: userDoc.id,
                                    receiverName: userDoc['displayName'] ?? 'Người dùng',
                                    receiverAvatarUrl: userDoc['photoURL'] ?? '',
                                  ),
                                ));
                              } else {
                                // Navigate to Profile Screen
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => ProfileScreen(userId: userDoc.id),
                                ));
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

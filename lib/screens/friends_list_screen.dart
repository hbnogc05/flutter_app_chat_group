// lib/screens/friends_list_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/chat_list_screen.dart';
import 'package:zalo_app/screens/chat_screen.dart';
import 'package:zalo_app/screens/friend_requests_screen.dart';
import 'package:zalo_app/screens/friend_search_screen.dart';
import 'package:zalo_app/services/chat_service.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper to fetch documents in chunks to avoid query limits.
  Future<List<QuerySnapshot>> _fetchDocsInChunks(
      List<String> docIds, String collectionPath) async {
    if (docIds.isEmpty) return [];

    // Firestore 'whereIn' queries can have at most 30 elements.
    const chunkSize = 30;
    List<Future<QuerySnapshot>> futures = [];

    for (var i = 0; i < docIds.length; i += chunkSize) {
      final chunk = docIds.sublist(
          i, i + chunkSize > docIds.length ? docIds.length : i + chunkSize);

      if (chunk.isNotEmpty) {
        futures.add(FirebaseFirestore.instance
            .collection(collectionPath)
            .where(FieldPath.documentId, whereIn: chunk)
            .get());
      }
    }
    return await Future.wait(futures);
  }

  Widget _buildCustomTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25.0),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: _tabController.index == 0
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
                  color: const Color(0xFFB0D8FF),
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
                    _tabController.animateTo(0);
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Center(
                    child: Text(
                      'BẠN BÈ',
                      style: TextStyle(
                        color: _tabController.index == 0
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
                    _tabController.animateTo(1);
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Center(
                    child: Text(
                      'NHÓM',
                      style: TextStyle(
                        color: _tabController.index == 1
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
                  // Header Container giống ChatListScreen
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
                                'Danh bạ',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.person_add_alt_1, color: Colors.blue.shade700), 
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
                              }
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendSearchScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white, 
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: Colors.grey[600]),
                                const SizedBox(width: 10),
                                Text('Tìm kiếm bạn bè', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  _buildCustomTabBar(),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFriendsTab(),
                        _buildGroupsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text("Vui lòng đăng nhập để xem danh sách bạn bè."),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return const Center(child: Text('Đã xảy ra lỗi khi tải dữ liệu người dùng.'));
        }
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Center(child: Text('Không tìm thấy dữ liệu người dùng.'));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

        final List<String> friendIds = (userData?['friends'] as List<dynamic>?)
            ?.whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList() ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('friend_requests').where('recipientId', isEqualTo: currentUser.uid).snapshots(),
          builder: (context, requestSnapshot) {
            final requestCount = requestSnapshot.data?.docs.length ?? 0;

            if (friendIds.isEmpty) {
              return _buildEmptyFriendsList(requestCount);
            }

            return FutureBuilder<List<QuerySnapshot>>(
              future: _fetchDocsInChunks(friendIds, 'users'),
              builder: (context, friendChunksSnapshot) {
                if (friendChunksSnapshot.hasError) {
                  debugPrint("Error fetching friends: ${friendChunksSnapshot.error}");
                  return const Center(child: Text("Đã có lỗi khi tải danh sách bạn bè."));
                }
                if (friendChunksSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final friends = friendChunksSnapshot.data
                    ?.expand((snapshot) => snapshot.docs)
                    .toList() ?? [];
                
                if (friends.isEmpty && friendIds.isNotEmpty) {
                    return const Center(child: Text("Không thể tải thông tin bạn bè."));
                }

                Map<String, List<DocumentSnapshot>> groupedUsers = {};
                for (var user in friends) {
                  final data = user.data() as Map<String, dynamic>;
                  String name = data['displayName'] ?? data['email'] ?? '#';
                  String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '#';
                  if (groupedUsers[firstLetter] == null) groupedUsers[firstLetter] = [];
                  groupedUsers[firstLetter]!.add(user);
                }
                List<String> sortedKeys = groupedUsers.keys.toList()..sort();

                for (var key in sortedKeys) {
                  groupedUsers[key]!.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    String aName = aData['displayName'] ?? aData['email'] ?? '';
                    String bName = bData['displayName'] ?? bData['email'] ?? '';
                    return aName.compareTo(bName);
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 100.0),
                  itemCount: sortedKeys.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildFunctionItem(Icons.group_add, 'Lời mời kết bạn', () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
                      }, badgeCount: requestCount);
                    }
                    if (index == 1) {
                      return _buildFunctionItem(Icons.cake, 'Sinh nhật', () {});
                    }

                    String key = sortedKeys[index - 2];
                    List<DocumentSnapshot> userGroup = groupedUsers[key]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        ...userGroup.map((doc) => _buildUserListItem(doc)),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyFriendsList(int requestCount) {
    return ListView(
      padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 100.0),
      children: [
        _buildFunctionItem(Icons.group_add, 'Lời mời kết bạn', () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
        }, badgeCount: requestCount),
        _buildFunctionItem(Icons.cake, 'Sinh nhật', () {}),
        const Center(child: Padding(padding: const EdgeInsets.all(50.0), child: Text('Bạn chưa có bạn bè nào.'))),
      ],
    );
  }

  Widget _buildFunctionItem(IconData icon, String title, VoidCallback onTap, {int badgeCount = 0}) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.blue.shade700, child: Icon(icon, color: Colors.white)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: badgeCount > 0
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildUserListItem(DocumentSnapshot document) {
    final data = document.data()! as Map<String, dynamic>;
    final String displayName = data['displayName'] ?? data['email'] ?? 'Người dùng';
    final String photoURL = data['photoURL'] ?? '';
    final String receiverId = document.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () async {
          if (_auth.currentUser == null) return;
          final currentUserId = _auth.currentUser!.uid;

          final chatRoomId = await _chatService.getOrCreateChatRoom(
            currentUserId,
            receiverId,
          );

          final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).get();

          if (!chatDoc.exists || chatDoc.data()?['lastMessageTimestamp'] == null) {
              await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).set({
                  'participants': [currentUserId, receiverId],
                  'lastMessage': '',
                  'lastMessageTimestamp': FieldValue.serverTimestamp(),
                  'unreadCount': {
                      currentUserId: 0,
                      receiverId: 0,
                  },
              }, SetOptions(merge: true));
          }

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatRoomId,
                receiverId: receiverId,
                receiverName: displayName,
                receiverAvatarUrl: photoURL,
              ),
            ),
          );
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
                  radius: 25,
                  backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                  child: photoURL.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    displayName, 
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.black87)
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.call_outlined, color: Colors.grey[600]), 
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: Icon(Icons.videocam_outlined, color: Colors.grey[600]), 
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsTab() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text("Vui lòng đăng nhập để xem các nhóm."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: currentUser.uid).where('isGroup', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Đã xảy ra lỗi khi tải các nhóm.'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Bạn chưa tham gia nhóm nào.'));

        return GridView.builder(
          padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 100.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final groupDoc = snapshot.data!.docs[index];
            return _buildGroupCard(groupDoc);
          },
        );
      },
    );
  }

  Widget _buildGroupCard(DocumentSnapshot groupDoc) {
    final groupData = groupDoc.data() as Map<String, dynamic>;
    final String groupName = groupData['groupName'] ?? 'Nhóm không tên';
    final List<dynamic> members = groupData['participants'] ?? [];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: Colors.white, // Solid white
      elevation: 3,
      child: InkWell(
        onTap: () {
          // Navigate to group chat screen
        },
        borderRadius: BorderRadius.circular(15.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: Colors.grey[200], child: const Icon(Icons.group, color: Colors.blue)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(groupName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${members.length} thành viên', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

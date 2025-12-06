// lib/screens/tuong_nha_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/create_post_screen.dart';
import 'package:zalo_app/screens/notification_screen.dart';
import 'package:zalo_app/screens/post_search_screen.dart';
import 'package:zalo_app/screens/reels_screen.dart';
import 'package:zalo_app/widgets/post_item.dart';

class TuongNhaScreen extends StatefulWidget {
  const TuongNhaScreen({super.key});

  @override
  State<TuongNhaScreen> createState() => _TuongNhaScreenState();
}

class _TuongNhaScreenState extends State<TuongNhaScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _tabController;
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<DocumentSnapshot> _getUserStream() {
    if (_currentUser == null) {
      return Stream.empty();
    }
    return FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).snapshots();
  }

  void _navigateToCreatePost() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreatePostScreen()));
  }

  void _navigateToPostSearch() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PostSearchScreen()));
  }

  void _navigateToNotifications() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const NotificationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNhatKyTab(),
          const ReelsScreen(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white, // White background
      elevation: 0,
      automaticallyImplyLeading: false,
      title: GestureDetector(
        onTap: _navigateToPostSearch,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFC6E7FF), // Light blue container
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Image.asset('assets/icon/search (2).png', width: 24, height: 24),
              ),
              Text('Tìm kiếm', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(icon: Icon(Icons.edit_note, color: Colors.blue.shade700), onPressed: _navigateToCreatePost),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser?.uid)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data?.docs.length ?? 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(icon: Icon(Icons.notifications_outlined, color: Colors.blue.shade700), onPressed: _navigateToNotifications),
                if (unreadCount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.blue.shade700,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.blue.shade700,
        indicatorWeight: 3.0,
        tabs: const [
          Tab(text: 'Nhật Ký'),
          Tab(text: 'REELS'),
        ],
      ),
    );
  }

  Widget _buildNhatKyTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getUserStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildNhatKyContent(null);
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final photoURL = userData?['photoURL'] as String?;
        
        return _buildNhatKyContent(photoURL);
      },
    );
  }

  Widget _buildNhatKyContent(String? photoURL) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildPostStatusSection(photoURL),
              const Divider(thickness: 8, color: Colors.transparent), // Transparent divider
              _buildKhoanhKhacSection(photoURL),
              const Divider(thickness: 8, color: Colors.transparent), // Transparent divider
            ],
          ),
        ),
        _buildFeedSection(),
      ],
    );
  }

  Widget _buildPostStatusSection(String? photoURL) {
    return GestureDetector(
      onTap: _navigateToCreatePost,
      child: Container(
        color: Colors.white, // Solid white
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: (photoURL != null && photoURL.isNotEmpty) ? NetworkImage(photoURL) : null,
                  child: (photoURL == null || photoURL.isEmpty) 
                      ? const Icon(Icons.person, size: 24, color: Colors.white)
                      : null,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(width: 12),
                Text('Hôm nay bạn thế nào?', style: TextStyle(color: Colors.grey[800], fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPostActionButton(Icons.image, 'Ảnh', Colors.green),
                _buildPostActionButton(Icons.videocam, 'Video', Colors.red),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPostActionButton(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildKhoanhKhacSection(String? photoURL) {
    return Container(
      color: Colors.white, // Solid white
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Khoảnh khắc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCreateStoryCard(photoURL),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateStoryCard(String? photoURL) {
    return GestureDetector(
      onTap: _navigateToCreatePost,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (photoURL != null && photoURL.isNotEmpty)
                ? Image.network(photoURL, fit: BoxFit.cover)
                : Container(color: Colors.grey[300], child: const Icon(Icons.person, size: 50, color: Colors.white)),
            ),
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue, 
                  shape: BoxShape.circle, 
                  border: Border.all(color: Colors.white, width: 3)
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ),
            const Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Text('Tạo mới', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedSection() {
    final currentUserId = _currentUser?.uid;
    if (currentUserId == null) {
      return const SliverToBoxAdapter(child: Center(child: Text('Vui lòng đăng nhập.')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        }
        if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const SliverToBoxAdapter(child: Center(child: Text('Không thể tải dữ liệu người dùng.')));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final List<dynamic> friends = userData?['friends'] ?? [];
        final friendIds = friends.map((id) => id.toString()).toSet();
        friendIds.add(currentUserId);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, postSnapshot) {
            if (postSnapshot.hasError) {
              debugPrint("Firestore Error: ${postSnapshot.error}");
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Đã có lỗi xảy ra khi tải bài viết.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            if (postSnapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
            }
            
            final allPosts = postSnapshot.data!.docs;
            final visiblePosts = allPosts.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final authorId = data['authorId'];
                return friendIds.contains(authorId);
            }).toList();

            if (visiblePosts.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(50.0),
                  child: Center(child: Text('Chưa có bài đăng nào từ bạn hoặc bạn bè.')),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final postDoc = visiblePosts[index];
                  return PostItem(postDoc: postDoc);
                },
                childCount: visiblePosts.length,
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/create_post_screen.dart';
import 'package:zalo_app/screens/create_story_screen.dart';
import 'package:zalo_app/screens/notification_screen.dart';
import 'package:zalo_app/screens/post_search_screen.dart';
import 'package:zalo_app/widgets/post_item.dart';

class TuongNhaScreen extends StatefulWidget {
  const TuongNhaScreen({super.key});

  @override
  State<TuongNhaScreen> createState() => _TuongNhaScreenState();
}

class _TuongNhaScreenState extends State<TuongNhaScreen> with AutomaticKeepAliveClientMixin {
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  bool get wantKeepAlive => true;

  Stream<DocumentSnapshot> _getUserStream() {
    if (_currentUser == null) {
      return Stream.empty();
    }
    return FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getUserStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildNhatKyContent(null, []);
          }
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final photoURL = userData?['photoURL'] as String?;
          final List<String> friends = List<String>.from(userData?['friends'] ?? []);
          final storyPublishers = [_currentUser!.uid, ...friends];

          return _buildNhatKyContent(photoURL, storyPublishers);
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0068FF),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PostSearchScreen())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: const [
              Icon(Icons.search, color: Colors.white),
              SizedBox(width: 8),
              Text('Tìm kiếm', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreatePostScreen())),
        ),
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
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const NotificationScreen())),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: const Color(0xFFFF3B30), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildNhatKyContent(String? photoURL, List<String> storyPublishers) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildPostStatusSection(photoURL),
                const Divider(thickness: 6, color: Color(0xFFF0F2F5)),
                _buildKhoanhKhacSection(photoURL, storyPublishers),
                const Divider(thickness: 6, color: Color(0xFFF0F2F5)),
              ],
            ),
          ),
        ),
        _buildFeedSection(),
      ],
    );
  }

  Widget _buildPostStatusSection(String? photoURL) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreatePostScreen())),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: (photoURL != null && photoURL.isNotEmpty) ? NetworkImage(photoURL) : null,
                  child: (photoURL == null || photoURL.isEmpty) ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(width: 12),
                Text('Hôm nay bạn thế nào?', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPostActionButton(Icons.image_outlined, 'Ảnh'),
              _buildPostActionButton(Icons.videocam_outlined, 'Video'),
              _buildPostActionButton(Icons.photo_album_outlined, 'Album'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPostActionButton(IconData icon, String label) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreatePostScreen())),
      icon: Icon(icon, color: Colors.grey[600]),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFF0F2F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildKhoanhKhacSection(String? myAvatar, List<String> storyPublishers) {
    final twentyFourHoursAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Text('Khoảnh khắc', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stories')
                  .where('authorId', whereIn: storyPublishers.isNotEmpty ? storyPublishers : null)
                  .where('timestamp', isGreaterThan: twentyFourHoursAgo)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // Even on error, at least show the create button
                  return ListView(padding: const EdgeInsets.symmetric(horizontal: 12), scrollDirection: Axis.horizontal, children: [_buildStoryCard('Tạo mới', isCreate: true, myAvatar: myAvatar)]);
                }

                final storiesDocs = snapshot.data?.docs ?? [];
                var stories = storiesDocs.fold<Map<String, DocumentSnapshot>>({}, (map, doc) {
                  String authorId = doc['authorId'];
                  if (!map.containsKey(authorId)) {
                    map[authorId] = doc;
                  }
                  return map;
                }).values.toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: stories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildStoryCard('Tạo mới', isCreate: true, myAvatar: myAvatar);
                    }
                    final story = stories[index - 1];
                    final data = story.data() as Map<String, dynamic>;
                    return _buildStoryCard(data['authorName'] ?? 'Người dùng', storyImageUrl: data['imageUrl'], authorAvatarUrl: data['authorAvatarUrl']);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(String name, {bool isCreate = false, String? myAvatar, String? storyImageUrl, String? authorAvatarUrl}) {
    final finalStoryImageUrl = isCreate ? myAvatar : storyImageUrl;

    return GestureDetector(
      onTap: () {
        if (isCreate) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateStoryScreen()));
        }
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: finalStoryImageUrl != null
              ? DecorationImage(image: NetworkImage(finalStoryImageUrl), fit: BoxFit.cover)
              : null,
          color: Colors.grey[300],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.7)],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),
            if (isCreate)
              Center(
                child: Container(
                  width: 44, 
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0068FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                ),
              )
            else 
              Center(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF0068FF), 
                  child: CircleAvatar(
                    radius: 22,
                    backgroundImage: (authorAvatarUrl != null && authorAvatarUrl.isNotEmpty) ? NetworkImage(authorAvatarUrl) : null,
                    child: (authorAvatarUrl == null || authorAvatarUrl.isEmpty) ? const Icon(Icons.person, size: 22) : null,
                  ),
                ),
              ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, postSnapshot) {
        if (postSnapshot.hasError) {
          return SliverToBoxAdapter(child: Center(child: Text('Lỗi: ${postSnapshot.error}')));
        }
        if (postSnapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        }
        if (!postSnapshot.hasData || postSnapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(50.0),
              child: Center(child: Text('Bảng tin trống.')),
            ),
          );
        }

        final posts = postSnapshot.data!.docs;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final postDoc = posts[index];
              return PostItem(postDoc: postDoc);
            },
            childCount: posts.length,
          ),
        );
      },
    );
  }
}

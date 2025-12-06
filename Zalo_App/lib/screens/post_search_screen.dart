// lib/screens/post_search_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PostSearchScreen extends StatefulWidget {
  const PostSearchScreen({super.key});

  @override
  State<PostSearchScreen> createState() => _PostSearchScreenState();
}

class _PostSearchScreenState extends State<PostSearchScreen> {
  final _searchController = TextEditingController();
  List<DocumentSnapshot> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPosts(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);

    final lowerCaseQuery = query.toLowerCase();
    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('keywords', arrayContains: lowerCaseQuery)
        .get();

    setState(() {
      _results = snapshot.docs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Tìm kiếm bài viết...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintStyle: TextStyle(color: Colors.grey),
            ),
            style: const TextStyle(color: Colors.black),
            onChanged: _searchPosts,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(child: Text('Không có bài viết nào khớp.'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final postData = _results[index].data() as Map<String, dynamic>;
                    return _buildPostItem(postData);
                  },
                ),
    );
  }

  // Widget cho một bài đăng (tái sử dụng từ tuong_nha_screen)
  Widget _buildPostItem(Map<String, dynamic> postData) {
    final String authorName = postData['authorName'] ?? 'Người dùng';
    final String authorAvatarUrl = postData['authorAvatarUrl'] ?? '';
    final String content = postData['content'] ?? '';
    final Timestamp timestamp = postData['timestamp'] ?? Timestamp.now();

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: authorAvatarUrl.isNotEmpty ? NetworkImage(authorAvatarUrl) : null,
                  child: authorAvatarUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(DateFormat.yMMMd().add_Hm().format(timestamp.toDate()), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
              ],
            ),
            const SizedBox(height: 12),
            Text(content, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPostInteractionButton(Icons.thumb_up_alt_outlined, 'Thích'),
                _buildPostInteractionButton(Icons.comment_outlined, 'Bình luận'),
                _buildPostInteractionButton(Icons.share_outlined, 'Chia sẻ'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPostInteractionButton(IconData icon, String label) {
    return TextButton.icon(
      onPressed: () {},
      icon: Icon(icon, color: Colors.grey[600]),
      label: Text(label, style: TextStyle(color: Colors.grey[700])),
    );
  }
}

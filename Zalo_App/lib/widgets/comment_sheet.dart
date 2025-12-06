// lib/widgets/comment_sheet.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CommentSheet extends StatefulWidget {
  final String postId;

  const CommentSheet({super.key, required this.postId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final _commentController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
    final userData = userDoc.data() ?? {};

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'content': content,
      'authorId': _currentUser!.uid,
      'authorName': userData['displayName'] ?? 'Người dùng',
      'authorAvatarUrl': userData['photoURL'] ?? '',
      'timestamp': Timestamp.now(),
    });

    _commentController.clear();
    FocusScope.of(context).unfocus(); // Ẩn bàn phím sau khi gửi
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets, // Đẩy UI lên khi bàn phím hiện
      child: Column(
        mainAxisSize: MainAxisSize.min, // Chỉ chiếm không gian cần thiết
        children: [
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text('Bình luận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const Divider(height: 1),
          // Vùng hiển thị các bình luận
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Chưa có bình luận nào.'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final commentData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return _buildCommentItem(commentData);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Vùng nhập bình luận
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration.collapsed(hintText: 'Viết bình luận...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _postComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> data) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (data['authorAvatarUrl'] != null && data['authorAvatarUrl'].isNotEmpty)
            ? NetworkImage(data['authorAvatarUrl'])
            : null,
        child: (data['authorAvatarUrl'] == null || data['authorAvatarUrl'].isEmpty)
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(data['authorName'] ?? '...', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['content'] ?? ''),
          const SizedBox(height: 4),
          Text(
            DateFormat.yMMMd().add_Hm().format((data['timestamp'] as Timestamp).toDate()),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

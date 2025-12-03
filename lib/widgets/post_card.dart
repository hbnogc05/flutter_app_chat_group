// lib/widgets/post_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PostCard extends StatefulWidget {
  final QueryDocumentSnapshot post;

  const PostCard({
    super.key,
    required this.post,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  Future<void> _toggleLike() async {
    final List likes = widget.post['likes'];
    final bool isLiked = likes.contains(currentUser.uid);

    try {
      DocumentReference postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post.id);

      if (isLiked) {
        await postRef.update({
          'likes': FieldValue.arrayRemove([currentUser.uid])
        });
      } else {
        await postRef.update({
          'likes': FieldValue.arrayUnion([currentUser.uid])
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xảy ra lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final postData = widget.post.data() as Map<String, dynamic>;
    final List likes = postData['likes'] ?? [];
    final bool isLiked = likes.contains(currentUser.uid);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      postData['userName'] ?? 'Vô danh', // Sửa từ authorEmail thành userName
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      (postData['timestamp'] as Timestamp).toDate().toString().substring(0, 16),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (postData['content'] != null && postData['content'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  postData['content'],
                  style: const TextStyle(fontSize: 16.0),
                ),
              ),

            if (postData['imageUrl'] != null && postData['imageUrl'].isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Image.network(
                  postData['imageUrl'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.error, color: Colors.red, size: 50);
                  },
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  onPressed: _toggleLike,
                  icon: Icon(
                    isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                    color: isLiked ? Theme.of(context).primaryColor : Colors.grey,
                  ),
                  label: Text(
                    'Thích (${likes.length})',
                    style: TextStyle(
                      color: isLiked ? Theme.of(context).primaryColor : Colors.grey,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () { /* TODO: Logic bình luận */ },
                  icon: const Icon(Icons.comment_outlined, color: Colors.grey),
                  label: const Text('Bình luận', style: TextStyle(color: Colors.grey)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

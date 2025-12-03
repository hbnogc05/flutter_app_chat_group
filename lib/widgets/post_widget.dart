import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PostWidget extends StatelessWidget {
  final DocumentSnapshot post;

  const PostWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final data = post.data() as Map<String, dynamic>;
    final String? content = data['content'];
    final String? imageUrl = data['imageUrl'];
    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    final String authorName = data['authorName'] ?? 'Người dùng';
    final String? authorAvatarUrl = data['authorAvatarUrl'];
    final List<dynamic> likes = data['likes'] ?? [];
    // Giả sử comments là một mảng các sub-collection, ta chỉ cần đếm số lượng
    final int commentCount = 0; // Tạm thời, sẽ cần truy vấn sub-collection để có số chính xác

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(authorAvatarUrl, authorName, timestamp),
            if (content != null && content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Text(content, style: const TextStyle(fontSize: 15.0)),
              ),
            if (imageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity),
              ),
            const Divider(height: 1, color: Colors.black12),
            _buildPostActions(likes.length, commentCount),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(String? avatarUrl, String name, Timestamp timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
            child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person, size: 20) : null,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostActions(int likeCount, int commentCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _actionButton(Icons.thumb_up_outlined, 'Thích', likeCount.toString()),
          _actionButton(Icons.comment_outlined, 'Bình luận', commentCount.toString()),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, String count) {
    return TextButton.icon(
      onPressed: () { /* TODO: Implement action */ },
      icon: Icon(icon, color: Colors.grey.shade700),
      label: Text(
        '$label ($count)',
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy ''lúc'' HH:mm').format(date);
  }
}

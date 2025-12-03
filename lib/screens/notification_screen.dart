import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zalo_app/screens/friend_requests_screen.dart';
import 'package:zalo_app/screens/post_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  void _handleNotificationTap(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final bool isRead = data['isRead'] ?? false;
    final String type = data['type'] ?? '';

    // Mark as read
    if (!isRead) {
      await doc.reference.update({'isRead': true});
    }

    // Navigate based on type
    if (type == 'friend_request' && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => const FriendRequestsScreen(),
      ));
    } else if ((type == 'like' || type == 'comment' || type == 'reaction') && mounted) {
      final postId = data['postId'];
      if (postId != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => PostDetailScreen(postId: postId),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Theme scaffoldBackgroundColor is used
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bạn chưa có thông báo nào.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notificationDoc = snapshot.data!.docs[index];
              return _buildNotificationItem(notificationDoc);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String title = data['title'] ?? '';
    final String body = data['body'] ?? '';
    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    final bool isRead = data['isRead'] ?? false;
    final String type = data['type'] ?? '';

    IconData getIconForType(String type) {
        switch (type) {
            case 'friend_request':
                return Icons.person_add;
            case 'like':
            case 'reaction':
                return Icons.thumb_up;
            case 'comment':
                return Icons.comment;
            default:
                return Icons.notifications;
        }
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      child: ListTile(
        tileColor: isRead ? Colors.transparent : Colors.blue.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(getIconForType(type), color: Colors.blue.shade700),
        ),
        title: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMd().add_Hm().format(timestamp.toDate()),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(doc),
      ),
    );
  }
}

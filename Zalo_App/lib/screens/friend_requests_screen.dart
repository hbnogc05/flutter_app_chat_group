// lib/screens/friend_requests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _acceptRequest(String requestId, String senderId) async {
    if (_currentUser == null) return;

    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
    final senderRef = FirebaseFirestore.instance.collection('users').doc(senderId);

    // Thêm bạn bè cho cả hai người
    await currentUserRef.update({
      'friends': FieldValue.arrayUnion([senderId])
    });
    await senderRef.update({
      'friends': FieldValue.arrayUnion([_currentUser!.uid])
    });

    // Xóa lời mời đã chấp nhận
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).delete();
  }

  Future<void> _deleteRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Using theme scaffoldBackgroundColor (Light Blue)
      appBar: AppBar(
        title: const Text('Lời mời kết bạn'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('friend_requests')
            .where('recipientId', isEqualTo: _currentUser!.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Đã có lỗi xảy ra.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bạn không có lời mời kết bạn nào.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: snapshot.data!.docs.map((doc) => _buildRequestItem(doc)).toList()
          );
        },
      ),
    );
  }

  Widget _buildRequestItem(DocumentSnapshot requestDoc) {
    final requestData = requestDoc.data() as Map<String, dynamic>;
    final senderId = requestData['senderId'];

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();
        final senderData = userSnapshot.data!.data() as Map<String, dynamic>;
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0.5,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12.0),
            leading: CircleAvatar(
              radius: 28,
              backgroundImage: (senderData['photoURL'] != null && senderData['photoURL'].isNotEmpty)
                  ? NetworkImage(senderData['photoURL'])
                  : null,
              child: (senderData['photoURL'] == null || senderData['photoURL'].isEmpty) ? const Icon(Icons.person) : null,
            ),
            title: Text(senderData['displayName'] ?? '...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text('Đã gửi cho bạn lời mời kết bạn.'),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () => _acceptRequest(requestDoc.id, senderId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Đồng ý', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _deleteRequest(requestDoc.id),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text('Xóa', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

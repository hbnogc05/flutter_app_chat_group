// lib/screens/notifications_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  // --- HÀM MỚI: Chấp nhận lời mời ---
  Future<void> _acceptRequest(String requestId, String senderId) async {
    if (currentUser == null) return;

    try {
      // Cập nhật trạng thái lời mời thành 'accepted'
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'accepted'});

      // Thêm bạn bè cho cả hai người dùng
      // Thêm người gửi vào danh sách bạn bè của người nhận (mình)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'friends': FieldValue.arrayUnion([senderId])
      });

      // Thêm người nhận (mình) vào danh sách bạn bè của người gửi
      await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .update({
        'friends': FieldValue.arrayUnion([currentUser!.uid])
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã chấp nhận lời mời!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra: ${e.toString()}')),
      );
    }
  }

  // --- HÀM MỚI: Từ chối lời mời ---
  Future<void> _declineRequest(String requestId) async {
    try {
      // Cập nhật trạng thái lời mời thành 'declined'
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'declined'});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông báo')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Lấy tất cả lời mời gửi đến mình và có trạng thái là 'pending'
        stream: FirebaseFirestore.instance
            .collection('friend_requests')
            .where('receiverId', isEqualTo: currentUser!.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Không có lời mời kết bạn mới.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final requestData = doc.data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(requestData['senderEmail'] ?? 'Một người dùng'),
                subtitle: const Text('đã gửi cho bạn lời mời kết bạn.'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () =>
                          _acceptRequest(doc.id, requestData['senderId']),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _declineRequest(doc.id),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

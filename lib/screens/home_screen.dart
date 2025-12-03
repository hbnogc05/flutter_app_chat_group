// lib/screens/home_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/create_post_screen.dart';
import 'package:zalo_app/screens/profile_screen.dart';
import 'package:zalo_app/widgets/post_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập để xem bảng tin')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng tin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return Center(child: Text('Lỗi: ${userSnapshot.error}'));
          }
          
          if (userSnapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }

          List<dynamic> friends = [];
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            friends = userData?['friends'] ?? [];
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, postSnapshot) {
              if (postSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (postSnapshot.hasError) {
                return Center(child: Text('Đã xảy ra lỗi: ${postSnapshot.error}'));
              }
              if (!postSnapshot.hasData || postSnapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('Chưa có bài đăng nào. Hãy là người đầu tiên!'),
                );
              }

              final allPosts = postSnapshot.data!.docs;
              
              // Lọc bài viết: chỉ hiện bài của mình hoặc của bạn bè
              final visiblePosts = allPosts.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final authorId = data['authorId'];
                return authorId == _currentUser!.uid || friends.contains(authorId);
              }).toList();

              if (visiblePosts.isEmpty) {
                return const Center(
                  child: Text('Chưa có bài đăng nào từ bạn bè.'),
                );
              }

              return ListView.builder(
                itemCount: visiblePosts.length,
                itemBuilder: (context, index) {
                  return PostCard(post: visiblePosts[index]);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

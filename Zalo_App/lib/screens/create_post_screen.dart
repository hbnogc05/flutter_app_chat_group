// lib/screens/create_post_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/main_layout_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final content = _textController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (content.isEmpty || currentUser == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};

      // Tách nội dung thành các từ khóa để tìm kiếm
      final keywords = content.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();

      await FirebaseFirestore.instance.collection('posts').add({
        'content': content,
        'keywords': keywords, // Lưu lại danh sách từ khóa
        'authorId': currentUser.uid,
        'authorName': userData['displayName'] ?? 'Người dùng',
        'authorAvatarUrl': userData['photoURL'] ?? '',
        'timestamp': Timestamp.now(),
        'likes': [],
        'comments': [],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng bài thành công!')),
        );
        // Quay về màn hình chính và mở tab Tường nhà (index 3)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainLayoutScreen(initialIndex: 3)),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed backgroundColor: Colors.white to use theme default
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make app bar transparent
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tạo bài viết',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: Text(
              'ĐĂNG',
              style: TextStyle(color: _isLoading ? Colors.grey : Colors.blue, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _textController,
                  autofocus: true,
                  maxLines: null, 
                  expands: true, 
                  decoration: const InputDecoration(
                    hintText: 'Bạn đang nghĩ gì?',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
    );
  }
}

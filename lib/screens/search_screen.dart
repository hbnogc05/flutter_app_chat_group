// lib/screens/search_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  String _searchKeyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchKeyword = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchKeyword = keyword;
      _searchResults = [];
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Lấy tất cả các cuộc trò chuyện của người dùng
    final chatsSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    List<Map<String, dynamic>> results = [];

    // Duyệt qua từng cuộc trò chuyện và tìm kiếm tin nhắn
    for (var chatDoc in chatsSnapshot.docs) {
      final messagesSnapshot = await chatDoc.reference.collection('messages').get();
      
      final matchingMessages = messagesSnapshot.docs.where((msgDoc) {
        final msgData = msgDoc.data();
        final text = msgData['text'] as String?;
        return text?.toLowerCase().contains(keyword.toLowerCase()) ?? false;
      }).toList();

      if (matchingMessages.isNotEmpty) {
        // Nếu tìm thấy, lấy thông tin của người nhận để hiển thị
        final chatData = chatDoc.data();
        final List<dynamic> participants = chatData['participants'] ?? [];
        final otherUserId = participants.firstWhere((id) => id != currentUser.uid, orElse: () => null);

        if (otherUserId != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            results.add({
              'chatId': chatDoc.id,
              'receiverId': otherUserId,
              'receiverName': userData['displayName'] ?? 'Người dùng',
              'receiverAvatarUrl': userData['photoURL'] ?? '',
              'matchCount': matchingMessages.length,
            });
          }
        }
      }
    }

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm tin nhắn'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nhập nội dung cần tìm...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _performSearch,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchKeyword.isEmpty) {
      return const Center(child: Text('Nhập từ khóa để tìm kiếm trong lịch sử trò chuyện.'));
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text('Không tìm thấy kết quả nào.'));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: (result['receiverAvatarUrl'] as String).isNotEmpty
                ? NetworkImage(result['receiverAvatarUrl'])
                : null,
            child: (result['receiverAvatarUrl'] as String).isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(result['receiverName']),
          subtitle: Text('${result['matchCount']} tin nhắn khớp'),
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
                  chatId: result['chatId'],
                  receiverId: result['receiverId'],
                  receiverName: result['receiverName'],
                  receiverAvatarUrl: result['receiverAvatarUrl'],
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          },
        );
      },
    );
  }
}

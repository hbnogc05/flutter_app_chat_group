import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zalo_app/screens/main_layout_screen.dart';
import 'package:zalo_app/screens/music_selection_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  bool _isLoading = false;
  XFile? _imageFile;
  Map<String, dynamic>? _selectedSong;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = image;
    });
  }

  Future<void> _selectMusic() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(builder: (context) => const MusicSelectionScreen()),
    );
    if (result != null) {
      setState(() {
        _selectedSong = result;
      });
    }
  }

  Future<String?> _uploadFile(XFile file) async {
    if (currentUser == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref('posts_media').child('${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}');
      final uploadTask = await ref.putFile(File(file.path));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  final currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _createPost() async {
    if (currentUser == null || (_textController.text.trim().isEmpty && _imageFile == null && _selectedSong == null)) {
      return;
    }

    setState(() => _isLoading = true);

    String? mediaUrl;
    if (_imageFile != null) {
      mediaUrl = await _uploadFile(_imageFile!);
      if (mediaUrl == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi tải lên tệp đa phương tiện.')));
        return;
      }
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      final userData = userDoc.data() ?? {};
      final content = _textController.text.trim();
      final keywords = content.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();

      await FirebaseFirestore.instance.collection('posts').add({
        'content': content,
        'imageUrl': mediaUrl, 
        'songInfo': _selectedSong,
        'keywords': keywords, 
        'authorId': currentUser!.uid,
        'authorName': userData['displayName'] ?? 'Người dùng',
        'authorAvatarUrl': userData['photoURL'] ?? '',
        'timestamp': Timestamp.now(),
        'likes': [],
        'comments': [],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng bài thành công!')));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainLayoutScreen(initialIndex: 3)),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xảy ra lỗi: $e')));
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Tạo bài viết', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: Text('ĐĂNG', style: TextStyle(color: _isLoading ? Colors.grey : Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _textController,
                          autofocus: true,
                          maxLines: null, 
                          decoration: const InputDecoration(
                            hintText: 'Bạn đang nghĩ gì?',
                            border: InputBorder.none,
                          ),
                        ),
                        if (_imageFile != null)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(_imageFile!.path)),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _imageFile = null),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedSong != null)
                            Card(
                              margin: const EdgeInsets.only(top: 16),
                              child: ListTile(
                                leading: const Icon(Icons.music_note, color: Colors.blueAccent),
                                title: Text(_selectedSong!['name'] ?? ''),
                                subtitle: Text(_selectedSong!['artist'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() => _selectedSong = null),
                                ),
                              ),
                            )
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                _buildActionToolbar(),
              ],
            ),
    );
  }

  Widget _buildActionToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(icon: Icons.photo_library, label: 'Ảnh/Video', onTap: _pickImage),
          _buildActionButton(icon: Icons.person_add, label: 'Gắn thẻ', onTap: () {}), // Placeholder
          _buildActionButton(icon: Icons.music_note, label: 'Nhạc', onTap: _selectMusic),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

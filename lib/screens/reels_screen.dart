// lib/screens/reels_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:zalo_app/services/storage_service.dart';

// Màn hình chính của Reels, tải danh sách video
class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  // Hàm điều hướng đến trang tải video lên
  void _navigateAndUpload(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadReelScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Reels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            onPressed: () => _navigateAndUpload(context),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('reels').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Đã xảy ra lỗi khi tải video!', style: TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Chưa có video nào.', style: TextStyle(color: Colors.white)),
            );
          }
          var videos = snapshot.data!.docs;
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final videoData = videos[index].data() as Map<String, dynamic>?;
              if (videoData == null) {
                return const Center(child: Text('Lỗi dữ liệu video.', style: TextStyle(color: Colors.white)));
              }
              return ReelPlayer(videoData: videoData, videoId: videos[index].id);
            },
          );
        },
      ),
    );
  }
}

// (Các widget ReelPlayer và _ReelPlayerState giữ nguyên như trước...)
// ...

// --- THÊM MỚI: Màn hình để tải video lên ---
class UploadReelScreen extends StatefulWidget {
  const UploadReelScreen({super.key});

  @override
  State<UploadReelScreen> createState() => _UploadReelScreenState();
}

class _UploadReelScreenState extends State<UploadReelScreen> {
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final _captionController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;

  File? _videoFile;
  bool _isLoading = false;

  // Hàm chọn video từ thư viện
  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _videoFile = File(video.path);
      });
    }
  }

  // Hàm tải video và dữ liệu lên Firebase
  Future<void> _uploadReel() async {
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn một video.')));
      return;
    }
    if (_currentUser == null) return;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // 1. Tải video lên Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoPath = 'reels/${_currentUser!.uid}/$timestamp.mp4';
      final videoUrl = await _storageService.uploadVideo(videoPath, _videoFile!);

      // 2. Lấy thông tin người dùng hiện tại
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      final userName = userDoc.data()?['displayName'] ?? _currentUser!.email;

      // 3. Thêm tài liệu mới vào collection 'reels'
      await FirebaseFirestore.instance.collection('reels').add({
        'videoUrl': videoUrl,
        'caption': _captionController.text.trim(),
        'userId': _currentUser!.uid,
        'userName': userName,
        'likes': [],
        'timestamp': FieldValue.serverTimestamp(),
      });

      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Đăng video thành công!')));
      navigator.pop(); // Quay lại màn hình Reels

    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Đăng video thất bại: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng video mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _videoFile == null
                    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.video_call, size: 50), Text('Nhấn để chọn video')]))
                    : const Center(child: Icon(Icons.check_circle, color: Colors.green, size: 50)), // Có thể thay bằng thumbnail
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả video...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _uploadReel,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: _isLoading ? const CircularProgressIndicator() : const Text('Đăng'),
            ),
          ],
        ),
      ),
    );
  }
}


// --- PHẦN REEL PLAYER (GIỮ NGUYÊN) ---
class ReelPlayer extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final String videoId;
  const ReelPlayer({super.key, required this.videoData, required this.videoId});

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final videoUrl = widget.videoData['videoUrl'] as String?;

    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _initializeVideoPlayerFuture = _videoController!.initialize().then((_) {
        _videoController!.play();
        _videoController!.setLooping(true);
        if (mounted) {
          setState(() {});
        }
      });
    } else {
       _initializeVideoPlayerFuture = Future.value();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleLike() {
    if (_currentUser == null) return;
    DocumentReference reelRef = FirebaseFirestore.instance.collection('reels').doc(widget.videoId);
    List<dynamic> likes = widget.videoData['likes'] ?? [];
    if (likes.contains(_currentUser!.uid)) {
      reelRef.update({'likes': FieldValue.arrayRemove([_currentUser!.uid])});
    } else {
      reelRef.update({'likes': FieldValue.arrayUnion([_currentUser!.uid])});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_videoController == null) {
        return const Center(child: Text('Lỗi: Không tìm thấy URL của video.', style: TextStyle(color: Colors.white)));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && _videoController!.value.isInitialized) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                  });
                },
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
        _buildUIVerlay(),
      ],
    );
  }

  Widget _buildUIVerlay() {
    List<dynamic> likes = widget.videoData['likes'] ?? [];
    String userName = widget.videoData['userName'] ?? 'Người dùng';
    String caption = widget.videoData['caption'] ?? ''; 
    bool isLiked = _currentUser != null && likes.contains(_currentUser!.uid);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(caption, style: const TextStyle(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.white, size: 30), onPressed: _toggleLike),
              Text('${likes.length}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 15),
              IconButton(icon: const Icon(Icons.comment, color: Colors.white, size: 30), onPressed: () {}),
              const Text('0', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 15),
              IconButton(icon: const Icon(Icons.share, color: Colors.white, size: 30), onPressed: () {}),
              const Text('0', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 50), 
            ],
          ),
        ],
      ),
    );
  }
}

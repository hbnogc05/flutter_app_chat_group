// lib/screens/gallery_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zalo_app/services/storage_service.dart';

class GalleryScreen extends StatefulWidget {
  final String userId;

  const GalleryScreen({super.key, required this.userId});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  late Future<List<String>> _imageUrlsFuture;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  void _loadImages() {
    _imageUrlsFuture = _storageService.listUserImages(widget.userId);
  }

  Future<void> _uploadNewImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Đang tải ảnh lên...')));

    try {
      final file = File(image.path);
      // Tạo tên file độc nhất dựa trên timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'user_images/${widget.userId}/album/$timestamp.jpg';

      // Upload and get URL
      final downloadUrl = await _storageService.uploadImage(path, file);

      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Tải lên thành công!')));

      // Automatically return the new image URL
      if (mounted) {
        Navigator.of(context).pop(downloadUrl);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Tải lên thất bại: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho ảnh của bạn'),
      ),
      body: FutureBuilder<List<String>>(
        future: _imageUrlsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Không thể tải kho ảnh.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Kho ảnh của bạn trống. Hãy tải lên ảnh mới!'));
          }

          final imageUrls = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = imageUrls[index];
              return GestureDetector(
                onTap: () {
                  // Khi người dùng chọn một ảnh, trả về URL của ảnh đó cho màn hình Profile
                  Navigator.of(context).pop(imageUrl);
                },
                child: Image.network(imageUrl, fit: BoxFit.cover),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadNewImage,
        child: const Icon(Icons.add_a_photo),
        tooltip: 'Tải lên ảnh mới',
      ),
    );
  }
}

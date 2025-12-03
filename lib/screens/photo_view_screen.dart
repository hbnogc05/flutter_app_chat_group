import 'package:flutter/material.dart';

class PhotoViewScreen extends StatelessWidget {
  final String imageUrl;
  final String imageType; // 'avatar' or 'cover'
  final bool isMyProfile;

  const PhotoViewScreen({
    super.key, 
    required this.imageUrl,
    required this.imageType,
    required this.isMyProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: imageUrl, // Sử dụng imageUrl làm tag cho animation
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 100,
            ),
          ),
        ),
      ),
      // Chúng ta sẽ thêm các nút chức năng ở đây trong bước tiếp theo
      bottomNavigationBar: isMyProfile ? _buildActionButtons(context) : null,
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return BottomAppBar(
      color: Colors.black.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton.icon(
              onPressed: () {
                // TODO: Logic thay đổi ảnh
              },
              icon: const Icon(Icons.photo_library, color: Colors.white),
              label: const Text('Thay đổi', style: TextStyle(color: Colors.white)),
            ),
            TextButton.icon(
              onPressed: () {
                // TODO: Logic xóa ảnh
              },
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: const Text('Xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

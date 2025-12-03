// lib/services/storage_service.dart
import 'dart:io';
import 'dart:typed_data'; 
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Hàm tải ảnh lên và trả về URL
  Future<String> uploadImage(String path, File file) async {
    try {
      final Uint8List imageBytes = await file.readAsBytes();
      final ref = _storage.ref(path);
      UploadTask uploadTask = ref.putData(imageBytes);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Lỗi khi tải ảnh lên: $e');
      rethrow;
    }
  }

  // THÊM MỚI: Hàm tải video
  Future<String> uploadVideo(String path, File file) async {
    try {
      final ref = _storage.ref(path);
      // Sử dụng putFile cho các tệp lớn như video để quản lý bộ nhớ tốt hơn
      UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Lỗi khi tải video lên: $e');
      rethrow;
    }
  }

  // Hàm lấy danh sách URL của tất cả ảnh trong kho của người dùng
  Future<List<String>> listUserImages(String userId) async {
    try {
      final ref = _storage.ref('user_images/$userId/album');
      final result = await ref.listAll();
      final sortedItems = result.items..sort((a, b) => b.name.compareTo(a.name));
      final urls = await Future.wait(
        sortedItems.map((Reference item) => item.getDownloadURL()),
      );
      return urls;
    } catch (e) {
      print('Lỗi khi lấy danh sách ảnh: $e');
      return [];
    }
  }
}

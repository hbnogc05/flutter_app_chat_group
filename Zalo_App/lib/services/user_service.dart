import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Hàm cập nhật thông tin người dùng
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      // Sao chép data để không thay đổi map gốc
      final Map<String, dynamic> updatedData = Map<String, dynamic>.from(data);

      // Nếu người dùng đang cập nhật tên hiển thị
      if (updatedData.containsKey('displayName')) {
        final displayName = updatedData['displayName'] as String;
        // Tự động thêm hoặc cập nhật trường lowercase
        updatedData['displayName_lowercase'] = displayName.toLowerCase();
      }

      // 1. Cập nhật dữ liệu mới lên Firestore (Ưu tiên hàng đầu)
      // Sử dụng set với merge: true để an toàn hơn nếu document chưa tồn tại
      await _firestore.collection('users').doc(uid).set(updatedData, SetOptions(merge: true));
      
      // 2. Cập nhật FirebaseAuth profile (Phụ)
      try {
        if (_auth.currentUser != null && _auth.currentUser!.uid == uid) {
          if (updatedData.containsKey('displayName')) {
            await _auth.currentUser!.updateDisplayName(updatedData['displayName']);
          }
          if (updatedData.containsKey('photoURL')) {
            await _auth.currentUser!.updatePhotoURL(updatedData['photoURL']);
          }
          // Reload để áp dụng thay đổi ngay lập tức trong session hiện tại
          await _auth.currentUser!.reload();
        }
      } catch (e) {
        print("Lỗi đồng bộ FirebaseAuth: $e");
      }

      // 3. Đồng bộ với SharedPreferences (Phụ)
      try {
        if (_auth.currentUser != null && _auth.currentUser!.uid == uid) {
           await _syncToSharedPreferences(uid, updatedData);
        }
      } catch (e) {
        print("Lỗi đồng bộ SharedPreferences: $e");
      }

    } catch (e) {
      print("Lỗi khi cập nhật dữ liệu người dùng: $e");
      rethrow;
    }
  }

  Future<void> updateUserStatus(bool isOnline) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': isOnline,
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print("Lỗi cập nhật trạng thái hoạt động: $e");
    }
  }

  Future<void> _syncToSharedPreferences(String uid, Map<String, dynamic> updatedFields) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedAccounts = prefs.getStringList('saved_accounts') ?? [];
      
      // Tìm tài khoản trong danh sách
      int index = -1;
      Map<String, dynamic>? existingAccount;
      
      for (int i = 0; i < savedAccounts.length; i++) {
        try {
          final acc = jsonDecode(savedAccounts[i]) as Map<String, dynamic>;
          if (acc['uid'] == uid) {
            index = i;
            existingAccount = acc;
            break;
          }
        } catch (e) {
          // Bỏ qua lỗi parse json nếu có
        }
      }

      // Nếu chưa có trong saved_accounts nhưng là user hiện tại, có thể muốn thêm mới
      // Nhưng ở đây chỉ cập nhật nếu đã tồn tại để tránh logic phức tạp
      if (index != -1 && existingAccount != null) {
        // Cập nhật các trường
        if (updatedFields.containsKey('displayName')) {
           existingAccount['displayName'] = updatedFields['displayName'];
        }
        if (updatedFields.containsKey('photoURL')) {
           existingAccount['photoURL'] = updatedFields['photoURL'];
        }
        if (updatedFields.containsKey('coverPhotoURL')) {
           existingAccount['coverPhotoURL'] = updatedFields['coverPhotoURL'];
        }
        
        // Lưu lại
        savedAccounts[index] = jsonEncode(existingAccount);
        await prefs.setStringList('saved_accounts', savedAccounts);
      }
    } catch (e) {
       print("Lỗi khi đồng bộ SharedPreferences: $e");
    }
  }
}

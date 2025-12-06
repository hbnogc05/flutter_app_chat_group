import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/main_layout_screen.dart';
import 'package:zalo_app/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            // SỬA LỖI: Xóa từ khóa `const` ở đây.
            // Điều này đảm bảo MainLayoutScreen chỉ được tạo SAU KHI đăng nhập thành công.
            return MainLayoutScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

// lib/screens/signup_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      User? newUser = userCredential.user;
      if (newUser != null) {
        // Tự động tạo displayName từ email
        final email = newUser.email!;
        final displayName = email.split('@')[0];

        await FirebaseFirestore.instance.collection('users').doc(newUser.uid).set({
          'uid': newUser.uid,
          'email': email,
          'displayName': displayName,
          'displayName_lowercase': displayName.toLowerCase(), // Thêm trường mới
          'bio': '', 
          'photoURL': '',
          'createdAt': Timestamp.now(), 
          'friends': [],
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng ký thành công! Vui lòng đăng nhập.')),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      String message = e.code == 'weak-password' ? 'Mật khẩu quá yếu.' : e.code == 'email-already-in-use' ? 'Email này đã được sử dụng.' : 'Đã xảy ra lỗi.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changePage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 120),
            Text('Tạo tài khoản', style: TextStyle(color: Colors.blue[800], fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildToggleButtons(),
            const SizedBox(height: 10),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildEmailForm(),
                  _buildPhoneForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButtons() {
     return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _changePage(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _currentPage == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(child: Text('Email', style: TextStyle(color: _currentPage == 0 ? Colors.blue[800] : Colors.black54, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _changePage(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _currentPage == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(child: Text('Số điện thoại', style: TextStyle(color: _currentPage == 1 ? Colors.blue[800] : Colors.black54, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Form(
        key: _emailFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
               style: const TextStyle(color: Colors.black),
              decoration: _inputDecoration('Email'),
              validator: (value) => (value == null || !value.contains('@')) ? 'Vui lòng nhập email hợp lệ' : null,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
               style: const TextStyle(color: Colors.black),
              decoration: _inputDecoration('Mật khẩu'),
              validator: (value) => (value == null || value.length < 6) ? 'Mật khẩu phải có ít nhất 6 ký tự' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
               style: const TextStyle(color: Colors.black),
              decoration: _inputDecoration('Xác nhận mật khẩu'),
              validator: (value) => (value != _passwordController.text) ? 'Mật khẩu không khớp' : null,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _signUpWithEmail,
              style: _buttonStyle(),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('ĐĂNG KÝ'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đã có tài khoản? Đăng nhập', style: TextStyle(color: Colors.blue[900])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneForm() {
    return const Center(
      child: Text('Chức năng đăng ký bằng số điện thoại sẽ được phát triển sau.', style: TextStyle(color: Colors.black54)),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      hintText: label,
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue, width: 2)),
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

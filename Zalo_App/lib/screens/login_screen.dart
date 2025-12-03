// lib/screens/login_screen.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zalo_app/screens/main_layout_screen.dart';
import 'package:zalo_app/screens/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? email;
  const LoginScreen({super.key, this.email});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _emailFormKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _phonePasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
    if (widget.email != null) {
      _currentPage = 0; // Ensure email tab is selected
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _phonePasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveAccountInfo(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final accountInfo = {
      'uid': user.uid,
      'email': user.email,
      'displayName': userData['displayName'] ?? '',
      'photoURL': userData['photoURL'] ?? '',
    };

    List<String> savedAccounts = prefs.getStringList('saved_accounts') ?? [];
    // Remove existing entry to avoid duplicates and to update info
    savedAccounts.removeWhere((account) => jsonDecode(account)['uid'] == user.uid);
    savedAccounts.add(jsonEncode(accountInfo));

    await prefs.setStringList('saved_accounts', savedAccounts);
  }

  Future<void> _loginWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await _saveAccountInfo(userCredential.user!);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainLayoutScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = 'Email hoặc mật khẩu không đúng.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _loginWithPhone() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chức năng này đang được phát triển.')),
      );
    }
  }

  void _navigateToSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SignupScreen()),
    );
  }

  void _changePage(int page) {
    if (widget.email != null) return;
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
            Text(
              widget.email != null ? 'Chào mừng trở lại' : 'Đăng nhập',
              style: TextStyle(color: Colors.blue[800], fontSize: 32, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 20),
            if (widget.email == null) _buildToggleButtons(),
            const SizedBox(height: 10),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: widget.email != null ? const NeverScrollableScrollPhysics() : null,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildEmailForm(),
                  if (widget.email == null) _buildPhoneForm(),
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
              readOnly: widget.email != null,
              style: TextStyle(color: widget.email != null ? Colors.grey[700] : Colors.black),
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
              validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
              autofocus: widget.email != null,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _loginWithEmail,
              style: _buttonStyle(),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('ĐĂNG NHẬP'),
            ),
            if (widget.email == null)
            TextButton(
              onPressed: _navigateToSignUp,
              child: Text('Chưa có tài khoản? Đăng ký ngay', style: TextStyle(color: Colors.blue[900])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Form(
        key: _phoneFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _phoneController,
              style: const TextStyle(color: Colors.black),
              decoration: _inputDecoration('Số điện thoại'),
              validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập số điện thoại' : null,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phonePasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.black),
              decoration: _inputDecoration('Mật khẩu'),
              validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _loginWithPhone,
              style: _buttonStyle(),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('ĐĂNG NHẬP'),
            ),
            TextButton(
              onPressed: _navigateToSignUp,
              child: Text('Chưa có tài khoản? Đăng ký ngay', style: TextStyle(color: Colors.blue[900])),
            ),
          ],
        ),
      ),
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

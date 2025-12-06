// lib/screens/account_switcher_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zalo_app/screens/login_screen.dart';
import 'package:zalo_app/screens/signup_screen.dart';

class AccountSwitcherScreen extends StatefulWidget {
  const AccountSwitcherScreen({super.key});

  @override
  State<AccountSwitcherScreen> createState() => _AccountSwitcherScreenState();
}

class _AccountSwitcherScreenState extends State<AccountSwitcherScreen> {
  Future<List<Map<String, dynamic>>> _getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedAccountsString = prefs.getStringList('saved_accounts') ?? [];
    return savedAccountsString
        .map((account) => jsonDecode(account) as Map<String, dynamic>)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Zalo',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 50),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getSavedAccounts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Chưa có tài khoản nào được lưu.'));
                    }
                    final accounts = snapshot.data!;
                    return ListView.builder(
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        return _buildAccountItem(
                          context,
                          name: account['displayName'] ?? 'Người dùng',
                          email: account['email'] ?? '',
                          avatarUrl: account['photoURL'] ?? '',
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildAuthButton(
                context,
                title: 'Đăng nhập bằng tài khoản khác',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildAuthButton(
                context,
                title: 'Tạo tài khoản mới',
                isPrimary: false,
                onPressed: () {
                   Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, {required String name, required String email, required String avatarUrl}) {
    return GestureDetector(
       onTap: () { 
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => LoginScreen(email: email)),
          );
        },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 28) : null,
            ),
            const SizedBox(width: 16),
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthButton(BuildContext context, {required String title, required VoidCallback onPressed, bool isPrimary = true}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.white.withOpacity(0.8) : Colors.transparent,
          foregroundColor: isPrimary ? Colors.black : Colors.blue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: isPrimary ? BorderSide.none : const BorderSide(color: Colors.blue, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

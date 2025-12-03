import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/add_card_screen.dart';
import 'package:zalo_app/screens/change_password_screen.dart';
import 'package:zalo_app/screens/edit_profile_info_screen.dart';
import 'package:zalo_app/screens/faq_screen.dart';
import 'package:zalo_app/screens/login_screen.dart';
import 'package:zalo_app/screens/terms_of_use_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'PROFILE SETTING',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildProfileHeader(currentUser),
          const SizedBox(height: 24),
          _buildSection('General', [
            _buildSettingsItem(Icons.person_outline, 'Edit Profile', 'Change profile picture, number, E-mail', () {
               Navigator.of(context).push(MaterialPageRoute(builder: (context) => const EditProfileInfoScreen()));
            }),
            _buildSettingsItem(Icons.lock_outline, 'Change Password', 'Update and strengthen account security', () {
               Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ChangePasswordScreen()));
            }),
            _buildSettingsItem(Icons.policy_outlined, 'Terms of Use', 'Protect your account now', () {
               Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TermsOfUseScreen()));
            }),
            _buildSettingsItem(Icons.credit_card_outlined, 'Add Card', 'Securely add payment method', () {
               Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddCardScreen()));
            }),
          ]),
          const SizedBox(height: 24),
           _buildSection('Preferences', [
            _buildNotificationToggle(),
            _buildSettingsItem(Icons.help_outline, 'FAQ', 'Securely add payment method', () {
               Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FaqScreen()));
            }),
            _buildSettingsItem(Icons.logout, 'Log Out', 'Securely log out of Account', () async {
                 await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
            }, isLogout: true),
          ]),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(User? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null ? const Icon(Icons.person, size: 30) : null,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user?.displayName ?? 'User Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text(user?.email ?? 'user.email@example.com', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: children.length,
            itemBuilder: (context, index) => children[index],
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle, VoidCallback onTap, {bool isLogout = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: isLogout ? Colors.red : Colors.blueAccent),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isLogout ? Colors.red : Colors.black)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: isLogout ? null : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildNotificationToggle() {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: const Icon(Icons.notifications_outlined, color: Colors.blueAccent),
      title: const Text('Notification', style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: const Text('Customize your notification preferences', style: TextStyle(color: Colors.grey, fontSize: 12)),
      value: true, // Placeholder value
      onChanged: (bool value) {
        // TODO: Implement notification preference logic
      },
      activeColor: Colors.blueAccent,
    );
  }
}

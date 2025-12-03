import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zalo_app/services/user_service.dart';

class EditProfileInfoScreen extends StatefulWidget {
  const EditProfileInfoScreen({super.key});

  @override
  State<EditProfileInfoScreen> createState() => _EditProfileInfoScreenState();
}

class _EditProfileInfoScreenState extends State<EditProfileInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nickNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _nameController.text = data['displayName'] ?? '';
        _nickNameController.text = data['nickName'] ?? ''; // Assuming 'nickName' field
        _emailController.text = currentUser!.email ?? '';
        _phoneController.text = data['phoneNumber'] ?? ''; // Assuming 'phoneNumber' field
        if (data['birthday'] != null) {
          final DateTime dob = (data['birthday'] as Timestamp).toDate();
          _dobController.text = DateFormat('dd.MM.yyyy').format(dob);
        }
      }
    } catch (e) {
      // Handle error, maybe show a snackbar
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nickNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (currentUser == null || !_formKey.currentState!.validate()) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Convert date string back to Timestamp
    DateTime? dob;
    try {
      dob = DateFormat('dd.MM.yyyy').parse(_dobController.text);
    } catch (e) {
      // Handle invalid date format if necessary
    }

    Map<String, dynamic> dataToUpdate = {
      'displayName': _nameController.text.trim(),
      'nickName': _nickNameController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'birthday': dob != null ? Timestamp.fromDate(dob) : null,
      // Email is usually handled by Firebase Auth, not directly in Firestore
    };

    try {
      await _userService.updateUserData(currentUser!.uid, dataToUpdate);
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
      navigator.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('EDIT PROFILE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildAvatar(),
                  const SizedBox(height: 32),
                  _buildTextField(label: 'Name', controller: _nameController),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Nick Name', controller: _nickNameController),
                  const SizedBox(height: 16),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Phone Number', controller: _phoneController, keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Date of birth', controller: _dobController, readOnly: true, onTap: _selectDate),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saveProfile,
                    child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dobController.text.isNotEmpty ? DateFormat('dd.MM.yyyy').parse(_dobController.text) : DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: currentUser?.photoURL != null ? NetworkImage(currentUser!.photoURL!) : null,
          child: currentUser?.photoURL == null ? const Icon(Icons.person, size: 60) : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300)
            ),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.camera_alt, color: Colors.black, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, TextInputType? keyboardType, bool readOnly = false, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Email', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          readOnly: true, // Email is not editable
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: () { /* TODO: Implement email verification */ },
                child: const Text('Verify', style: TextStyle(color: Colors.blueAccent)),
                 style: TextButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

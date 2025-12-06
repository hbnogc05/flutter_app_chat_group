// lib/screens/kham_pha_screen.dart
import 'package:flutter/material.dart';

class KhamPhaScreen extends StatelessWidget {
  const KhamPhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khám phá'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Text('Nội dung trang Khám phá', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

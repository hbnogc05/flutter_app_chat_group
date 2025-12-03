import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MusicSelectionScreen extends StatefulWidget {
  const MusicSelectionScreen({super.key});

  @override
  State<MusicSelectionScreen> createState() => _MusicSelectionScreenState();
}

class _MusicSelectionScreenState extends State<MusicSelectionScreen> {
  final Stream<QuerySnapshot> _songsStream = FirebaseFirestore.instance.collection('songs').snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn nhạc nền'),
        backgroundColor: Colors.white,
        elevation: 1,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _songsStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          // --- BƯỚC 1: HIỂN THỊ LỖI NẾU CÓ ---
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Đã có lỗi xảy ra!\n\nLỗi: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          // --- BƯỚC 2: HIỂN THỊ TRẠNG THÁI ĐANG TẢI ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang tải danh sách nhạc...'),
                ],
              ),
            );
          }

          // --- BƯỚC 3: HIỂN THỊ KHI KHÔNG TÌM THẤY BÀI HÁT ---
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  const Text(
                    'Không tìm thấy bài hát nào.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vui lòng kiểm tra lại thiết lập trên Firebase.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // --- BƯỚC 4: HIỂN THỊ DANH SÁCH NẾU MỌI THỨ OK ---
          return ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              String songName = data['songName'] ?? 'Không có tên';
              String artistName = data['artistName'] ?? 'Không rõ nghệ sĩ';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.blueAccent),
                  title: Text(songName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(artistName),
                  trailing: ElevatedButton(
                    child: const Text('Chọn'),
                    onPressed: () {
                      final selectedSong = {
                        'name': songName,
                        'artist': artistName,
                        'url': data['songUrl'] ?? '', 
                      }; 
                      Navigator.of(context).pop(selectedSong);
                    },
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

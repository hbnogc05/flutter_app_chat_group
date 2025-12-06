// lib/services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lấy hoặc tạo phòng chat giữa hai người dùng
  Future<String> getOrCreateChatRoom(String userId1, String userId2) async {
    // Đảm bảo ID được tạo nhất quán bằng cách sắp xếp userId
    List<String> participants = [userId1, userId2]..sort(); 
    String chatRoomId = participants.join('_'); 

    final chatRoomRef = _firestore.collection('chats').doc(chatRoomId);
    final chatRoom = await chatRoomRef.get();

    if (!chatRoom.exists) {
      // Nếu chưa tồn tại, tạo mới.
      // LƯU Ý: Không set 'lastMessageTimestamp' ở đây để tránh hiện thị trong ChatListScreen
      // khi chưa có tin nhắn nào.
      await chatRoomRef.set({
        'participants': participants,
        'lastMessage': '',
        // 'lastMessageTimestamp': FieldValue.serverTimestamp(), // Đã bỏ dòng này
        'unreadCount': {
          userId1: 0,
          userId2: 0,
        },
      });
    } else {
      // Nếu đã tồn tại nhưng thiếu trường participants hoặc unreadCount (do code cũ)
      // Update lại để đảm bảo tính nhất quán
       if (chatRoom.data() == null || !chatRoom.data()!.containsKey('participants')) {
          await chatRoomRef.update({'participants': participants});
       }
    }

    return chatRoomId;
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  // Singleton instance
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Stream danh sách chat
  Stream<QuerySnapshot> getChatListStream() {
    final uid = currentUserId;
    if (uid == null) return const Stream.empty();
    
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }

  // Lấy thông tin người dùng khác
  Future<DocumentSnapshot> getUserInfo(String userId) {
    return _firestore.collection('users').doc(userId).get();
  }

  // Cập nhật trạng thái chưa đọc (0: đã đọc, >0: chưa đọc)
  Future<void> updateUnreadCount(String chatId, int count) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount.$uid': count,
    });
  }

  // Ghim / Bỏ ghim cuộc trò chuyện
  Future<void> togglePinChat(String chatId, bool isPinned) async {
    final uid = currentUserId;
    if (uid == null) return;

    final chatRef = _firestore.collection('chats').doc(chatId);
    if (isPinned) {
      await chatRef.update({
        'pinnedBy': FieldValue.arrayRemove([uid])
      });
    } else {
      await chatRef.update({
        'pinnedBy': FieldValue.arrayUnion([uid])
      });
    }
  }

  // Bật / Tắt thông báo cuộc trò chuyện
  Future<void> toggleMuteChat(String chatId, bool isMuted) async {
    final uid = currentUserId;
    if (uid == null) return;

    final chatRef = _firestore.collection('chats').doc(chatId);
    if (isMuted) {
      await chatRef.update({
        'mutedBy': FieldValue.arrayRemove([uid])
      });
    } else {
      await chatRef.update({
        'mutedBy': FieldValue.arrayUnion([uid])
      });
    }
  }

  // Xóa cuộc trò chuyện (Soft delete)
  Future<void> deleteChat(String chatId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('chats').doc(chatId).set({
      'deletedBy': FieldValue.arrayUnion([uid])
    }, SetOptions(merge: true));
  }

  // --- MỚI: Logic từ ChatScreen ---

  // 1. Message Stream
  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 2. User Status Stream
  Stream<DocumentSnapshot> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // 3. Chat Document Stream
  Stream<DocumentSnapshot> getChatStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots();
  }

  // 4. Set User Online/Offline
  Future<void> setUserStatus(bool isOnline) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).set({
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error setting user status: $e");
    }
  }

  // 5. Mark Messages as Read
  Future<void> markMessagesAsRead(String chatId, String receiverId) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      // Cập nhật unreadCount của bản thân về 0
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount.$uid': 0,
      });

      // Đánh dấu các tin nhắn là đã đọc
      final querySnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: receiverId)
          .where('isRead', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in querySnapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  // 6. Send Message
  Future<void> sendMessage({
    required String chatId,
    String? text,
    String? imageUrl,
    String type = 'text',
    Map<String, dynamic>? replyTo,
    required String receiverId,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;
    if ((text == null || text.isEmpty) && imageUrl == null) return;

    final chatRef = _firestore.collection('chats').doc(chatId);

    Map<String, dynamic> messageData = {
      'senderId': uid,
      'timestamp': Timestamp.now(),
      'type': type,
      'deletedBy': [],
      'isRead': false,
    };

    if (text != null && text.isNotEmpty) {
      messageData['text'] = text;
    }
    if (imageUrl != null) {
      messageData['imageUrl'] = imageUrl;
    }

    if (replyTo != null) {
      messageData['replyTo'] = replyTo;
    }

    await chatRef.collection('messages').add(messageData);

    String notificationMessage = text ?? '';
    if (type == 'image') {
      notificationMessage = '[Hình ảnh]';
    } else if (type == 'audio') {
      notificationMessage = '[Tin nhắn thoại]';
    } else if (type == 'file') {
      notificationMessage = '[Tập tin] $text';
    } else if (type == 'sticker') {
      notificationMessage = '[Sticker]';
    }

    await chatRef.set({
      'lastMessage': notificationMessage,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadCount': {
        receiverId: FieldValue.increment(1),
      },
      'lastSenderId': uid,
      'users': FieldValue.arrayUnion([uid, receiverId]),
    }, SetOptions(merge: true));
  }

  // 7. Upload File (Generic)
  Future<String?> uploadFileToStorage(File file, String path, String contentType) async {
    try {
      Reference ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      UploadTask uploadTask = ref.putFile(file, metadata);
      TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        return await snapshot.ref.getDownloadURL();
      }
    } catch (e) {
      print("Error uploading file: $e");
    }
    return null;
  }

  // 8. Upload Data (Bytes - for ImagePicker sometimes)
  Future<String?> uploadDataToStorage(Uint8List data, String path, String contentType) async {
    try {
      Reference ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      UploadTask uploadTask = ref.putData(data, metadata);
      TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        return await snapshot.ref.getDownloadURL();
      }
    } catch (e) {
      print("Error uploading data: $e");
    }
    return null;
  }

  // 9. Toggle Reaction
  Future<void> toggleReaction(String chatId, String messageId, String emoji, Map<String, dynamic> currentReactions) async {
    final uid = currentUserId;
    if (uid == null) return;

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final newReactions = Map<String, dynamic>.from(currentReactions);
    final currentEmoji = newReactions[uid];

    if (currentEmoji == emoji) {
      newReactions.remove(uid);
    } else {
      newReactions[uid] = emoji;
    }

    await messageRef.update({'reactions': newReactions});
  }

  // 10. Unsend (Delete for everyone)
  Future<void> unsendMessage(String chatId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // 11. Delete for me
  Future<void> deleteMessageForMe(String chatId, String messageId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedBy': FieldValue.arrayUnion([uid])
    });
  }

  // 12. Update Chat Theme
  Future<void> updateChatTheme(String chatId, String themeId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'themeId': themeId,
    });
  }
}

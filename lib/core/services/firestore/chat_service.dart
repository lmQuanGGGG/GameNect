part of '../firestore_service.dart';

// ==================== CHAT & MESSAGING OPERATIONS ====================
// Quản lý tin nhắn, voice message, media, reactions và call logs

extension ChatServiceExtension on FirestoreService {
  // Lấy danh sách tin nhắn một lần (không realtime)
  Future<List<Map<String, dynamic>>> getMessages(String matchId) async {
    final snapshot = await _db
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .orderBy('timestamp')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Gửi tin nhắn text
  Future<void> sendMessage(String matchId, String text) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .add({
          'senderId': userId,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'text',
        });

    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': userId,
      'lastMessageRead': false,
    });
  }

  // Gửi tin nhắn kèm media (ảnh/video)
  Future<void> sendMessageWithMedia({
    required String matchId,
    required String text,
    String? mediaUrl,
    bool isVideo = false,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .add({
          'senderId': userId,
          'text': text,
          'mediaUrl': mediaUrl,
          'isVideo': isVideo,
          'timestamp': FieldValue.serverTimestamp(),
        });

    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMediaUrl': mediaUrl,
      'lastIsVideo': isVideo,
      'lastMessageSenderId': userId,
      'lastMessageRead': false,
    });
  }

  // Gửi media kèm notification
  Future<void> sendMediaWithNotify({
    required String matchId,
    required String mediaUrl,
    bool isVideo = false,
    String? caption,
    UserModel? peerUser,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .add({
          'senderId': userId,
          'mediaUrl': mediaUrl,
          'isVideo': isVideo,
          'caption': caption,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'media',
        });

    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'lastMessage': isVideo ? 'Đã gửi video' : 'Đã gửi hình ảnh',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMediaUrl': mediaUrl,
      'lastIsVideo': isVideo,
      'lastMessageSenderId': userId,
      'lastMessageRead': false,
    });
  }

  // Lưu log cuộc gọi vào messages
  Future<void> addCallMessage({
    required String matchId,
    String? senderId,
    required int duration,
    bool missed = false,
    bool declined = false,
    bool cancelled = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = senderId ?? user?.uid;
    if (uid == null) return;

    String callStatus;
    String text;

    if (cancelled) {
      callStatus = 'cancelled';
      text = 'Đã hủy';
    } else if (declined) {
      callStatus = 'declined';
      text = 'Cuộc gọi bị từ chối';
    } else if (missed) {
      callStatus = 'missed';
      text = 'Cuộc gọi nhỡ';
    } else {
      callStatus = 'ended';
      final minutes = duration ~/ 60;
      final secs = duration % 60;
      if (minutes > 0) {
        text = 'Đã gọi $minutes phút${secs > 0 ? ' $secs giây' : ''}';
      } else {
        text = 'Đã gọi $secs giây';
      }
    }

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .add({
          'senderId': uid,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'call',
          'callStatus': callStatus,
          'duration': duration,
        });

    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': uid,
      'lastMessageRead': false,
    });
  }

  // Gửi voice message
  Future<void> sendVoiceMessage({
    required String matchId,
    required String audioUrl,
    int? duration,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .add({
          'senderId': userId,
          'audioUrl': audioUrl,
          'duration': duration,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'voice',
        });

    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'lastMessage': 'Đã gửi 1 tin nhắn thoại',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': userId,
      'lastMessageRead': false,
    });
  }

  // React vào tin nhắn (emoji)
  Future<void> reactToMessage({
    required String matchId,
    required String messageId,
    required String emoji,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // 1. Update reactions array trên message gốc
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .doc(messageId)
        .update({
          'reactions': FieldValue.arrayUnion([
            {'userId': userId, 'emoji': emoji},
          ]),
        });

    // 2. Tạo message react để stream nhận và gửi thông báo
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .add({
          'senderId': userId,
          'type': 'react',
          'emoji': emoji,
          'targetMessageId': messageId,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // 3. Cập nhật lastMessage cho match
    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'lastMessage': 'Đã thả cảm xúc $emoji',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': userId,
      'lastMessageRead': false,
    });
  }

  // Lấy tin nhắn cuối cùng trong một chat
  Future<Map<String, dynamic>?> getLastMessage(String matchId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(matchId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting last message: $e');
      return null;
    }
  }

  // Stream tin nhắn real-time
  Stream<List<Map<String, dynamic>>> messagesStream(String matchId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Đánh dấu tin nhắn đã đọc
  Future<void> markMatchAsRead(String matchId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    // Lấy thông tin match hiện tại để kiểm tra
    final doc = await FirebaseFirestore.instance.collection('matches').doc(matchId).get();
    final data = doc.data();
    if (data != null && data['lastMessageSenderId'] != userId) {
      await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
        'lastMessageRead': true,
      });
    }
  }

  // Cập nhật typing indicator
  Future<void> setTypingIndicator({
    required String matchId,
    required String userId,
    required bool isTyping,
  }) async {
    await FirebaseFirestore.instance.collection('chats').doc(matchId).set(
      {'${userId}_typing': isTyping},
      SetOptions(merge: true),
    );
  }

  // Chia sẻ Game vào đoạn chat
  Future<void> sendGameMessage({
    required String matchId,
    required GameModel game,
    UserModel? peerUser,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .add({
          'senderId': userId,
          'type': 'game',
          'gameId': game.id,
          'gameName': game.name,
          'gameImage': game.backgroundImage,
          'gameRating': game.rating,
          'timestamp': FieldValue.serverTimestamp(),
        });

    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'lastMessage': 'Đã chia sẻ một trò chơi',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': userId,
      'lastMessageRead': false,
    });
  }
}

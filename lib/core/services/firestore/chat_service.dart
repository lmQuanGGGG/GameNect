part of '../firestore_service.dart';

// ==================== CHAT & MESSAGING OPERATIONS ====================
// Quản lý tin nhắn, voice message, media, reactions và call logs

extension ChatServiceExtension on FirestoreService {
  static final Map<String, DateTime?> _clearedAtCache = {};
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
  Future<void> sendMessage(String matchId, String text, {Map<String, dynamic>? repliedMessage}) async {
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
          if (repliedMessage != null) ...{
            'repliedToId': repliedMessage['id'],
            'repliedToText': repliedMessage['text'],
            'repliedToSender': repliedMessage['senderId'],
            'repliedToType': repliedMessage['type'],
          }
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
    Map<String, dynamic>? repliedMessage,
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
          if (repliedMessage != null) ...{
            'repliedToId': repliedMessage['id'],
            'repliedToText': repliedMessage['text'],
            'repliedToSender': repliedMessage['senderId'],
            'repliedToType': repliedMessage['type'],
          }
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
    Map<String, dynamic>? repliedMessage,
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
          if (repliedMessage != null) ...{
            'repliedToId': repliedMessage['id'],
            'repliedToText': repliedMessage['text'],
            'repliedToSender': repliedMessage['senderId'],
            'repliedToType': repliedMessage['type'],
          }
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

  // Chuyển tiếp tin nhắn
  Future<void> forwardMessage(List<String> matchIds, Map<String, dynamic> originalMsg) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || matchIds.isEmpty) return;

    final Map<String, dynamic> newMsg = {
      'senderId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'isForwarded': true,
      'type': originalMsg['type'] ?? 'text',
      if (originalMsg['text'] != null) 'text': originalMsg['text'],
      if (originalMsg['mediaUrl'] != null) 'mediaUrl': originalMsg['mediaUrl'],
      if (originalMsg['isVideo'] != null) 'isVideo': originalMsg['isVideo'],
      if (originalMsg['audioUrl'] != null) 'audioUrl': originalMsg['audioUrl'],
      if (originalMsg['duration'] != null) 'duration': originalMsg['duration'],
      if (originalMsg['gameId'] != null) 'gameId': originalMsg['gameId'],
      if (originalMsg['gameName'] != null) 'gameName': originalMsg['gameName'],
      if (originalMsg['gameImageUrl'] != null) 'gameImageUrl': originalMsg['gameImageUrl'],
    };

    String lastMessageText = newMsg['text'] ?? 'Đã chuyển tiếp tin nhắn';
    if (newMsg['type'] == 'media') {
      lastMessageText = (newMsg['isVideo'] == true) ? 'Đã gửi video' : 'Đã gửi hình ảnh';
    } else if (newMsg['type'] == 'voice') {
      lastMessageText = 'Đã gửi tin nhắn thoại';
    } else if (newMsg['type'] == 'game') {
      lastMessageText = 'Đã chia sẻ một trò chơi';
    }

    final batch = FirebaseFirestore.instance.batch();

    for (final matchId in matchIds) {
      final msgRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(matchId)
          .collection('messages')
          .doc();
          
      batch.set(msgRef, newMsg);

      final matchRef = FirebaseFirestore.instance.collection('matches').doc(matchId);
      batch.update(matchRef, {
        'lastMessage': lastMessageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': userId,
        'lastMessageRead': false,
        if (newMsg['mediaUrl'] != null) 'lastMediaUrl': newMsg['mediaUrl'],
        if (newMsg['isVideo'] != null) 'lastIsVideo': newMsg['isVideo'],
      });
    }

    await batch.commit();
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

  // Lấy danh sách tin nhắn mới nhất (phục vụ preload)
  Future<List<Map<String, dynamic>>> getLatestMessages(String matchId, {int limit = 10}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    // Lấy thời điểm xóa chat của user hiện tại
    DateTime? clearedAt;
    if (userId != null) {
      final cacheKey = '${matchId}_$userId';
      if (_clearedAtCache.containsKey(cacheKey)) {
        clearedAt = _clearedAtCache[cacheKey];
      } else {
        try {
          final matchDoc = await FirebaseFirestore.instance
              .collection('matches')
              .doc(matchId)
              .get()
              .timeout(const Duration(seconds: 2));
          clearedAt = (matchDoc.data()?['clearedAt_$userId'] as Timestamp?)?.toDate();
          _clearedAtCache[cacheKey] = clearedAt;
        } catch (_) {}
      }
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(matchId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final messages = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final msgTime = (data['timestamp'] as Timestamp?)?.toDate();
        // Lọc bỏ các tin nhắn trước thời điểm xóa
        if (clearedAt != null && msgTime != null && !msgTime.isAfter(clearedAt)) {
          continue;
        }
        messages.add(data);
      }
      return messages.reversed.toList();
    } catch (e) {
      debugPrint('Error preloading messages: $e');
      return [];
    }
  }

  // Stream tin nhắn real-time
  Stream<List<Map<String, dynamic>>> messagesStream(String matchId) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .orderBy('timestamp', descending: true) // Sắp xếp giảm dần để lấy 50 tin mới nhất
        .limit(50) // Giới hạn 50 tin nhắn để tránh tốn Reads
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) {
            return <Map<String, dynamic>>[];
          }

          // Lấy thời điểm xóa chat của user hiện tại
          DateTime? clearedAt;
          if (userId != null) {
            final cacheKey = '${matchId}_$userId';
            if (_clearedAtCache.containsKey(cacheKey)) {
              clearedAt = _clearedAtCache[cacheKey];
            } else {
              try {
                final matchDoc = await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(matchId)
                    .get()
                    .timeout(const Duration(seconds: 2));
                clearedAt = (matchDoc.data()?['clearedAt_$userId'] as Timestamp?)?.toDate();
                _clearedAtCache[cacheKey] = clearedAt;
              } catch (_) {}
            }
          }

          final messages = <Map<String, dynamic>>[];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            final msgTime = (data['timestamp'] as Timestamp?)?.toDate();
            // Lọc bỏ các tin nhắn trước thời điểm xóa
            if (clearedAt != null && msgTime != null && !msgTime.isAfter(clearedAt)) {
              continue;
            }
            messages.add(data);
          }
          // Đảo ngược lại danh sách để tin mới nhất nằm ở dưới cùng theo đúng UI của Chat
          return messages.reversed.toList();
        });
  }

  // Đánh dấu tin nhắn đã đọc
  Future<void> markMatchAsRead(String matchId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    // Lấy thôngkiem tra
    final doc = await FirebaseFirestore.instance.collection('matches').doc(matchId).get();
    final data = doc.data();
    if (data != null && data['lastMessageSenderId'] != userId) {
      await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
        'lastMessageRead': true,
      });
    }
  }

  // Thu hồi tin nhắn
  Future<void> recallMessage(String matchId, String messageId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    final db = FirebaseFirestore.instance;
    final msgRef = db.collection('chats').doc(matchId).collection('messages').doc(messageId);
    final matchRef = db.collection('matches').doc(matchId);

    try {
      final msgSnapshot = await msgRef.get();
      if (!msgSnapshot.exists) return;

      final batch = db.batch();

      batch.update(msgRef, {
        'isRecalled': true,
        'text': 'Tin nhắn đã bị thu hồi',
        'type': 'text',
        'mediaUrl': FieldValue.delete(),
        'audioUrl': FieldValue.delete(),
        'isVideo': FieldValue.delete(),
        'gameId': FieldValue.delete(),
      });

      final matchDoc = await matchRef.get();
      if (matchDoc.exists) {
        final data = matchDoc.data();
        final lastMsgTime = data?['lastMessageTime'] as Timestamp?;
        final msgTime = msgSnapshot.data()?['timestamp'] as Timestamp?;

        // Nếu tin nhắn này là tin nhắn cuối cùng (hoặc cùng timestamp)
        if (lastMsgTime != null && msgTime != null && lastMsgTime.seconds == msgTime.seconds) {
          batch.update(matchRef, {
            'lastMessage': 'Tin nhắn đã bị thu hồi',
            'lastMessageSenderId': userId,
          });
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error recalling message: $e');
    }
  }

  // Xóa hội thoại cho riêng mình (ẩn tin nhắn cũ)
  Future<void> clearChatForMe(String matchId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'clearedAt_$userId': FieldValue.serverTimestamp(),
    });

    final cacheKey = '${matchId}_$userId';
    _clearedAtCache.remove(cacheKey);
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

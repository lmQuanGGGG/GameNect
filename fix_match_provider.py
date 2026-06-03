import sys
import re

with open('lib/core/providers/match_provider.dart', 'r') as f:
    content = f.read()

old_stream_func = """  // Stream danh sách user đã match, kèm thông tin tin nhắn cuối cùng
  Stream<List<Map<String, dynamic>>> matchedUsersStream(String currentUserId) {
    final matchQuery = FirebaseFirestore.instance
        .collection('matches')
        .where('userIds', arrayContains: currentUserId)
        .where('status', isEqualTo: 'confirmed')
        .snapshots();

    return matchQuery.switchMap((matchSnap) {
      if (matchSnap.docs.isEmpty) return Stream.value([]);

      final streams = matchSnap.docs.map((doc) {
        final matchId = doc.id;
        final userIds = List<String>.from(doc['userIds'] ?? []);
        final peerId = userIds.firstWhere((id) => id != currentUserId, orElse: () => '');
        final userFuture = FirestoreService().getUser(peerId);

        // Stream lấy message cuối cùng
        final msgStream = FirebaseFirestore.instance
    .collection('chats')
    .doc(matchId)
    .collection('messages')
    .orderBy('timestamp', descending: true)
    .limit(1)
    .snapshots()
    .asyncMap((msgSnap) async {
      String? lastMessage;
      DateTime? lastMessageTime;
      if (msgSnap.docs.isNotEmpty) {
        final msg = msgSnap.docs.first.data();
        lastMessageTime = (msg['timestamp'] as Timestamp?)?.toDate();
        
        final msgType = msg['type'] ?? 'text';
        final senderId = msg['senderId'];
        final isMe = senderId == currentUserId; // ← Kiểm tra ai gửi
        
        switch (msgType) {
          case 'call':
            if (msg['callStatus'] == 'missed') {
              lastMessage = isMe ? 'Bạn: Cuộc gọi nhỡ' : 'Cuộc gọi nhỡ';
            } else if (msg['callStatus'] == 'declined') {
              lastMessage = isMe ? 'Bạn: Cuộc gọi bị từ chối' : 'Cuộc gọi bị từ chối';
            } else if (msg['callStatus'] == 'cancelled') {
              lastMessage = isMe ? 'Bạn: Đã hủy' : 'Đã hủy';
            } else {
              final duration = msg['duration'] ?? 0;
              lastMessage = isMe 
                ? 'Bạn: Đã gọi ${_formatDuration(duration)}'
                : 'Đã gọi ${_formatDuration(duration)}';
            }
            break;
          case 'voice':
            lastMessage = isMe ? 'Bạn: Đã gửi 1 tin nhắn thoại' : 'Đã gửi 1 tin nhắn thoại';
            break;
          case 'media':
            final isVideo = msg['isVideo'] == true;
            lastMessage = isMe 
              ? (isVideo ? 'Bạn: Đã gửi 1 video' : 'Bạn: Đã gửi 1 ảnh')
              : (isVideo ? 'Đã gửi 1 video' : 'Đã gửi 1 ảnh');
            break;
          case 'game':
            lastMessage = isMe ? 'Bạn: Đã chia sẻ một trò chơi' : 'Đã chia sẻ một trò chơi';
            break;
          default:
            lastMessage = isMe ? 'Bạn: ${msg['text']}' : msg['text'];
        }
      }

      final lastSeenMe = (doc.data()['lastSeen_$currentUserId'] as Timestamp?)?.toDate();
      final lastMessageRead = lastSeenMe != null &&
          lastMessageTime != null &&
          !lastSeenMe.isBefore(lastMessageTime);

      return {
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime,
        'lastMessageRead': lastMessageRead,
        'lastMessageSenderId': msgSnap.docs.isNotEmpty ? msgSnap.docs.first['senderId'] : '',
      };
    });

        return msgStream.asyncMap((msgData) async {
          final user = await userFuture;
          return {
            'matchId': matchId,
            'user': user,
            'matchedAt': (doc['createdAt'] as Timestamp?)?.toDate(),
            ...msgData,
          };
        });
      });

      return rxdart.CombineLatestStream.list(streams).map((list) {
        return list.where((item) => item['user'] != null).toList();
      });
    });
  }"""

new_stream_func = """  // Cache thông tin user để tránh query lại nhiều lần khi stream cập nhật
  final Map<String, UserModel> _userCache = {};

  // Stream danh sách user đã match, kèm thông tin tin nhắn cuối cùng lấy trực tiếp từ match doc
  Stream<List<Map<String, dynamic>>> matchedUsersStream(String currentUserId) {
    final matchQuery = FirebaseFirestore.instance
        .collection('matches')
        .where('userIds', arrayContains: currentUserId)
        .where('status', isEqualTo: 'confirmed')
        .snapshots();

    return matchQuery.asyncMap((matchSnap) async {
      if (matchSnap.docs.isEmpty) return [];

      final futures = matchSnap.docs.map((doc) async {
        final data = doc.data();
        final matchId = doc.id;
        final userIds = List<String>.from(data['userIds'] ?? []);
        final peerId = userIds.firstWhere((id) => id != currentUserId, orElse: () => '');
        
        UserModel? user;
        if (_userCache.containsKey(peerId)) {
          user = _userCache[peerId];
        } else {
          user = await FirestoreService().getUser(peerId);
          if (user != null) {
            _userCache[peerId] = user;
          }
        }

        String? lastMessage = data['lastMessage'] as String?;
        final lastMessageTime = (data['lastMessageTime'] as Timestamp?)?.toDate();
        final lastMessageSenderId = data['lastMessageSenderId'] as String? ?? '';
        final lastSeenMe = (data['lastSeen_$currentUserId'] as Timestamp?)?.toDate();
        
        final lastMessageRead = lastSeenMe != null &&
            lastMessageTime != null &&
            !lastSeenMe.isBefore(lastMessageTime);

        final isMe = lastMessageSenderId == currentUserId;

        // Xử lý tiền tố "Bạn: " cho lastMessage
        if (lastMessage != null && lastMessage.isNotEmpty) {
          if (isMe && !lastMessage.startsWith('Bạn: ')) {
            // Trường hợp call đã format ở service là Đã gọi/Đã hủy, ta thêm Bạn:
            if (lastMessage == 'Đã hủy' || lastMessage.startsWith('Đã gọi') || lastMessage.startsWith('Cuộc gọi')) {
              lastMessage = 'Bạn: $lastMessage';
            } 
            // Voice, Media, Game thường set cứng text, có thể format lại nếu cần
            else {
               lastMessage = 'Bạn: $lastMessage';
            }
          }
        }

        return {
          'matchId': matchId,
          'user': user,
          'matchedAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'lastMessage': lastMessage,
          'lastMessageTime': lastMessageTime,
          'lastMessageRead': lastMessageRead,
          'lastMessageSenderId': lastMessageSenderId,
        };
      });

      final list = await Future.wait(futures);
      return list.where((item) => item['user'] != null).toList();
    });
  }"""

if old_stream_func in content:
    content = content.replace(old_stream_func, new_stream_func)
else:
    print("Could not find the old stream function!")
    sys.exit(1)

with open('lib/core/providers/match_provider.dart', 'w') as f:
    f.write(content)

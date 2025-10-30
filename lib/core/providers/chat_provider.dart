import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

// ChatProvider quản lý trạng thái và logic liên quan đến chat, sử dụng ChangeNotifier để cập nhật UI khi dữ liệu thay đổi.
class ChatProvider with ChangeNotifier {
  // Danh sách các tin nhắn trong cuộc trò chuyện
  List<Map<String, dynamic>> _messages = [];
  // Biến kiểm tra trạng thái đang tải dữ liệu
  bool _isLoading = false;
  // Id của người dùng hiện tại
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  // Kiểm tra trạng thái đối phương có đang nhập tin nhắn không
  bool _isPeerTyping = false;
  // Thông tin người dùng hiện tại
  UserModel? _currentUser;

  // Lưu lại id/timestamp của tin nhắn đã gửi thông báo để tránh gửi lặp lại
  Map<String, String> _lastNotifiedMessageId = {};

  // Getter trả về danh sách tin nhắn
  List<Map<String, dynamic>> get messages => _messages;
  // Getter trả về trạng thái loading
  bool get isLoading => _isLoading;
  // Getter trả về trạng thái đối phương đang nhập
  bool get isPeerTyping => _isPeerTyping;
  // Getter trả về thông tin người dùng hiện tại
  UserModel? get currentUser => _currentUser;

  // Setter cập nhật trạng thái đối phương đang nhập và thông báo cho UI
  set isPeerTyping(bool value) {
    _isPeerTyping = value;
    notifyListeners();
  }

  // Hàm lấy danh sách tin nhắn từ Firestore, cập nhật trạng thái loading và thông báo cho UI
  Future<void> fetchMessages(String matchId) async {
    _isLoading = true;
    notifyListeners();
    _messages = await FirestoreService().getMessages(matchId);
    _isLoading = false;
    notifyListeners();
  }

  // Hàm gửi tin nhắn văn bản, gọi FirestoreService để gửi, sau đó cập nhật lại danh sách tin nhắn
  Future<void> sendMessage(String matchId, String text, {UserModel? peerUser}) async {
    _isLoading = true;
    notifyListeners();
    await FirestoreService().sendMessage(matchId, text);
    await fetchMessages(matchId);
    _isLoading = false;
    notifyListeners();
  }

  // Hàm gửi tin nhắn thoại, gọi FirestoreService để gửi, cập nhật lại tin nhắn, đồng thời gửi thông báo push cho đối phương nếu có
  Future<void> sendVoiceMessage(
    String matchId,
    String audioUrl, {
    int? duration,
    UserModel? peerUser,
  }) async {
    _isLoading = true;
    notifyListeners();
    await FirestoreService().sendVoiceMessage(
      matchId: matchId,
      audioUrl: audioUrl,
      duration: duration,
    );
    await fetchMessages(matchId);
    _isLoading = false;
    notifyListeners();

    // Gửi thông báo push cho đối phương nếu có
    if (peerUser != null) {
      await handleMessageNotification(
        matchId,
        'Đã gửi 1 tin nhắn thoại',
        peerUser,
      );
    }
  }

  // Hàm gửi cảm xúc (emoji) cho một tin nhắn, gọi FirestoreService để xử lý
  Future<void> reactToMessage(String matchId, String messageId, String emoji) async {
  await FirestoreService().reactToMessage(
    matchId: matchId,
    messageId: messageId,
    emoji: emoji,
  );
  notifyListeners();
}

Future<void> sendMediaWithNotify(
  String matchId,
  String mediaUrl, {
  bool isVideo = false,
  String? caption,
  UserModel? peerUser,
}) async {
  await FirestoreService().sendMediaWithNotify(
    matchId: matchId,
    mediaUrl: mediaUrl,
    isVideo: isVideo,
    caption: caption,
    peerUser: peerUser,
  );
  await fetchMessages(matchId);
  notifyListeners();
}

  // Hàm gửi tin nhắn văn bản kèm media (ảnh/video)
  Future<void> sendMessageWithMedia(
    String matchId,
    String text, {
    String? mediaUrl,
    bool isVideo = false,
  }) async {
    await FirestoreService().sendMessageWithMedia(
      matchId: matchId,
      text: text,
      mediaUrl: mediaUrl,
      isVideo: isVideo,
    );
  }

  // Hàm trả về stream danh sách tin nhắn, đồng thời kiểm tra nếu có tin nhắn mới từ đối phương thì gửi thông báo, tránh gửi lặp lại bằng cách kiểm tra id/timestamp
  Stream<List<Map<String, dynamic>>> messagesStream(String matchId, UserModel peerUser) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return FirestoreService().messagesStream(matchId).map((messages) {
      if (messages.isNotEmpty) {
        final lastMsg = messages.last;
        final msgId = lastMsg['id'] ?? lastMsg['timestamp']?.toString();
        // Nếu là tin nhắn mới từ người khác và chưa thông báo
        if (lastMsg['senderId'] != currentUserId &&
            msgId != null &&
            _lastNotifiedMessageId[matchId] != msgId) {
            String notifyText = '';
            if (lastMsg['type'] == 'voice') {
              notifyText = 'Đã gửi 1 tin nhắn thoại';
            } else if (lastMsg['type'] == 'media') {
              notifyText = 'Đã gửi 1 hình ảnh/video';
            } else if (lastMsg['type'] == 'react') {
              notifyText = 'Đã thả cảm xúc';
            } else {
              notifyText = lastMsg['text'] ?? '';
            }
            handleMessageNotification(matchId, notifyText, peerUser);
            _lastNotifiedMessageId[matchId] = msgId;
        }
      }
      return messages;
    });
  }

  // Hàm lắng nghe cuộc gọi đến qua Firestore, nếu có cuộc gọi mới từ đối phương thì hiển thị thông báo cuộc gọi
  void listenForIncomingCalls(String matchId, UserModel peerUser) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    FirebaseFirestore.instance
        .collection('calls')
        .doc(matchId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      
      // Kiểm tra nếu có cuộc gọi mới từ người khác (không phải mình gọi) và chưa được trả lời
      if (data != null &&
          data['callerId'] != currentUserId &&
          data['status'] == 'active' &&
          (data['answered'] != true)) {
        
        // Hiển thị thông báo cuộc gọi
        showCallNotification(
          peerUsername: peerUser.username,
          matchId: matchId,
          peerUserId: peerUser.id,
        );
      }
    });
  }

  // Hàm xác nhận đã nhận cuộc gọi, cập nhật trạng thái cuộc gọi trên Firestore
  Future<void> answerCall(String matchId) async {
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(matchId)
        .set({'answered': true, 'status': 'accepted'}, SetOptions(merge: true));
    notifyListeners();
  }

  // Hàm kết thúc cuộc gọi, ghi lại thông tin cuộc gọi (thời lượng, trạng thái) vào Firestore
  Future<void> endCall(String matchId, int duration, {bool missed = false, bool declined = false}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await FirestoreService().addCallMessage(
      matchId: matchId,
      senderId: userId,
      duration: duration,
      missed: missed,
      declined: declined,
    );
    notifyListeners();
  }

  // Hàm lấy thông tin người dùng hiện tại từ Firestore
  Future<void> fetchCurrentUser() async {
    _currentUser = await FirestoreService().getCurrentUser();
    notifyListeners();
  }

  // Hàm cập nhật trạng thái đang nhập tin nhắn của người dùng hiện tại lên Firestore
  Future<void> setTyping(String matchId, {required bool isTyping}) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .set({'${currentUserId}_typing': isTyping}, SetOptions(merge: true));
  }

  // Hàm trả về stream trạng thái đang nhập tin nhắn của đối phương
  Stream<bool> peerTypingStream(String matchId, String peerUserId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .snapshots()
        .map((doc) => doc.data()?['${peerUserId}_typing'] == true);
  }

  // Hàm gửi thông báo khi nhận tin nhắn mới
  Future<void> handleMessageNotification(String matchId, String text, UserModel peerUser) async {
    await showMessageNotification(
      peerUsername: peerUser.username,
      matchId: matchId,
      peerUserId: peerUser.id,
      message: text,
    );
  }

  // Hàm gửi thông báo khi có cuộc gọi đến
  Future<void> handleCallNotification(String matchId, UserModel peerUser) async {
    await showCallNotification(
      peerUsername: peerUser.username,
      matchId: matchId,
      peerUserId: peerUser.id,
    );
  }
}
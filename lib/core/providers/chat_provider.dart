import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class ChatProvider with ChangeNotifier {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isPeerTyping = false;
  UserModel? _currentUser;

  // Thêm biến này để lưu lại id/timestamp tin nhắn đã thông báo
  Map<String, String> _lastNotifiedMessageId = {};

  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isPeerTyping => _isPeerTyping;
  UserModel? get currentUser => _currentUser;

  set isPeerTyping(bool value) {
    _isPeerTyping = value;
    notifyListeners();
  }

  Future<void> fetchMessages(String matchId) async {
    _isLoading = true;
    notifyListeners();
    _messages = await FirestoreService().getMessages(matchId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessage(String matchId, String text, {UserModel? peerUser}) async {
    _isLoading = true;
    notifyListeners();
    await FirestoreService().sendMessage(matchId, text);
    await fetchMessages(matchId);
    _isLoading = false;
    notifyListeners();

    // XÓA hoặc COMMENT dòng này để không tự gửi thông báo cho chính mình
    // if (peerUser != null) {
    //   await handleMessageNotification(matchId, text, peerUser);
    // }
  }

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
          handleMessageNotification(matchId, lastMsg['text'] ?? '', peerUser);
          _lastNotifiedMessageId[matchId] = msgId;
        }
      }
      return messages;
    });
  }

  // Hàm lắng nghe cuộc gọi đến và hiển thị thông báo
  void listenForIncomingCalls(String matchId, UserModel peerUser) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    FirebaseFirestore.instance
        .collection('calls')
        .doc(matchId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      
      // Kiểm tra nếu có cuộc gọi mới từ người khác (không phải mình gọi)
      // và chưa được trả lời
      if (data != null &&
          data['callerId'] != currentUserId &&
          data['status'] == 'active' &&
          (data['answered'] != true)) {
        
        // HIỂN THỊ THÔNG BÁO CUỘC GỌI
        showCallNotification(
          peerUsername: peerUser.username,
          matchId: matchId,
          peerUserId: peerUser.id,
        );
      }
    });
  }

  // Hàm xác nhận đã nhận cuộc gọi
  Future<void> answerCall(String matchId) async {
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(matchId)
        .set({'answered': true, 'status': 'accepted'}, SetOptions(merge: true));
    notifyListeners();
  }

  // Hàm kết thúc cuộc gọi
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

  // Hàm helper format duration
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes phút $secs giây';
    }
    return '$secs giây';
  }

  Future<void> fetchCurrentUser() async {
    _currentUser = await FirestoreService().getCurrentUser();
    notifyListeners();
  }

  Future<void> setTyping(String matchId, {required bool isTyping}) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .set({'${currentUserId}_typing': isTyping}, SetOptions(merge: true));
  }

  Stream<bool> peerTypingStream(String matchId, String peerUserId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .snapshots()
        .map((doc) => doc.data()?['${peerUserId}_typing'] == true);
  }

  Future<void> handleMessageNotification(String matchId, String text, UserModel peerUser) async {
    // Khi nhận tin nhắn mới
    await showMessageNotification(
      peerUsername: peerUser.username,
      matchId: matchId,
      peerUserId: peerUser.id,
      message: text,
    );
  }

  Future<void> handleCallNotification(String matchId, UserModel peerUser) async {
    // Khi có cuộc gọi đến
    await showCallNotification(
      peerUsername: peerUser.username,
      matchId: matchId,
      peerUserId: peerUser.id,
    );
  }
}
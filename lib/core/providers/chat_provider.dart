import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/game_model.dart';
import '../services/notification_service.dart';
import '../routes/app_router.dart';
import '../../user/screens/call/video_call_screen.dart';

// ChatProvider quản lý trạng thái và logic liên quan đến chat, sử dụng ChangeNotifier để cập nhật UI khi dữ liệu thay đổi.
class ChatProvider with ChangeNotifier {
  // Tracker để biết user đang ở trong màn hình chat nào
  static String? currentActiveMatchId;

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

  // Track các matchId đã nhận snapshot đầu tiên để tránh thông báo tin nhắn cũ
  final Set<String> _firstSnapshotMatchIds = {};

  // Cache các tin nhắn đã được tải sẵn của từng cuộc hội thoại
  final Map<String, List<Map<String, dynamic>>> _preloadedMessages = {};

  // Getter trả về danh sách tin nhắn
  List<Map<String, dynamic>> get messages => _messages;

  // Getter trả về tin nhắn đã tải sẵn
  List<Map<String, dynamic>>? getPreloadedMessages(String matchId) => _preloadedMessages[matchId];
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

  // Hàm tải sẵn 10 tin nhắn mới nhất cho top 10 cuộc hội thoại
  Future<void> preloadTopChatsMessages(List<String> matchIds) async {
    for (final matchId in matchIds) {
      try {
        final msgs = await FirestoreService().getLatestMessages(matchId, limit: 10);
        _preloadedMessages[matchId] = msgs;
      } catch (e) {
        debugPrint('Error preloading messages for match $matchId: $e');
      }
    }
    notifyListeners();
  }

  // Hàm gửi tin nhắn văn bản, gọi FirestoreService để gửi, sau đó cập nhật lại danh sách tin nhắn
  Future<void> sendMessage(String matchId, String text, {UserModel? peerUser, Map<String, dynamic>? repliedMessage}) async {
    _isLoading = true;
    notifyListeners();
    await FirestoreService().sendMessage(matchId, text, repliedMessage: repliedMessage);
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
  Map<String, dynamic>? repliedMessage,
}) async {
  await FirestoreService().sendMediaWithNotify(
    matchId: matchId,
    mediaUrl: mediaUrl,
    isVideo: isVideo,
    caption: caption,
    peerUser: peerUser,
    repliedMessage: repliedMessage,
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
    Map<String, dynamic>? repliedMessage,
  }) async {
    await FirestoreService().sendMessageWithMedia(
      matchId: matchId,
      text: text,
      mediaUrl: mediaUrl,
      isVideo: isVideo,
      repliedMessage: repliedMessage,
    );
  }

  // Hàm chuyển tiếp tin nhắn
  Future<void> forwardMessage(List<String> matchIds, Map<String, dynamic> originalMsg) async {
    _isLoading = true;
    notifyListeners();
    await FirestoreService().forwardMessage(matchIds, originalMsg);
    _isLoading = false;
    notifyListeners();
  }

  // Hàm chia sẻ Game
  Future<void> sendGameMessage(
    String matchId,
    GameModel game, {
    UserModel? peerUser,
  }) async {
    _isLoading = true;
    notifyListeners();
    await FirestoreService().sendGameMessage(
      matchId: matchId,
      game: game,
      peerUser: peerUser,
    );
    await fetchMessages(matchId);
    _isLoading = false;
    notifyListeners();

  }

  // Hàm thu hồi tin nhắn
  Future<void> recallMessage(String matchId, String messageId) async {
    await FirestoreService().recallMessage(matchId, messageId);
    notifyListeners();
  }

  // Hàm trả về stream danh sách tin nhắn, đồng thời kiểm tra nếu có tin nhắn mới từ đối phương thì gửi thông báo, tránh gửi lặp lại bằng cách kiểm tra id/timestamp
  Stream<List<Map<String, dynamic>>> messagesStream(String matchId, UserModel peerUser) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return FirestoreService().messagesStream(matchId).map((messages) {
      _preloadedMessages[matchId] = messages;
      if (messages.isNotEmpty) {
        final lastMsg = messages.last;
        final msgId = lastMsg['id'] ?? lastMsg['timestamp']?.toString();

        // Snapshot đầu tiên cho matchId này: chỉ ghi nhận ID, KHÔNG gửi thông báo
        // Tránh thông báo lại tin nhắn cũ sau khi đăng nhập/mở lại app
        if (!_firstSnapshotMatchIds.contains(matchId)) {
          _firstSnapshotMatchIds.add(matchId);
          if (msgId != null) {
            _lastNotifiedMessageId[matchId] = msgId;
          }
          return messages;
        }

        // Nếu là tin nhắn mới từ người khác và chưa thông báo
        if (lastMsg['senderId'] != currentUserId &&
            msgId != null &&
            _lastNotifiedMessageId[matchId] != msgId) {
            
            // Đánh dấu đã đọc ngay lập tức vì user đang ở trong màn hình chat
            markMatchAsRead(matchId);
            
            String notifyText = '';
            if (lastMsg['type'] == 'voice') {
              notifyText = 'Đã gửi 1 tin nhắn thoại';
            } else if (lastMsg['type'] == 'media') {
              notifyText = 'Đã gửi 1 hình ảnh/video';
            } else if (lastMsg['type'] == 'react') {
              notifyText = 'Đã thả cảm xúc';
            } else if (lastMsg['type'] == 'game') {
              notifyText = 'Đã chia sẻ một trò chơi';
            } else {
              notifyText = lastMsg['text'] ?? '';
            }
            // handleMessageNotification(matchId, notifyText, peerUser); // Đã bị xóa để tránh lặp thông báo
            _lastNotifiedMessageId[matchId] = msgId;
        }
      }
      return messages;
    });
  }

  final Map<String, StreamSubscription<DocumentSnapshot>> _callSubscriptions = {};
  final Map<String, BuildContext> _incomingCallDialogCtxs = {};

  // Dọn dẹp tất cả subscriptions để tránh rò rỉ khi đăng xuất/đăng nhập lại
  void clearAllSubscriptions() {
    for (var sub in _callSubscriptions.values) {
      sub.cancel();
    }
    _callSubscriptions.clear();
    _incomingCallDialogCtxs.clear();
    _lastNotifiedMessageId.clear();
    _firstSnapshotMatchIds.clear(); // Reset trạng thái snapshot đầu tiên
    _preloadedMessages.clear(); // Dọn dẹp cache tin nhắn tải sẵn
  }

  // Hàm lắng nghe cuộc gọi đến qua Firestore, nếu có cuộc gọi mới từ đối phương thì hiển thị thông báo cuộc gọi
  void listenForIncomingCalls(String matchId, UserModel peerUser) {
    _callSubscriptions[matchId]?.cancel();

    final sub = FirebaseFirestore.instance
        .collection('calls')
        .doc(matchId)
        .snapshots()
        .listen((doc) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final data = doc.data();
      
      // Kiểm tra nếu có cuộc gọi mới từ người khác (không phải mình gọi) và chưa được trả lời
      if (data != null &&
          data['callerId'] != currentUserId &&
          data['status'] == 'active' &&
          (data['answered'] != true) &&
          !VideoCallScreen.isCallActive) {
        
        // Bỏ qua các cuộc gọi cũ (quá 60 giây) để tránh spam thông báo khi mở lại app
        final startedAtData = data['startedAt'];
        DateTime? startedAt;
        if (startedAtData is Timestamp) {
          startedAt = startedAtData.toDate();
        } else if (startedAtData is String) {
          startedAt = DateTime.tryParse(startedAtData);
        }

        if (startedAt != null) {
          if (DateTime.now().difference(startedAt).inSeconds > 60) {
             // Tự động dọn dẹp data cũ luôn để khỏi bị lặp lại
             FirebaseFirestore.instance
                .collection('calls')
                .doc(matchId)
                .set({'status': 'missed'}, SetOptions(merge: true));
             return;
          }
        } else {
          // Bỏ qua nếu cuộc gọi cũ không có timestamp hợp lệ
          return;
        }

        // Hiển thị thông báo cuộc gọi (OS Level) nếu app đang ở background
        if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
          showCallNotification(
            peerUsername: peerUser.username,
            matchId: matchId,
            peerUserId: peerUser.id,
          );
        }

        // Hiển thị dialog trong app nếu app đang ở foreground
        if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
          final context = navigatorKey.currentContext;
          if (context != null && !_incomingCallDialogCtxs.containsKey(matchId)) {
            // Đánh dấu tạm để tránh show nhiều lần (trước khi builder chạy)
            _incomingCallDialogCtxs[matchId] = context; 

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) {
                _incomingCallDialogCtxs[matchId] = ctx;
                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMini = constraints.maxWidth < 250 || MediaQuery.of(context).size.height < 400;
                      
                      if (isMini) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2A29), // Màu nền dark brown như ảnh
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '📞 Gọi: ${peerUser.username}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (_incomingCallDialogCtxs.containsKey(matchId)) {
                                         _incomingCallDialogCtxs.remove(matchId);
                                         Navigator.pop(ctx);
                                       }
                                       FirebaseFirestore.instance
                                           .collection('calls')
                                           .doc(matchId)
                                           .set({'answered': true, 'status': 'accepted'}, SetOptions(merge: true));
                                      navigatorKey.currentState?.push(
                                        MaterialPageRoute(
                                          builder: (_) => VideoCallScreen(
                                            channelName: matchId,
                                            peerUserId: peerUser.id,
                                            peerUsername: peerUser.username,
                                            peerAvatarUrl: peerUser.avatarUrl,
                                            isVoiceCall: data['type'] == 'voice',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                                      child: const Icon(Icons.call, color: Colors.white, size: 14),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (_incomingCallDialogCtxs.containsKey(matchId)) {
                                         _incomingCallDialogCtxs.remove(matchId);
                                         Navigator.pop(ctx);
                                      }
                                      FirebaseFirestore.instance
                                          .collection('calls')
                                          .doc(matchId)
                                          .set({'status': 'declined'}, SetOptions(merge: true));
                                      endCall(matchId, 0, declined: true);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(color: Color(0xFFF44336), shape: BoxShape.circle),
                                      child: const Icon(Icons.call_end, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      // Full Layout
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2A29), // Màu nền dark brown
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white12,
                              backgroundImage: peerUser.avatarUrl != null ? NetworkImage(peerUser.avatarUrl!) : null,
                              child: peerUser.avatarUrl == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Cuộc gọi đến từ',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              peerUser.username,
                              style: const TextStyle(
                                color: Color(0xFFFF6E40),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () {
                                      if (_incomingCallDialogCtxs.containsKey(matchId)) {
                                         _incomingCallDialogCtxs.remove(matchId);
                                         Navigator.pop(ctx);
                                       }
                                       FirebaseFirestore.instance
                                           .collection('calls')
                                           .doc(matchId)
                                           .set({'answered': true, 'status': 'accepted'}, SetOptions(merge: true));
                                      navigatorKey.currentState?.push(
                                        MaterialPageRoute(
                                          builder: (_) => VideoCallScreen(
                                            channelName: matchId,
                                            peerUserId: peerUser.id,
                                            peerUsername: peerUser.username,
                                            peerAvatarUrl: peerUser.avatarUrl,
                                            isVoiceCall: data['type'] == 'voice',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.call, size: 20),
                                    label: const Text('Nghe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF44336),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () {
                                      if (_incomingCallDialogCtxs.containsKey(matchId)) {
                                         _incomingCallDialogCtxs.remove(matchId);
                                         Navigator.pop(ctx);
                                      }
                                      FirebaseFirestore.instance
                                          .collection('calls')
                                          .doc(matchId)
                                          .set({'status': 'declined'}, SetOptions(merge: true));
                                      endCall(matchId, 0, declined: true);
                                    },
                                    icon: const Icon(Icons.call_end, size: 20),
                                    label: const Text('Từ chối', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ).then((_) {
              _incomingCallDialogCtxs.remove(matchId);
            });
          }
        }
      } else if (data != null && data['status'] != 'active') {
        // Nếu cuộc gọi kết thúc/hủy, tự động đóng dialog nếu đang mở
        if (_incomingCallDialogCtxs.containsKey(matchId)) {
          final ctx = _incomingCallDialogCtxs[matchId];
          if (ctx != null && ctx.mounted) {
            Navigator.pop(ctx);
          }
          _incomingCallDialogCtxs.remove(matchId);
        }
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

  // Đánh dấu tin nhắn đã đọc
  Future<void> markMatchAsRead(String matchId) async {
    await FirestoreService().markMatchAsRead(matchId);
    notifyListeners();
  }
}
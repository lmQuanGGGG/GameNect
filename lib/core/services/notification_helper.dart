import '../controllers/notification_controller.dart';

// Helper class chứa các hàm tiện ích để hiển thị notification
// Đóng vai trò là lớp trung gian giữa UI và NotificationController

// Hiển thị thông báo tin nhắn mới trong chat
// Được gọi khi nhận tin nhắn từ người dùng khác
Future<void> showMessageNotification({
  required String peerUsername,
  required String matchId,
  required String peerUserId,
  required String message,
}) async {
  await NotificationController.showChatNotification(
    peerUsername: peerUsername,
    matchId: matchId,
    peerUserId: peerUserId,
    message: message,
  );
}

// Hiển thị thông báo cuộc gọi đến
// Được gọi khi có người gọi video call hoặc voice call
Future<void> showCallNotification({
  required String peerUsername,
  required String matchId,
  required String peerUserId,
}) async {
  await NotificationController.showCallNotification(
    peerUsername: peerUsername,
    matchId: matchId,
    peerUserId: peerUserId,
  );
}

// Hiển thị thông báo khi có người react vào moment
// Được gọi khi người dùng khác thả emoji vào moment của mình
Future<void> showMomentReactionNotification({
  required String momentOwnerId,
  required String reactorUsername,
  required String reactorUserId,
  required String momentId,
  required String emoji,
}) async {
  await NotificationController.showMomentNotification(
    reactorUsername: reactorUsername,
    momentId: momentId,
    reactorUserId: reactorUserId,
    emoji: emoji,
  );
}
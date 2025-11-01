import '../controllers/notification_controller.dart';

// Hiển thị thông báo tin nhắn
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

// Hiển thị thông báo cuộc gọi
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

// Hiển thị thông báo moment reaction
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
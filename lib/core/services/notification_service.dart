import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

// Hiển thị thông báo tin nhắn mới
// Sử dụng NotificationLayout.Messaging để hiển thị dạng tin nhắn
Future<void> showMessageNotification({
  required String peerUsername,
  required String matchId,
  required String peerUserId,
  required String message,
}) async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      // Tạo ID duy nhất dựa trên timestamp để tránh trùng lặp
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      channelKey: 'gamenect_channel',
      title: peerUsername,
      body: message,
      // Payload chứa dữ liệu để xử lý khi user tap vào notification
      payload: {
        'type': 'chat',
        'matchId': matchId,
        'peerUserId': peerUserId,
      },
      notificationLayout: NotificationLayout.Messaging,
      category: NotificationCategory.Message,
      // Đánh thức màn hình khi có notification
      wakeUpScreen: true,
    ),
  );
  
  developer.log('Message notification sent: $peerUsername', name: 'Notification');
}

// Hiển thị thông báo cuộc gọi đến với action buttons
// User có thể Accept hoặc Decline trực tiếp từ notification
Future<void> showCallNotification({
  required String peerUsername,
  required String matchId,
  required String peerUserId,
}) async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      // Dùng hashCode của matchId làm ID để cập nhật notification nếu cần
      id: matchId.hashCode,
      channelKey: 'call_channel',
      title: '📞 Cuộc gọi đến',
      body: '$peerUsername đang gọi cho bạn',
      payload: {
        'type': 'call',
        'matchId': matchId,
        'peerUserId': peerUserId,
      },
      notificationLayout: NotificationLayout.Default,
      category: NotificationCategory.Call,
      wakeUpScreen: true,
      // Hiển thị fullscreen để thu hút sự chú ý
      fullScreenIntent: true,
      // Critical alert để vượt qua chế độ im lặng
      criticalAlert: true,
      // Khóa notification để không bị vuốt tắt vô tình
      locked: true,
    ),
    // Thêm hai nút Accept và Decline
    actionButtons: [
      NotificationActionButton(
        key: 'accept',
        label: 'Nghe',
        color: Colors.green,
        autoDismissible: true,
      ),
      NotificationActionButton(
        key: 'decline',
        label: 'Từ chối',
        color: Colors.red,
        autoDismissible: true,
      ),
    ],
  );
  
  developer.log('Call notification sent: $peerUsername', name: 'Notification');
}

// Hiển thị thông báo khi có người react vào moment
// Dùng để thông báo tương tác xã hội trên moment
Future<void> showMomentReactionNotification({
  required String momentOwnerId,
  required String reactorUsername,
  required String reactorUserId,
  required String momentId,
  required String emoji,
}) async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: momentId.hashCode,
      channelKey: 'moment_channel',
      title: '$reactorUsername đã thả cảm xúc $emoji',
      body: 'Vào moment của bạn',
      payload: {
        'type': 'moment_reaction',
        'momentId': momentId,
        'reactorUserId': reactorUserId,
      },
      notificationLayout: NotificationLayout.Default,
      category: NotificationCategory.Social,
    ),
  );
  
  developer.log('Moment reaction notification sent', name: 'Notification');
}

// Hủy một notification cụ thể theo ID
Future<void> cancelNotification(int id) async {
  await AwesomeNotifications().cancel(id);
}

// Hủy tất cả notifications đang hiển thị
Future<void> cancelAllNotifications() async {
  await AwesomeNotifications().cancelAll();
}
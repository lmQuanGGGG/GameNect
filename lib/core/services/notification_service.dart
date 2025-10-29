import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

// Hiển thị thông báo tin nhắn
Future<void> showMessageNotification({
  required String peerUsername,
  required String matchId,
  required String peerUserId,
  required String message,
}) async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      channelKey: 'gamenect_channel',
      title: peerUsername,
      body: message,
      payload: {
        'type': 'chat',
        'matchId': matchId,
        'peerUserId': peerUserId,
      },
      notificationLayout: NotificationLayout.Messaging,
      category: NotificationCategory.Message,
      wakeUpScreen: true,
    ),
  );
  
  developer.log('Message notification sent: $peerUsername', name: 'Notification');
}

// Hiển thị thông báo cuộc gọi (có nút Accept/Decline)
Future<void> showCallNotification({
  required String peerUsername,
  required String matchId,
  required String peerUserId,
}) async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
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
      fullScreenIntent: true,
      criticalAlert: true,
      locked: true,
    ),
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

// Hiển thị thông báo moment reaction
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

// Hủy notification
Future<void> cancelNotification(int id) async {
  await AwesomeNotifications().cancel(id);
}

// Hủy tất cả notifications
Future<void> cancelAllNotifications() async {
  await AwesomeNotifications().cancelAll();
}
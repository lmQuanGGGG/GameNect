import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../main.dart';
import 'dart:convert'; 


// Hàm chung để hiển thị thông báo trên cả iOS và Android
Future<void> showNotification({
  required String title,
  required String body,
  String? payload,
  List<AndroidNotificationAction>? actions,
  AndroidNotificationCategory? androidCategory,
  String? categoryId,
}) async {
  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'gamenect_channel',
        'Gamenect Notifications',
        channelDescription: 'Thông báo Gamenect',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        actions: actions ?? [],
        fullScreenIntent: androidCategory == AndroidNotificationCategory.call,
        category: androidCategory,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true, // BẮT BUỘC để hiện banner
        presentSound: true, // BẮT BUỘC để có âm thanh
        presentBadge: true, // BẮT BUỘC để hiện badge
        categoryIdentifier: categoryId,
        interruptionLevel: InterruptionLevel.timeSensitive, 
      ),
    ),
    payload: payload,
  );
}

Future<void> showMomentReactionNotification({
  required String momentOwnerId,
  required String reactorUsername,
  required String reactorUserId,
  required String momentId,
  required String emoji,
}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'moment_reactions_channel',
    'Cảm xúc Moment',
    channelDescription: 'Thông báo khi có người thả cảm xúc vào moment',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    playSound: true,
    enableVibration: true,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    momentId.hashCode, // Unique ID dựa trên momentId
    '$reactorUsername đã thả cảm xúc $emoji',
    'Vào moment của bạn',
    notificationDetails,
    payload: json.encode({
      'type': 'moment_reaction',
      'momentId': momentId,
      'reactorUserId': reactorUserId,
    }),
  );
}

// Hiển thị thông báo tin nhắn mới
Future<void> showMessageNotification({
  required String peerUsername,
  required String matchId,
  required String peerUserId,
  required String message,
}) async {
  await showNotification(
    title: 'Tin nhắn mới từ $peerUsername',
    body: message,
    payload: 'chat:$matchId:$peerUserId', // Payload để xử lý khi bấm vào thông báo
  );
}

// Hiển thị thông báo cuộc gọi đến với các nút action
Future<void> showCallNotification({
  required String peerUsername,
  required String matchId,
  required String peerUserId,
}) async {
  await showNotification(
    title: 'Cuộc gọi đến từ $peerUsername',
    body: 'Bạn có muốn nghe không?',
    payload: 'call:$matchId:$peerUserId',
    actions: [
      AndroidNotificationAction('accept', 'Nghe'),
      AndroidNotificationAction('decline', 'Từ chối'),
    ],
    androidCategory: AndroidNotificationCategory.call,
    categoryId: 'CALL_CATEGORY', // Phải khớp với category đã đăng ký trong main.dart
  );
}
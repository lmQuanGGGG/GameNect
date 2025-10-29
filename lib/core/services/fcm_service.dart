import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'dart:async';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Khởi tạo FCM và lấy token
  Future<void> initialize() async {
    try {
      // Khởi tạo Awesome Notifications FCM
      await AwesomeNotificationsFcm().initialize(
        onFcmTokenHandle: _onFcmTokenReceived,
        onNativeTokenHandle: _onNativeTokenReceived,
        onFcmSilentDataHandle: _onFcmSilentDataReceived,
        
        debug: true, // Bật debug mode
      );

      // Xin quyền notification
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      // Lấy FCM token
      _fcmToken = await AwesomeNotificationsFcm().requestFirebaseAppToken();
      developer.log('FCM Token: $_fcmToken', name: 'FCM');

      // Lưu token vào Firestore
      await _saveTokenToFirestore(_fcmToken);

      // Đăng ký nhận thông báo từ FCM
      await _subscribeToPushNotifications();

    } catch (e) {
      developer.log('Error initializing FCM: $e', name: 'FCM');
    }
  }

  /// Callback khi nhận FCM token mới
  @pragma('vm:entry-point')
  static Future<void> _onFcmTokenReceived(String token) async {
    developer.log('FCM Token received: $token', name: 'FCM');
    
    // Lưu token vào Firestore
    await _saveTokenToFirestore(token);
  }

  /// Callback khi nhận native token (APNS cho iOS)
  @pragma('vm:entry-point')
  static Future<void> _onNativeTokenReceived(String token) async {
    developer.log('Native Token received: $token', name: 'FCM');
  }

  /// Callback khi nhận silent notification từ FCM
  @pragma('vm:entry-point')
  static Future<void> _onFcmSilentDataReceived(FcmSilentData silentData) async {
    developer.log('Silent notification received: ${silentData.data}', name: 'FCM');
    
    try {
      final data = silentData.data ?? {};
      final type = data['type'] as String?;

      // Xử lý theo loại notification
      switch (type) {
        case 'chat':
          await _handleChatNotification(data);
          break;
        case 'call':
          await _handleCallNotification(data);
          break;
        case 'moment_reaction':
          await _handleMomentNotification(data);
          break;
        case 'match':
          await _handleMatchNotification(data);
          break;
        default:
          developer.log('Unknown notification type: $type', name: 'FCM');
      }
    } catch (e) {
      developer.log('Error handling silent notification: $e', name: 'FCM');
    }
  }

  /// Lưu FCM token vào Firestore
  static Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': 'android', // Hoặc 'ios'
      }, SetOptions(merge: true));

      developer.log('FCM token saved to Firestore', name: 'FCM');
    } catch (e) {
      developer.log('Error saving FCM token: $e', name: 'FCM');
    }
  }

  /// Đăng ký nhận push notifications
  Future<void> _subscribeToPushNotifications() async {
    try {
      // Subscribe to topics nếu cần
      await AwesomeNotificationsFcm().subscribeToTopic('all_users');
      
      developer.log('Subscribed to push notifications', name: 'FCM');
    } catch (e) {
      developer.log('Error subscribing to push: $e', name: 'FCM');
    }
  }

  /// Xử lý notification tin nhắn
  static Future<void> _handleChatNotification(Map<String, dynamic> data) async {
    final matchId = data['matchId'] as String?;
    final peerUserId = data['peerUserId'] as String?;
    final peerUsername = data['peerUsername'] as String?;
    final message = data['message'] as String?;

    if (matchId == null || peerUserId == null || peerUsername == null) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'gamenect_channel',
        title: peerUsername,
        body: message ?? 'Tin nhắn mới',
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

    developer.log('Chat notification displayed', name: 'FCM');
  }

  /// Xử lý notification cuộc gọi
  static Future<void> _handleCallNotification(Map<String, dynamic> data) async {
    final matchId = data['matchId'] as String?;
    final peerUserId = data['peerUserId'] as String?;
    final peerUsername = data['peerUsername'] as String?;

    if (matchId == null || peerUserId == null || peerUsername == null) return;

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
          color: const Color(0xFF4CAF50),
          autoDismissible: true,
        ),
        NotificationActionButton(
          key: 'decline',
          label: 'Từ chối',
          color: const Color(0xFFF44336),
          autoDismissible: true,
        ),
      ],
    );

    developer.log('Call notification displayed', name: 'FCM');
  }

  /// Xử lý notification moment
  static Future<void> _handleMomentNotification(Map<String, dynamic> data) async {
    final momentId = data['momentId'] as String?;
    final reactorUserId = data['reactorUserId'] as String?;
    final reactorUsername = data['reactorUsername'] as String?;
    final emoji = data['emoji'] as String?;

    if (momentId == null || reactorUsername == null) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: momentId.hashCode,
        channelKey: 'moment_channel',
        title: '$reactorUsername đã thả cảm xúc ${emoji ?? '❤️'}',
        body: 'Vào moment của bạn',
        payload: {
          'type': 'moment_reaction',
          'momentId': momentId,
          'reactorUserId': reactorUserId ?? '',
        },
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Social,
      ),
    );

    developer.log('Moment notification displayed', name: 'FCM');
  }

  /// Xử lý notification match mới
  static Future<void> _handleMatchNotification(Map<String, dynamic> data) async {
    final matchId = data['matchId'] as String?;
    final peerUsername = data['peerUsername'] as String?;

    if (matchId == null || peerUsername == null) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: matchId.hashCode,
        channelKey: 'gamenect_channel',
        title: '🎮 Match mới!',
        body: 'Bạn và $peerUsername đã match với nhau',
        payload: {
          'type': 'match',
          'matchId': matchId,
        },
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Social,
      ),
    );

    developer.log('Match notification displayed', name: 'FCM');
  }

  /// Gửi thông báo push đến một user (gọi từ Cloud Functions)
  /// Đây chỉ là helper method để test, production nên dùng Cloud Functions
  Future<void> sendPushNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // Lấy FCM token của user đích
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();

      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) {
        developer.log('User $targetUserId has no FCM token', name: 'FCM');
        return;
      }

      // Lưu notification vào Firestore để Cloud Function xử lý
      await FirebaseFirestore.instance.collection('notifications').add({
        'targetUserId': targetUserId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      developer.log('Notification queued for user $targetUserId', name: 'FCM');
    } catch (e) {
      developer.log('Error sending push notification: $e', name: 'FCM');
    }
  }

  /// Hủy đăng ký FCM khi logout
  Future<void> cleanup() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmToken': FieldValue.delete(),
        });
      }

      // Unsubscribe từ topics
      //await AwesomeNotificationsFcm().unsubscribeFromTopic('all_users');
      
      developer.log('FCM cleanup completed', name: 'FCM');
    } catch (e) {
      developer.log('Error cleaning up FCM: $e', name: 'FCM');
    }
  }
}
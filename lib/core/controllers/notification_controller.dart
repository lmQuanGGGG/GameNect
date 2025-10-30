import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'dart:math';

// Lớp NotificationController quản lý toàn bộ logic thông báo của ứng dụng.
// Bao gồm khởi tạo kênh thông báo, lấy và lưu FCM token, xử lý nhận thông báo từ FCM, tạo thông báo local.

class NotificationController {
  // Singleton để đảm bảo chỉ có một instance NotificationController trong toàn bộ app.
  static final NotificationController _instance = NotificationController._internal();
  factory NotificationController() => _instance;
  NotificationController._internal();

  // Biến lưu FCM token hiện tại của user.
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Hàm khởi tạo các kênh thông báo local (Awesome Notifications).
  // Mỗi kênh dùng cho một loại thông báo: tin nhắn, cuộc gọi, moment, thông báo cơ bản.
  static Future<void> initializeLocalNotifications({required bool debug}) async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'gamenect_channel',
          channelName: 'Gamenect Messages',
          channelDescription: 'Thông báo tin nhắn',
          defaultColor: Color(0xFFFF453A),
          ledColor: Colors.white,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'call_channel',
          channelName: 'Gamenect Calls',
          channelDescription: 'Thông báo cuộc gọi',
          defaultColor: Colors.green,
          ledColor: Colors.green,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          criticalAlerts: true,
        ),
        NotificationChannel(
          channelKey: 'moment_channel',
          channelName: 'Gamenect Moments',
          channelDescription: 'Thông báo moments',
          defaultColor: Color(0xFFFF453A),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelKey: 'basic_channel',
          channelName: 'Basic notifications',
          channelDescription: 'Thông báo cơ bản',
          defaultColor: Colors.blue,
          ledColor: Colors.white,
          importance: NotificationImportance.Default,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
      ],
      debug: debug,
    );
  }

  // Hàm khởi tạo nhận thông báo từ FCM (Firebase Cloud Messaging).
  // Đăng ký các callback xử lý khi nhận silent data, nhận token mới, nhận native token.
  static Future<void> initializeRemoteNotifications({required bool debug}) async {
    await Firebase.initializeApp();
    await AwesomeNotificationsFcm().initialize(
      onFcmSilentDataHandle: mySilentDataHandle,
      onFcmTokenHandle: myFcmTokenHandle,
      onNativeTokenHandle: myNativeTokenHandle,
      debug: debug,
    );
  }

  // Hàm yêu cầu quyền gửi thông báo cho app.
  // Nếu chưa được cấp quyền, sẽ hiện popup xin quyền từ hệ điều hành.
  static Future<void> requestPermissions() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  // Hàm lấy FCM token của thiết bị hiện tại.
  // Token này dùng để gửi thông báo từ server về đúng thiết bị.
  // Sau khi lấy được token, sẽ lưu vào Firestore để backend sử dụng.
  Future<String?> getFirebaseToken() async {
    if (await AwesomeNotificationsFcm().isFirebaseAvailable) {
      try {
        _fcmToken = await AwesomeNotificationsFcm().requestFirebaseAppToken();
        developer.log('FCM Token: $_fcmToken', name: 'FCM');
        
        // Lưu token vào Firestore để backend có thể gửi thông báo đến user này.
        if (_fcmToken != null) {
          await _saveTokenToFirestore(_fcmToken!);
        }
        
        return _fcmToken;
      } catch (e) {
        developer.log('Error getting FCM token: $e', name: 'FCM');
        return null;
      }
    } else {
      developer.log('Firebase not available', name: 'FCM');
      return null;
    }
  }

  // Hàm đăng ký nhận thông báo theo topic (chủ đề).
  // Dùng cho các thông báo broadcast đến nhiều user cùng lúc.
  Future<void> subscribeToTopic(String topic) async {
    await AwesomeNotificationsFcm().subscribeToTopic(topic);
    developer.log('Subscribed to topic: $topic', name: 'FCM');
  }

  // Hàm hủy đăng ký nhận thông báo theo topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    await AwesomeNotificationsFcm().unsubscribeToTopic(topic);
    developer.log('Unsubscribed from topic: $topic', name: 'FCM');
  }

  // Hàm xóa FCM token khi user logout.
  // Xóa token khỏi Firestore để đảm bảo không gửi thông báo nhầm cho user cũ.
  Future<void> clearToken() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': FieldValue.delete()});
    }
    _fcmToken = null;
    developer.log('Token cleared', name: 'FCM');
  }

  // Hàm xử lý dữ liệu silent push từ FCM khi app chạy nền hoặc bị kill.
  // Tạo notification trực tiếp dựa trên loại thông báo nhận được (chat, call, moment).
  @pragma("vm:entry-point")
  static Future<void> mySilentDataHandle(FcmSilentData silentData) async {
    developer.log('Silent Data received: ${silentData.data}', name: 'FCM');
    
    if (silentData.createdLifeCycle != NotificationLifeCycle.Foreground) {
      developer.log('Background silent data', name: 'FCM');
    } else {
      developer.log('Foreground silent data', name: 'FCM');
    }

    // Lấy dữ liệu từ silentData để xác định loại thông báo.
    final data = silentData.data ?? {};
    final type = data['type'];

    try {
      if (type == 'chat') {
        // Tạo notification tin nhắn mới.
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            channelKey: 'gamenect_channel',
            title: data['peerUsername'] ?? 'User',
            body: data['message'] ?? 'New message',
            payload: {
              'type': 'chat',
              'matchId': data['matchId'] ?? '',
              'peerUserId': data['peerUserId'] ?? '',
            },
            notificationLayout: NotificationLayout.Messaging,
            category: NotificationCategory.Message,
            wakeUpScreen: true,
          ),
        );
      } else if (type == 'call') {
        // Tạo notification cuộc gọi đến với hai nút nghe và từ chối.
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: (data['matchId'] ?? '').hashCode,
            channelKey: 'call_channel',
            title: 'Cuộc gọi đến',
            body: '${data['peerUsername'] ?? 'User'} đang gọi cho bạn',
            payload: {
              'type': 'call',
              'matchId': data['matchId'] ?? '',
              'peerUserId': data['peerUserId'] ?? '',
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
      } else if (type == 'moment_reaction') {
        // Tạo notification khi có người thả cảm xúc vào moment của user.
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: (data['momentId'] ?? '').hashCode,
            channelKey: 'moment_channel',
            title: '${data['reactorUsername'] ?? 'Someone'} đã thả cảm xúc ${data['emoji'] ?? '❤️'}',
            body: 'Vào moment của bạn',
            payload: {
              'type': 'moment_reaction',
              'momentId': data['momentId'] ?? '',
              'reactorUserId': data['reactorUserId'] ?? '',
            },
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Social,
          ),
        );
      }
    } catch (e) {
      developer.log('Error creating notification: $e', name: 'FCM');
    }
  }

  // Hàm xử lý khi nhận FCM Token mới từ Firebase.
  // Lưu token vào Firestore để backend sử dụng gửi thông báo.
  @pragma("vm:entry-point")
  static Future<void> myFcmTokenHandle(String token) async {
    developer.log('FCM Token Handle: $token', name: 'FCM');
    await _saveTokenToFirestore(token);
  }

  // Hàm xử lý khi nhận Native Token (APNS cho iOS).
  @pragma("vm:entry-point")
  static Future<void> myNativeTokenHandle(String token) async {
    developer.log('Native Token: $token', name: 'FCM');
  }

  // Hàm lưu FCM token vào Firestore cho user hiện tại.
  // Token này dùng để backend gửi thông báo đến đúng user.
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        developer.log('No user logged in, skip saving token', name: 'FCM');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      developer.log('Token saved to Firestore', name: 'FCM');
    } catch (e) {
      developer.log('Error saving token: $e', name: 'FCM');
    }
  }

  // Hàm hiển thị notification tin nhắn chat.
  // Dùng khi muốn tạo thông báo local cho tin nhắn mới.
  static Future<void> showChatNotification({
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
  }

  // Hàm hiển thị notification cuộc gọi đến.
  // Tạo thông báo với hai nút nghe và từ chối, có thể hiện popup toàn màn hình.
  static Future<void> showCallNotification({
    required String peerUsername,
    required String matchId,
    required String peerUserId,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: matchId.hashCode,
        channelKey: 'call_channel',
        title: 'Cuộc gọi đến',
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
  }

  // Hàm hiển thị notification khi có người thả cảm xúc vào moment của user.
  static Future<void> showMomentNotification({
    required String reactorUsername,
    required String momentId,
    required String reactorUserId,
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
  }

  // Hàm tạo notification cơ bản, dùng cho các trường hợp thông báo khác.
  static Future<void> createNewNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: Random().nextInt(100000),  // Tạo id ngẫu nhiên cho notification
        channelKey: 'basic_channel',
        title: title,
        body: body,
        payload: payload,
        wakeUpScreen: true,  // Bật sáng màn hình khi nhận thông báo
        fullScreenIntent: true,  // Hiện popup toàn màn hình nếu cần
        showWhen: true,
        displayOnForeground: true,
        displayOnBackground: true,
      ),
    );
  }
}
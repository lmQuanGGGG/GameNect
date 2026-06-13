import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/notification_service.dart';
import '../providers/chat_provider.dart';
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
    if (kIsWeb) return;
    await AwesomeNotifications().initialize(
      defaultTargetPlatform == TargetPlatform.android
          ? 'resource://mipmap/launcher_icon'
          : null,
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
        NotificationChannel(
          channelKey: 'mentor_live_channel',
          channelName: 'Mentor Live',
          channelDescription: 'Thông báo khi Mentor bắt đầu livestream',
          defaultColor: Color(0xFFFF3B30),
          ledColor: Color(0xFFFF6E40),
          importance: NotificationImportance.High,
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
    if (kIsWeb) return;
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
    if (kIsWeb) return;
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  // Hàm lấy FCM token của thiết bị hiện tại.
  // Token này dùng để gửi thông báo từ server về đúng thiết bị.
  // Sau khi lấy được token, sẽ lưu vào Firestore để backend sử dụng.
  Future<String?> getFirebaseToken({String? vapidKey}) async {
    if (kIsWeb) {
      try {
        bool isSupported = await FirebaseMessaging.instance.isSupported();
        if (!isSupported) {
          developer.log('Push notifications not supported on Web. Cannot get token.', name: 'FCM');
          return null;
        }
        
        final resolvedVapidKey = vapidKey ??
          const String.fromEnvironment('FCM_VAPID_KEY') ??
          dotenv.env['FCM_VAPID_KEY'];
        if (resolvedVapidKey == null || resolvedVapidKey.isEmpty) {
          developer.log('Missing FCM_VAPID_KEY for Web', name: 'FCM');
          return null;
        }

        _fcmToken = await FirebaseMessaging.instance.getToken(
          vapidKey: resolvedVapidKey,
        );

        developer.log('Web FCM Token: $_fcmToken', name: 'FCM');

        if (_fcmToken != null) {
          await _saveTokenToFirestore(_fcmToken!);
        }

        return _fcmToken;
      } catch (e) {
        developer.log('Error getting Web FCM token: $e', name: 'FCM');
        return null;
      }
    }

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
    if (kIsWeb) return;
    await AwesomeNotificationsFcm().subscribeToTopic(topic);
    developer.log('Subscribed to topic: $topic', name: 'FCM');
  }

  // Hàm hủy đăng ký nhận thông báo theo topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;
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

  // Hybrid approach:
  // - Chat/moment/like: OS tự hiển thị notification từ FCM "notification" field
  // - Call: data-only → mySilentDataHandle tạo notification CÓ nút Nghe/Từ chối (như Zalo)
  @pragma("vm:entry-point")
  static Future<void> mySilentDataHandle(FcmSilentData silentData) async {
    if (kIsWeb) return;
    developer.log(
      'Silent Data received | lifecycle: ${silentData.createdLifeCycle} | data: ${silentData.data}',
      name: 'FCM',
    );

    final data = silentData.data ?? {};
    final type = data['type'];

    // CALL: Xử lý khi app ở background/killed
    // Nếu app đang ở foreground, Dialog trong chat_provider sẽ lo hiển thị
    if (type == 'call') {
      if (silentData.createdLifeCycle != NotificationLifeCycle.Foreground) {
        await _createCallNotification(data);
      }
      return;
    }

    // Các loại khác (chat/moment/like): 
    // Khi background/killed → OS đã hiển thị từ FCM notification field
    // Khi foreground → tạo in-app notification
    if (silentData.createdLifeCycle != NotificationLifeCycle.Foreground) {
      developer.log('Background/Killed + non-call → handled by OS', name: 'FCM');
      return;
    }

    // Foreground: tạo in-app notification có style đẹp hơn
    try {
      if (type == 'chat') {
        final matchId = data['matchId'] ?? '';
        // Bỏ qua nếu user đang mở đúng màn hình chat đó
        if (ChatProvider.currentActiveMatchId == matchId) return;

        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            channelKey: 'gamenect_channel',
            title: data['peerUsername'] ?? 'User',
            body: data['message'] ?? 'Tin nhắn mới',
            payload: {
              'type': 'chat',
              'matchId': data['matchId'] ?? '',
              'peerUserId': data['peerUserId'] ?? '',
            },
            notificationLayout: NotificationLayout.Messaging,
            category: NotificationCategory.Message,
            wakeUpScreen: true,
            displayOnForeground: true,
          ),
          actionButtons: [],
        );
      } else if (type == 'moment_reaction') {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: (data['momentId'] ?? '').hashCode,
            channelKey: 'moment_channel',
            title: '${data['reactorUsername'] ?? 'Someone'} đã thả ${data['emoji'] ?? '❤️'}',
            body: 'vào moment của bạn',
            payload: {
              'type': 'moment_reaction',
              'momentId': data['momentId'] ?? '',
              'reactorUserId': data['reactorUserId'] ?? '',
            },
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Social,
            displayOnForeground: true,
          ),
          actionButtons: [],
        );
      }
    } catch (e) {
      developer.log('Error creating foreground notification: $e', name: 'FCM');
    }
  }

  // Tạo call notification có action buttons — dùng cho mọi trạng thái app
  static Future<void> _createCallNotification(Map<String, String?> data) async {
    if (kIsWeb) return;
    try {
      final peerUsername = data['peerUsername'] ?? 'User';
      final matchId = data['matchId'] ?? '';
      final peerUserId = data['peerUserId'] ?? '';
      final callType = data['callType'] ?? 'video';
      final callTypeLabel = callType == 'voice' ? 'thoại' : 'video';

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: matchId.hashCode,
          channelKey: 'call_channel',
          title: '📞 Cuộc gọi $callTypeLabel đến',
          body: '$peerUsername đang gọi cho bạn',
          payload: {
            'type': 'call',
            'matchId': matchId,
            'peerUserId': peerUserId,
          },
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Call,
          wakeUpScreen: true,
          fullScreenIntent: true,   // Hiển thị full screen khi màn hình khóa
          criticalAlert: true,       // Vượt qua chế độ im lặng
          locked: true,              // Không thể vuốt tắt
        ),
        // Nút Nghe và Từ chối hiển thị trực tiếp trên notification
        actionButtons: [
          NotificationActionButton(
            key: 'accept',
            label: '✅ Nghe',
            color: Colors.green,
            autoDismissible: true,
          ),
          NotificationActionButton(
            key: 'decline',
            label: '❌ Từ chối',
            color: Colors.red,
            autoDismissible: true,
          ),
        ],
      );
      developer.log('Call notification created with action buttons', name: 'FCM');
    } catch (e) {
      developer.log('Error creating call notification: $e', name: 'FCM');
    }
  }

  // Hàm xử lý khi nhận FCM Token mới từ Firebase.
  // Lưu token vào Firestore để backend sử dụng gửi thông báo.
  @pragma("vm:entry-point")
  static Future<void> myFcmTokenHandle(String token) async {
    if (kIsWeb) return;
    developer.log('FCM Token Handle: $token', name: 'FCM');
    await _saveTokenToFirestore(token);
  }

  // Hàm xử lý khi nhận Native Token (APNS cho iOS).
  @pragma("vm:entry-point")
  static Future<void> myNativeTokenHandle(String token) async {
    if (kIsWeb) return;
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
    if (kIsWeb) return;
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
      actionButtons: [],
    );
  }

  // Hàm hiển thị notification cuộc gọi đến.
  // Tạo thông báo với hai nút nghe và từ chối, có thể hiện popup toàn màn hình.
  static Future<void> showCallNotification({
    required String peerUsername,
    required String matchId,
    required String peerUserId,
  }) async {
    if (kIsWeb) return;
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
    if (kIsWeb) return;
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
      actionButtons: [],
    );
  }

  // Hàm tạo notification cơ bản, dùng cho các trường hợp thông báo khác.
  static Future<void> createNewNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    if (kIsWeb) return;
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
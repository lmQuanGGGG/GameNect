import 'dart:ui';

import 'package:flutter/material.dart';
import 'user/screens/main/main_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'package:cached_network_image/cached_network_image.dart';
import 'core/services/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_handler.dart';
import 'core/services/moment_notification_navigation.dart';
import 'core/controllers/notification_controller.dart';
import 'core/providers/profile_provider.dart';
import 'core/providers/edit_profile_provider.dart';
import 'core/providers/auth_provider.dart' as local;
import 'core/providers/location_provider.dart';
import 'core/providers/match_provider.dart';
import 'core/providers/chat_provider.dart';
import 'core/providers/moment_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/game_provider.dart';
import 'core/providers/mentor_provider.dart';
import 'core/providers/livestream_provider.dart';
import 'core/providers/wallet_provider.dart';
import 'core/utils/fullscreen_helper.dart'
    if (dart.library.html) 'core/utils/fullscreen_helper_web.dart';
import 'core/services/web_notification.dart';
import 'core/services/web_message.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/models/user_model.dart';
import 'user/screens/matching/home_screen.dart';
import 'user/screens/chat/chat_screen.dart';
import 'user/screens/auth/login_screen.dart';

import 'user/user_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences sharedPrefs;

// Pending FCM message khi app được mở từ notification (top-level để tránh lỗi scope)
RemoteMessage? _pendingFcmMessage;
bool _webDeepLinkHandled = false;
String? _lastWebNotificationKey;
DateTime? _lastWebNotificationAt;

final _notificationLifecycleObserver = _NotificationLifecycleObserver();

class _NotificationLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!kIsWeb) {
        AwesomeNotifications().resetGlobalBadge();
      }
      AppNotificationHandler.processPendingAction();
    }
  }
}

// Hàm main: điểm khởi đầu của ứng dụng
void main() async {
  // Đảm bảo Flutter đã được khởi tạo trước khi thực hiện bất kỳ hoạt động bất đồng bộ nào
  WidgetsFlutterBinding.ensureInitialized();
  try {
    sharedPrefs = await SharedPreferences.getInstance();
  } catch (e) {
    developer.log('Lỗi khởi tạo SharedPreferences: $e', name: 'Init');
  }
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    developer.log(
      'Không tìm thấy file .env (chấp nhận được trên Web Production)',
      name: 'Config',
    );
  }

  // Khởi tạo Firebase với các tùy chọn cho nền tảng hiện tại
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    startWebVideoContainTimer();
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (e) {
      developer.log('Error setting auth persistence: $e', name: 'Auth-Web');
    }

    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled:
            false, // Tắt trên Web để tránh bị khóa IndexedDB gây treo
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      developer.log(
        'Error setting firestore persistence: $e',
        name: 'Firestore-Web',
      );
    }

    try {
      bool isSupported = await FirebaseMessaging.instance.isSupported();
      if (isSupported) {
        await FirebaseMessaging.instance.requestPermission();
        FirebaseMessaging.onMessage.listen(_handleWebForegroundMessage);

        // Tự động cập nhật Token mới lên Firestore nếu Firebase thay đổi Token ngầm
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          NotificationController.myFcmTokenHandle(newToken);
        });
      } else {
        developer.log(
          'Push notifications not supported on this browser/tab. Skipping FCM init.',
          name: 'FCM-Web',
        );
      }
    } catch (e) {
      developer.log('Error checking FCM support: $e', name: 'FCM-Web');
    }

    // Vẫn listen web message vì app có thể đang chạy dưới dạng Standalone PWA trên iOS
    // và nhận message từ Service Worker (do OS mở lại)
    WebMessageService.listen((data) async {
      await _handleFcmTap(data);
    });
  }

  // Khởi tạo thông báo cục bộ và từ xa với chế độ debug
  if (!kIsWeb) {
    await NotificationController.initializeLocalNotifications(debug: true);
    await NotificationController.initializeRemoteNotifications(debug: true);
    await NotificationController.requestPermissions();

    // Thiết lập các listener cho AwesomeNotifications
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: AppNotificationHandler.onActionReceivedMethod,
      onNotificationCreatedMethod:
          AppNotificationHandler.onNotificationCreatedMethod,
      onNotificationDisplayedMethod:
          AppNotificationHandler.onNotificationDisplayedMethod,
      onDismissActionReceivedMethod:
          AppNotificationHandler.onDismissActionReceivedMethod,
    );

    // iOS: khi app đang foreground, iOS suppress notification field từ FCM.
    // Phải tự tạo local notification thông qua FirebaseMessaging.onMessage.
    // Android không bị ảnh hưởng vì đã có channelId + notification field xử lý đúng.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Yêu cầu iOS cấp quyền hiển thị notification (alert, badge, sound)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS: cho phép hiển thị notification khi app đang foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  if (!kIsWeb) {
    // Killed state: tap FCM notification → app mở lại
    _pendingFcmMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (_pendingFcmMessage != null) {
      developer.log(
        'getInitialMessage stored: ${_pendingFcmMessage!.data}',
        name: 'FCM-Tap',
      );
    }

    // Background state: tap FCM notification → listener phải đăng ký sớm
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      developer.log('onMessageOpenedApp: ${message.data}', name: 'FCM-Tap');
      // Nếu navigator chưa sẵn sàng thì chờ
      await Future.delayed(const Duration(milliseconds: 500));
      await _handleFcmTap(message.data);
    });
  }

  // Chạy ứng dụng chính
  runApp(const GameNectApp());
  WidgetsBinding.instance.addObserver(_notificationLifecycleObserver);

  // Sau khi app build xong, xử lý pending tap
  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      while (navigatorKey.currentState == null) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      AwesomeNotifications().resetGlobalBadge();

      // Handle any queued notification actions once navigator is ready
      await AppNotificationHandler.processPendingAction();

      // Navigate từ killed-state FCM tap
      if (_pendingFcmMessage != null) {
        developer.log(
          'Processing pending FCM tap: ${_pendingFcmMessage!.data}',
          name: 'FCM-Tap',
        );
        await _handleFcmTap(_pendingFcmMessage!.data);
        _pendingFcmMessage = null;
      }

      // Navigate từ killed-state AwesomeNotifications tap (iOS foreground notification)
      final initialAction = await AwesomeNotifications()
          .getInitialNotificationAction(removeFromActionEvents: true);
      if (initialAction != null) {
        developer.log(
          'Processing initial notification action: ${initialAction.payload}',
          name: 'FCM-Tap',
        );
        await AppNotificationHandler.onActionReceivedMethod(initialAction);
      }
    });
  }
}

// Điều hướng khi tap FCM notification (background/killed state)
Future<void> _handleFcmTap(Map<String, dynamic> data) async {
  final type = data['type'] ?? '';
  developer.log('_handleFcmTap: type=$type data=$data', name: 'FCM-Tap');
  developer.log(
    'Navigator state: ${navigatorKey.currentState}',
    name: 'FCM-Tap',
  );

  try {
    if (kIsWeb) {
      if (type == 'call') {
        final matchId = data['matchId'] ?? '';
        final peerUserId = data['peerUserId'] ?? '';
        developer.log(
          'Web FCM tap: Call notification clicked. matchId=$matchId peerUserId=$peerUserId',
          name: 'FCM-Tap',
        );
        if (matchId.isNotEmpty && peerUserId.isNotEmpty) {
          AppNotificationHandler.showIncomingCallDialog(matchId, peerUserId);
        }
        return;
      }

      // Chỉ xử lý các type hợp lệ của Web
      if (type == 'chat' ||
          type == 'match' ||
          type == 'moment_reaction' ||
          type == 'like') {
        int targetIndex = 0;
        if (type == 'chat' || type == 'match') {
          targetIndex = 3; // MatchListScreen (Tin nhắn)
        } else if (type == 'moment_reaction') {
          targetIndex = 1; // MomentScreen (Feed)
        } else if (type == 'like') {
          targetIndex = 2; // LikedMeScreen (Lượt thích)
        }

        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        mainScreenTabIndex.value = targetIndex;

        if (type == 'chat' || type == 'match') {
          final matchId = data['matchId'] ?? '';
          final peerUserId = data['peerUserId'] ?? '';
          if (matchId.isNotEmpty && peerUserId.isNotEmpty) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(peerUserId)
                .get();
            if (userDoc.exists && userDoc.data() != null) {
              final peerUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(matchId: matchId, peerUser: peerUser),
                ),
              );
            }
          }
        } else if (type == 'moment_reaction') {
          final momentId = data['momentId'] ?? '';
          if (momentId.isNotEmpty) {
            pendingMomentIdToOpen.value = momentId;
          }
        } else if (type == 'like') {
          navigatorKey.currentState?.pushNamed('/liked-me');
        }

        developer.log(
          'Web FCM tap: Navigated to tab index $targetIndex and pushed detail',
          name: 'FCM-Tap',
        );
        return;
      } else if (type == 'mentor_live') {
        final streamId = data['streamId'] ?? '';
        if (streamId.isNotEmpty) {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
          navigatorKey.currentState?.pushNamed(
            '/live-stream',
            arguments: {'streamId': streamId, 'isMentor': false},
          );
          developer.log(
            'Web FCM tap: Navigated to /live-stream streamId=$streamId',
            name: 'FCM-Tap',
          );
        }
        return;
      }

      // Nếu type không khớp hoặc không hợp lệ, KHÔNG làm gì cả (tránh tự động chuyển về home screen)
      developer.log(
        'Web FCM tap: Unknown or unhandled notification type: $type',
        name: 'FCM-Tap',
      );
      return;
    }

    switch (type) {
      case 'chat':
      case 'match':
        final matchId = data['matchId'] ?? '';
        final peerUserId = data['peerUserId'] ?? '';
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(peerUserId)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final peerUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(matchId: matchId, peerUser: peerUser),
            ),
          );
          developer.log('Navigated to ChatScreen for $type', name: 'FCM-Tap');
        }
        break;
      case 'moment_reaction':
        final momentId = data['momentId'] ?? '';
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        mainScreenTabIndex.value = 1;
        if (momentId.isNotEmpty) {
          pendingMomentIdToOpen.value = momentId;
        }
        developer.log(
          'Navigated to Moment feed tab with momentId=$momentId',
          name: 'FCM-Tap',
        );
        break;
      case 'like':
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        mainScreenTabIndex.value = 2;
        developer.log('Navigated to liked-me tab', name: 'FCM-Tap');
        break;
      case 'mentor_live':
        final streamId = data['streamId'] ?? '';
        if (streamId.isNotEmpty) {
          navigatorKey.currentState?.pushNamed(
            '/live-stream',
            arguments: {'streamId': streamId, 'isMentor': false},
          );
          developer.log(
            'Navigated to /live-stream streamId=$streamId',
            name: 'FCM-Tap',
          );
        }
        break;
      default:
        developer.log('Unknown tap type: $type', name: 'FCM-Tap');
    }
  } catch (e) {
    developer.log('Error in _handleFcmTap: $e', name: 'FCM-Tap');
  }
}

// Xử lý FCM message khi app đang foreground.
// iOS suppress notification field khi app foreground → phải tự tạo notification local.
// Android KHÔNG cần xử lý ở đây vì OS Android đã hiển thị đúng.
Future<void> _handleForegroundMessage(RemoteMessage message) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;

  developer.log(
    'Foreground FCM | title: ${message.notification?.title} | data: ${message.data}',
    name: 'FCM-Foreground',
  );

  final data = message.data;
  final type = data['type'] ?? '';

  try {
    switch (type) {
      case 'chat':
      case 'match':
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            channelKey: 'gamenect_channel',
            title:
                data['peerUsername'] ??
                message.notification?.title ??
                (type == 'match' ? 'Match mới!' : 'Tin nhắn mới'),
            body:
                data['message'] ??
                message.notification?.body ??
                (type == 'match' ? 'Nhấn để nhắn tin ngay' : ''),
            payload: {
              'type': type,
              'matchId': data['matchId'] ?? '',
              'peerUserId': data['peerUserId'] ?? '',
            },
            actionType: ActionType.Default,
            notificationLayout: NotificationLayout.Messaging,
            category: NotificationCategory.Message,
            wakeUpScreen: true,
            displayOnForeground: true,
          ),
          actionButtons: [],
        );
        break;

      case 'call':
        // Tạo call notification có nút Nghe/Từ chối (dùng lại logic hiện có)
        await NotificationController.showCallNotification(
          peerUsername:
              data['peerUsername'] ?? message.notification?.title ?? 'User',
          matchId: data['matchId'] ?? '',
          peerUserId: data['peerUserId'] ?? '',
        );
        break;

      case 'moment_reaction':
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: (data['momentId'] ?? '').hashCode,
            channelKey: 'moment_channel',
            title:
                message.notification?.title ??
                '${data['reactorUsername'] ?? 'Someone'} đã thả ${data['emoji'] ?? '❤️'}',
            body: message.notification?.body ?? 'vào moment của bạn',
            payload: {
              'type': 'moment_reaction',
              'momentId': data['momentId'] ?? '',
              'reactorUserId': data['reactorUserId'] ?? '',
            },
            actionType: ActionType.Default,
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Social,
            displayOnForeground: true,
          ),
          actionButtons: [],
        );
        break;

      case 'like':
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: (data['likerUserId'] ?? '').hashCode,
            channelKey: 'gamenect_channel',
            title: message.notification?.title ?? '💖 Có người thích bạn!',
            body: message.notification?.body ?? '',
            payload: {'type': 'like', 'likerUserId': data['likerUserId'] ?? ''},
            actionType: ActionType.Default,
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Social,
            wakeUpScreen: true,
          ),
          actionButtons: [],
        );
        break;

      case 'mentor_live':
        final mlStreamId = data['streamId'] ?? '';
        if (mlStreamId.isNotEmpty) {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: mlStreamId.hashCode.abs() % 100000,
              channelKey: 'mentor_live_channel',
              title: data['mentorUsername'] != null
                  ? '🔴 ${data['mentorUsername']} đang LIVE!'
                  : message.notification?.title ?? '🔴 Mentor đang LIVE!',
              body:
                  data['streamTitle'] ??
                  message.notification?.body ??
                  'Nhấn để xem ngay',
              payload: {'type': 'mentor_live', 'streamId': mlStreamId},
              actionType: ActionType.Default,
              notificationLayout: NotificationLayout.Default,
              category: NotificationCategory.Reminder,
              wakeUpScreen: true,
              displayOnForeground: true,
            ),
            actionButtons: [],
          );
        }
        break;

      default:
        // Thông báo không xác định loại → hiển thị generic
        if (message.notification != null) {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              channelKey: 'basic_channel',
              title: message.notification!.title ?? 'GameNect',
              body: message.notification!.body ?? '',
              notificationLayout: NotificationLayout.Default,
              wakeUpScreen: true,
            ),
            actionButtons: [],
          );
        }
    }
  } catch (e) {
    developer.log(
      'Error creating foreground notification: $e',
      name: 'FCM-Foreground',
    );
  }
}

Future<void> _handleWebForegroundMessage(RemoteMessage message) async {
  developer.log(
    'Web foreground FCM | title: ${message.notification?.title} | data: ${message.data}',
    name: 'FCM-Web',
  );

  final messageKey =
      message.messageId ??
      '${message.data['type'] ?? ''}-${message.data['matchId'] ?? ''}-${message.data['momentId'] ?? ''}';
  final now = DateTime.now();
  if (_lastWebNotificationKey == messageKey &&
      _lastWebNotificationAt != null &&
      now.difference(_lastWebNotificationAt!) < const Duration(seconds: 3)) {
    return;
  }
  _lastWebNotificationKey = messageKey;
  _lastWebNotificationAt = now;

  final title =
      message.notification?.title ??
      (message.data['title']?.toString() ?? 'GameNect');
  final body =
      message.notification?.body ?? (message.data['body']?.toString() ?? '');

  final data = <String, String>{};
  message.data.forEach((key, value) {
    if (value != null) {
      data[key] = value.toString();
    }
  });

  // Bỏ qua hiển thị thông báo tin nhắn nếu đang mở màn hình chat đó
  if (data['type'] == 'chat') {
    final matchId = data['matchId'] ?? '';
    if (ChatProvider.currentActiveMatchId == matchId) {
      return;
    }
  }

  await WebNotificationService.show(
    title: title,
    body: body,
    data: data,
    onClick: () async {
      await _handleFcmTap(data);
    },
  );
}

Future<void> _handleWebDeepLinkIfAny() async {
  if (!kIsWeb || _webDeepLinkHandled) return;
  final params = Uri.base.queryParameters;
  if (params.isEmpty || !params.containsKey('type')) return;
  _webDeepLinkHandled = true;
  await _handleFcmTap(params);
}

// Widget chính của ứng dụng GameNect
class GameNectApp extends StatelessWidget {
  const GameNectApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider để cung cấp các provider cho toàn bộ ứng dụng
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProxyProvider<LocationProvider, local.AuthProvider>(
          create: (context) {
            final authProvider = local.AuthProvider();
            authProvider.setLocationProvider(
              Provider.of<LocationProvider>(context, listen: false),
            );
            return authProvider;
          },
          update: (context, locationProvider, authProvider) {
            authProvider?.setLocationProvider(locationProvider);
            return authProvider ?? local.AuthProvider()
              ..setLocationProvider(locationProvider);
          },
        ),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => EditProfileProvider()),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => MomentProvider()),
        Provider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => MentorProvider()),
        ChangeNotifierProvider(create: (_) => LivestreamProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'GameNect',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            initialRoute: '/',
            routes: AppRouter.routes,
            onGenerateRoute: AppRouter.onGenerateRoute,
            onUnknownRoute: AppRouter.onUnknownRoute,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
            locale: const Locale('vi', 'VN'),
            navigatorKey: navigatorKey,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
          );
        },
      ),
    );
  }
}

// Helper function to initialize user services asynchronously after login
Future<void> _setupUserSession(BuildContext context, String uid) async {
  try {
    final fcmToken = await NotificationController().getFirebaseToken();
    developer.log('FCM Token retrieved after login: $fcmToken', name: 'Auth');

    if (!context.mounted) return;
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final matchProvider = Provider.of<MatchProvider>(context, listen: false);
    final momentProvider = Provider.of<MomentProvider>(context, listen: false);

    if (kIsWeb) {
      await profileProvider.loadUserProfile(forceRefresh: true);
      Future<void>(() async {
        await locationProvider.requestLocationPermission();
        final didUpdate = await locationProvider.updateUserLocation(uid);
        if (!didUpdate) return;
        await profileProvider.loadUserProfile(forceRefresh: true);
        final refreshedUser = profileProvider.userData;
        if (refreshedUser != null) {
          locationProvider.loadSettingsFromUser(refreshedUser);
        }
      });
    } else {
      await locationProvider.requestLocationPermission();
      await locationProvider.updateUserLocation(uid);
      await profileProvider.loadUserProfile(forceRefresh: true);
    }

    if (profileProvider.userData != null) {
      locationProvider.loadSettingsFromUser(profileProvider.userData!);
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      final matches = await matchProvider.fetchMatchedUsersWithMatchId(
        currentUserId,
      );
      for (var match in matches) {
        final matchId = match['matchId'] as String;
        final peerUser = match['user'] as UserModel;
        chatProvider.listenForIncomingCalls(matchId, peerUser);
      }

      // TẢI SẴN TIN NHẮN CỦA 10 CUỘC TRÒ CHUYỆN GẦN NHẤT (MỖI NGƯỜI 10 TIN NHẮN)
      final topMatches = matches
          .take(10)
          .map((m) => m['matchId'] as String)
          .toList();
      await chatProvider.preloadTopChatsMessages(topMatches);
      developer.log(
        'Preloaded last 10 messages for top 10 matches',
        name: 'Auth',
      );

      developer.log('Starting moment reactions listener...', name: 'Auth');
      await momentProvider.listenMoments(currentUserId);
      developer.log('Moment listener started', name: 'Auth');

      // TẢI SẴN & PRECACHE ẢNH CỦA 10 MOMENTS ĐẦU TIÊN
      if (context.mounted) {
        final topMoments = momentProvider.moments.take(10);
        for (var moment in topMoments) {
          final imageUrl = moment.isVideo
              ? (moment.thumbnailUrl ?? '')
              : moment.mediaUrl;
          if (imageUrl.isNotEmpty) {
            precacheImage(
              CachedNetworkImageProvider(imageUrl),
              context,
            ).catchError((_) => null);
          }
        }
      }

      // TẢI SẴN & PRECACHE ẢNH CỦA 10 MENTOR MEDIA ĐẦU TIÊN
      final mentorMediaSnapshot = await FirebaseFirestore.instance
          .collection('mentor_media')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      if (context.mounted) {
        for (var doc in mentorMediaSnapshot.docs) {
          final data = doc.data();
          final isVideo = data['type'] == 'video';
          final imageUrl = isVideo
              ? (data['thumbnailUrl'] as String? ?? '')
              : (data['url'] as String? ?? '');
          if (imageUrl.isNotEmpty) {
            precacheImage(
              CachedNetworkImageProvider(imageUrl),
              context,
            ).catchError((_) => null);
          }
        }
      }

      // TẢI SẴN ĐỀ XUẤT MATCH & PRECACHE ẢNH CỦA 10 NGƯỜI ĐẦU TIÊN
      if (profileProvider.userData != null) {
        final userModel = profileProvider.userData!;
        if (userModel.latitude == null || userModel.longitude == null) {
          developer.log(
            'Bỏ qua preload match vì user chưa có tọa độ đã lưu',
            name: 'AppPreload',
          );
          return;
        }
        final candidateUsers = await FirestoreService().getUsersWithinRadius(
          latitude: userModel.latitude!,
          longitude: userModel.longitude!,
          radiusKm: userModel.maxDistance,
          limit: 100,
        );
        await matchProvider.fetchRecommendations(userModel, candidateUsers);
        if (context.mounted) {
          final topRecs = matchProvider.recommendations.take(10);
          for (var rec in topRecs) {
            // Precache avatar
            if (rec.avatarUrl != null && rec.avatarUrl!.isNotEmpty) {
              precacheImage(
                CachedNetworkImageProvider(rec.avatarUrl!),
                context,
              ).catchError((_) => null);
            }
            // Precache additional photos (tải trước ảnh phụ)
            for (var photo in rec.additionalPhotos.take(2)) {
              if (photo.isNotEmpty) {
                precacheImage(
                  CachedNetworkImageProvider(photo),
                  context,
                ).catchError((_) => null);
              }
            }
          }
        }
      }

      // TẢI SẴN MENTORS & PRECACHE ẢNH CỦA 10 MENTOR ĐẦU TIÊN
      if (context.mounted) {
        final mentorProvider = Provider.of<MentorProvider>(
          context,
          listen: false,
        );
        await mentorProvider.loadApprovedMentors();
        if (context.mounted) {
          final topMentors = mentorProvider.approvedMentors.take(10);
          for (var mentor in topMentors) {
            final avatarUrl = mentor['avatarUrl'] as String?;
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              precacheImage(
                CachedNetworkImageProvider(avatarUrl),
                context,
              ).catchError((_) => null);
            }
          }
        }
        developer.log(
          'Preloaded approved mentors list and precached top 10 avatar images',
          name: 'Auth',
        );
      }

      // Bắt đầu lắng nghe khi mentor follow đang live
      if (context.mounted) {
        Provider.of<MentorProvider>(
          context,
          listen: false,
        ).startMentorLiveListener(currentUserId);
        developer.log('Mentor live listener started', name: 'Auth');
      }
    }

    await _handleWebDeepLinkIfAny();
  } catch (e) {
    developer.log('Error setting up user session: $e', name: 'Auth');
  }
}

// Widget bao bọc để xử lý trạng thái xác thực
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = Provider.of<AuthService>(
      context,
      listen: false,
    );

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.games, size: 80, color: Colors.deepOrange),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Colors.deepOrange),
                  SizedBox(height: 16),
                  Text(
                    'Đang khởi động...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Lỗi xác thực',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          developer.log('User logged in: ${snapshot.data!.uid}', name: 'Auth');
          final uid = snapshot.data!.uid;

          // Kiểm tra xem user đã có thông tin cá nhân (username) được lưu ở local preference chưa
          final isProfileCompleted =
              sharedPrefs.getBool('profile_completed_$uid') ?? false;

          int? initialIndex;
          if (kIsWeb) {
            final params = Uri.base.queryParameters;
            if (params.isNotEmpty && params.containsKey('type')) {
              final type = params['type'];
              if (type == 'chat') {
                initialIndex = 3;
              } else if (type == 'moment_reaction') {
                initialIndex = 1;
              } else if (type == 'like') {
                initialIndex = 2;
              } else if (type == 'mentor_live') {
                initialIndex = 1;
              }
            }
          }

          if (isProfileCompleted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _setupUserSession(context, uid);
            });
            return UserApp(initialIndex: initialIndex);
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _setupUserSession(context, uid);
          });

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.deepOrange),
                        SizedBox(height: 16),
                        Text(
                          'Đang kiểm tra quyền truy cập...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (userSnapshot.hasError) {
                return const HomeScreen();
              }

              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const UserApp(initialRoute: '/profile');
              }

              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>?;

              if (userData == null) {
                return const UserApp(initialRoute: '/profile');
              }

              final isNewUser =
                  userData['username'] == null ||
                  userData['username'].toString().isEmpty;

              if (isNewUser) {
                return const UserApp(initialRoute: '/profile');
              }

              // Lưu trạng thái đã cấu hình xong thông tin cá nhân
              sharedPrefs.setBool('profile_completed_$uid', true);

              final isAdmin = userData['isAdmin'] ?? false;

              // Cả admin và user đều vào UserApp để xem profile cá nhân
              developer.log('User logged in (isAdmin: $isAdmin)', name: 'Auth');
              return UserApp(initialIndex: initialIndex);
            },
          );
        } else {
          // Người dùng đã đăng xuất, dọn dẹp các call subscriptions trong ChatProvider
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final chatProvider = Provider.of<ChatProvider>(
              context,
              listen: false,
            );
            chatProvider.clearAllSubscriptions();
            Provider.of<ProfileProvider>(
              context,
              listen: false,
            ).clearUserProfile();
            Provider.of<MentorProvider>(
              context,
              listen: false,
            ).clearMyMentorProfile();
          });
        }

        developer.log('No user logged in (Guest Mode)', name: 'Auth');
        int? guestInitialIndex;
        if (kIsWeb) {
          final params = Uri.base.queryParameters;
          if (params.isNotEmpty && params.containsKey('type')) {
            final type = params['type'];
            if (type == 'mentor_live') {
              guestInitialIndex = 1;
            } else if (type == 'moment_reaction' || type == 'like') {
              // Redirect to login if trying to access restricted content directly
              return const LoginScreen();
            }
          }
        }
        return UserApp(initialIndex: guestInitialIndex);
      },
    );
  }
}

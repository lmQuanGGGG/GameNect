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

import 'core/services/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_handler.dart';
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
import 'core/services/web_notification.dart';
import 'core/services/web_message.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/models/user_model.dart';
import 'user/screens/matching/home_screen.dart';
import 'user/screens/chat/chat_screen.dart';

import 'user/user_app.dart';

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
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (e) {
      developer.log('Error setting auth persistence: $e', name: 'Auth-Web');
    }

    try {
      bool isSupported = await FirebaseMessaging.instance.isSupported();
      if (isSupported) {
        await FirebaseMessaging.instance.requestPermission();
        FirebaseMessaging.onMessage.listen(_handleWebForegroundMessage);
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
      await Future.delayed(const Duration(milliseconds: 1000));
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
      int targetIndex = 0; // Default: Khám phá
      if (type == 'chat') {
        targetIndex = 3; // MatchListScreen (Tin nhắn)
      } else if (type == 'moment_reaction') {
        targetIndex = 1; // MomentScreen (Feed)
      } else if (type == 'like') {
        targetIndex = 2; // LikedMeScreen (Lượt thích)
      }

      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      mainScreenTabIndex.value = targetIndex;
      developer.log(
        'Web FCM tap: Navigated to tab index $targetIndex',
        name: 'FCM-Tap',
      );
      return;
    }

    switch (type) {
      case 'chat':
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
          developer.log('Navigated to ChatScreen', name: 'FCM-Tap');
        }
        break;
      case 'moment_reaction':
        navigatorKey.currentState?.pushNamed(
          '/moments',
          arguments: {'momentId': data['momentId'] ?? ''},
        );
        developer.log('Navigated to /moments', name: 'FCM-Tap');
        break;
      case 'like':
        navigatorKey.currentState?.pushNamed('/liked-me');
        developer.log('Navigated to /liked-me', name: 'FCM-Tap');
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
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            channelKey: 'gamenect_channel',
            title:
                data['peerUsername'] ??
                message.notification?.title ??
                'Tin nhắn mới',
            body: data['message'] ?? message.notification?.body ?? '',
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
          );
        },
      ),
    );
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

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              final fcmToken = await NotificationController()
                  .getFirebaseToken();
              developer.log(
                'FCM Token retrieved after login: $fcmToken',
                name: 'Auth',
              );

              if (!context.mounted) return;
              final locationProvider = Provider.of<LocationProvider>(
                context,
                listen: false,
              );
              final profileProvider = Provider.of<ProfileProvider>(
                context,
                listen: false,
              );
              final chatProvider = Provider.of<ChatProvider>(
                context,
                listen: false,
              );
              final matchProvider = Provider.of<MatchProvider>(
                context,
                listen: false,
              );
              final momentProvider = Provider.of<MomentProvider>(
                context,
                listen: false,
              );

              await locationProvider.updateUserLocation(snapshot.data!.uid);

              if (profileProvider.userData == null) {
                await profileProvider.loadUserProfile();
              }

              if (profileProvider.userData != null) {
                locationProvider.loadSettingsFromUser(
                  profileProvider.userData!,
                );
              }

              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId != null) {
                final matches = await matchProvider
                    .fetchMatchedUsersWithMatchId(currentUserId);
                for (var match in matches) {
                  final matchId = match['matchId'] as String;
                  final peerUser = match['user'] as UserModel;
                  chatProvider.messagesStream(matchId, peerUser).listen((_) {});
                  chatProvider.listenForIncomingCalls(matchId, peerUser);
                }

                developer.log(
                  'Starting moment reactions listener...',
                  name: 'Auth',
                );
                await momentProvider.listenMoments(currentUserId);
                developer.log('Moment listener started', name: 'Auth');

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
              developer.log('Error getting FCM token: $e', name: 'Auth');
            }
          });

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
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

              final isAdmin = userData['isAdmin'] ?? false;

              // Cả admin và user đều vào UserApp để xem profile cá nhân
              developer.log('User logged in (isAdmin: $isAdmin)', name: 'Auth');
              return const UserApp();
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
          });
        }

        developer.log('No user logged in', name: 'Auth');
        return const HomeScreen();
      },
    );
  }
}

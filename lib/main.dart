import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'core/providers/game_provider.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/models/user_model.dart';
import 'user/screens/auth/login_screen.dart';
import 'admin/admin_app.dart';
import 'user/user_app.dart';

// Hàm main: điểm khởi đầu của ứng dụng
void main() async {
  // Đảm bảo Flutter đã được khởi tạo trước khi thực hiện bất kỳ hoạt động bất đồng bộ nào
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    developer.log('Không tìm thấy file .env (chấp nhận được trên Web Production)', name: 'Config');
  }

  // Khởi tạo Firebase với các tùy chọn cho nền tảng hiện tại
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
  }

  // Chạy ứng dụng chính
  runApp(const GameNectApp());
}

// Widget chính của ứng dụng GameNect
class GameNectApp extends StatelessWidget {
  const GameNectApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider để cung cấp các provider cho toàn bộ ứng dụng
    return MultiProvider(
      providers: [
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
      ],
      child: MaterialApp(
        title: 'GameNect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
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
              }
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

              if (userSnapshot.hasError ||
                  !userSnapshot.hasData ||
                  !userSnapshot.data!.exists) {
                return LoginScreen();
              }

              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>?;

              if (userData == null) {
                return LoginScreen();
              }

              final isAdmin = userData['isAdmin'] ?? false;

              if (isAdmin == true) {
                developer.log('ADMIN DETECTED', name: 'Auth');
                return const AdminApp();
              }

              developer.log('Regular user detected', name: 'Auth');
              return const UserApp();
            },
          );
        }

        developer.log('No user logged in', name: 'Auth');
        return LoginScreen();
      },
    );
  }
}

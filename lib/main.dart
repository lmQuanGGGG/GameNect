import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/services/auth_service.dart';
import 'user/screens/login_screen.dart';
import 'user/user_app.dart';
import 'user/screens/edit_profile_screen.dart';
import 'package:provider/provider.dart';
import 'user/screens/home_profile_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/providers/profile_provider.dart';
import 'core/providers/edit_profile_provider.dart';
import 'core/providers/auth_provider.dart' as local;
import 'core/providers/location_provider.dart';
import 'user/screens/phone_login_screen.dart';
import 'user/screens/email_login_screen.dart';
import 'user/screens/admin_test_users_screen.dart';
import 'core/providers/match_provider.dart';
import 'core/services/firestore_service.dart';
import 'core/providers/chat_provider.dart';
import 'core/providers/moment_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/models/user_model.dart';
import 'user/screens/chat_screen.dart';
import 'user/screens/video_call_screen.dart';
import 'dart:developer' as developer;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final granted = await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);
  
  developer.log('iOS Notification Permission: $granted', name: 'Main.Notification');
  
  if (granted == false) {
    developer.log('iOS Notification Permission DENIED. Guide user to Settings.', name: 'Main.Notification');
  }

  final darwinCallCategory = DarwinNotificationCategory(
    'CALL_CATEGORY',
    actions: [
      DarwinNotificationAction.plain('accept', 'Nghe'),
      DarwinNotificationAction.plain('decline', 'Từ chối'),
    ],
  );

  final initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      notificationCategories: [darwinCallCategory],
    ),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final payload = response.payload ?? '';
      final parts = payload.split(':');
    
      final context = navigatorKey.currentContext;
      if (context == null) {
        developer.log('Navigator context is null, cannot handle notification', name: 'Main.Notification');
        return;
      }

      if (payload.startsWith('call:') && parts.length >= 3) {
        final matchId = parts[1];
        final peerUserId = parts[2];

        if (response.actionId == 'accept') {
          developer.log('Accept call action triggered', name: 'Main.Call');
          await _handleAcceptCall(matchId, peerUserId);
          return;
        }

        if (response.actionId == 'decline') {
          developer.log('Decline call action triggered', name: 'Main.Call');
          
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId == null) return;
          
          await FirebaseFirestore.instance
              .collection('calls')
              .doc(matchId)
              .set({
                'status': 'declined',
                'answered': false,
                'endedAt': DateTime.now().toIso8601String(),
              }, SetOptions(merge: true));
          
          await FirestoreService().addCallMessage(
            matchId: matchId,
            senderId: currentUserId,
            duration: 0,
            declined: true,
          );
          
          return;
        }

        developer.log('Show incoming call dialog', name: 'Main.Call');
        showIncomingCallDialog(matchId, peerUserId);
      }

      if (payload.startsWith('chat:') && parts.length >= 3) {
        final matchId = parts[1];
        final peerUserId = parts[2];
        developer.log('Navigate to chat: $matchId', name: 'Main.Chat');
        
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(peerUserId)
            .get();
            
        if (!userDoc.exists || userDoc.data() == null) {
          developer.log('User not found: $peerUserId', name: 'Main.Chat');
          return;
        }
        
        final peerUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
        navigatorKey.currentState?.pushNamed(
          '/chat',
          arguments: {'matchId': matchId, 'peerUser': peerUser},
        );
      }
    },
  );

  runApp(const GameNectApp());
}

Future<void> _handleAcceptCall(String matchId, String peerUserId) async {
  try {
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(matchId)
        .set({'answered': true, 'status': 'accepted'}, SetOptions(merge: true));

    final peerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(peerUserId)
        .get();
        
    if (!peerDoc.exists || peerDoc.data() == null) {
      developer.log('Peer user not found', name: 'Main.Call');
      return;
    }

    final peerUser = UserModel.fromMap(peerDoc.data()!, peerDoc.id);

    navigatorKey.currentState?.pushNamed(
      '/video_call',
      arguments: {
        'channelName': matchId,
        'peerUserId': peerUserId,
        'peerUsername': peerUser.username,
        'peerAvatarUrl': peerUser.avatarUrl,
        'isVoiceCall': false,
      },
    );
  } catch (e) {
    developer.log('Error accepting call: $e', name: 'Main.Call');
  }
}

void showIncomingCallDialog(String matchId, String peerUserId) async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    developer.log('Cannot show dialog: context is null', name: 'Main.Call');
    return;
  }

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(peerUserId)
      .get();
      
  if (!userDoc.exists || userDoc.data() == null) {
    developer.log('User not found for dialog', name: 'Main.Call');
    return;
  }

  final peerUsername = userDoc.data()!['username'] ?? '';
  final peerAvatarUrl = userDoc.data()!['avatarUrl'] ?? '';

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage: peerAvatarUrl.isNotEmpty
                  ? NetworkImage(peerAvatarUrl)
                  : null,
              child: peerAvatarUrl.isEmpty ? Icon(Icons.person, size: 36) : null,
            ),
            const SizedBox(height: 16),
            Text('Cuộc gọi đến từ', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(
              peerUsername,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.call),
                  label: const Text('Nghe'),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _handleAcceptCall(matchId, peerUserId);
                  },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.call_end),
                  label: const Text('Từ chối'),
                  onPressed: () async {
                    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                    if (currentUserId == null) return;
                    
                    if (Navigator.of(dialogContext).canPop()) {
                      Navigator.of(dialogContext).pop();
                    }
                    
                    await FirebaseFirestore.instance
                        .collection('calls')
                        .doc(matchId)
                        .set({
                          'status': 'declined',
                          'answered': false,
                          'endedAt': DateTime.now().toIso8601String(),
                        }, SetOptions(merge: true));
                    
                    await FirestoreService().addCallMessage(
                      matchId: matchId,
                      senderId: currentUserId,
                      duration: 0,
                      declined: true,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class GameNectApp extends StatelessWidget {
  const GameNectApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      ],
      child: MaterialApp(
        title: 'GameNect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[100],
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => LoginScreen(),
          '/home': (context) => const UserApp(),
          '/profile': (context) => ProfileScreen(),
          '/phone-login': (context) => const PhoneLoginScreen(),
          '/home_profile': (context) => const HomeProfileScreen(),
          '/email-login': (context) => const EmailLoginScreen(),
          '/admin-test-users': (context) => const AdminTestUsersScreen(),
          '/chat': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map;
            return ChatScreen(
              matchId: args['matchId'] as String,
              peerUser: args['peerUser'] as UserModel,
            );
          },
          '/video_call': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map;
            return VideoCallScreen(
              channelName: args['channelName'] as String,
              peerUserId: args['peerUserId'] as String,
              peerUsername: args['peerUsername'] as String,
              peerAvatarUrl: args['peerAvatarUrl'] as String?,
              isVoiceCall: args['isVoiceCall'] as bool? ?? false,
            );
          },
        },
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';
          if (name.startsWith('/__/auth')) {
            return MaterialPageRoute(
              builder: (_) => const SizedBox.shrink(),
              settings: const RouteSettings(name: '_firebase_auth_cb'),
            );
          }
          return null;
        },
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.orange.shade50,
            body: Center(
              child: Text(
                'Quay lại trang trước xác nhận!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepOrange,
                  letterSpacing: .5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('vi', 'VN'),
          Locale('en', 'US'),
        ],
        locale: const Locale('vi', 'VN'),
        navigatorKey: navigatorKey,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.games, size: 80, color: Colors.deepOrange),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.deepOrange),
                  const SizedBox(height: 16),
                  const Text('Đang khởi động...', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Lỗi xác thực', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final locationProvider = Provider.of<LocationProvider>(context, listen: false);
            final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
            final chatProvider = Provider.of<ChatProvider>(context, listen: false);
            final matchProvider = Provider.of<MatchProvider>(context, listen: false);

            await locationProvider.updateUserLocation(snapshot.data!.uid);

            if (profileProvider.userData == null) {
              await profileProvider.loadUserProfile();
            }

            if (profileProvider.userData != null) {
              locationProvider.loadSettingsFromUser(profileProvider.userData!);
            }

            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            if (currentUserId != null) {
              final matches = await matchProvider.fetchMatchedUsersWithMatchId(currentUserId);
              for (var match in matches) {
                final matchId = match['matchId'] as String;
                final peerUser = match['user'] as UserModel;
                chatProvider.messagesStream(matchId, peerUser).listen((_) {});
                chatProvider.listenForIncomingCalls(matchId, peerUser);
              }
            }
          });

          return const UserApp();
        }

        return LoginScreen();
      },
    );
  }
}

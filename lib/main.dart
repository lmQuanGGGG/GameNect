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
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/models/user_model.dart';
import 'user/screens/chat_screen.dart';
import 'user/screens/video_call_screen.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'admin/admin_app.dart';
import 'core/controllers/notification_controller.dart'; 

// Khóa navigator toàn cục để điều hướng từ các phần khác của ứng dụng, đặc biệt là từ thông báo
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Hàm main: điểm khởi đầu của ứng dụng
// Khởi tạo các dịch vụ cần thiết như Firebase, thông báo, và chạy ứng dụng
void main() async {
  // Đảm bảo Flutter đã được khởi tạo trước khi thực hiện bất kỳ hoạt động bất đồng bộ nào
  WidgetsFlutterBinding.ensureInitialized();
  // Tải biến môi trường từ file .env
  await dotenv.load(fileName: ".env");
  
  // Khởi tạo Firebase với các tùy chọn cho nền tảng hiện tại
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Khởi tạo thông báo cục bộ với chế độ debug
  await NotificationController.initializeLocalNotifications(debug: true);
  
  // Khởi tạo thông báo từ xa (FCM) với chế độ debug
  await NotificationController.initializeRemoteNotifications(debug: true);
  
  // Yêu cầu quyền truy cập thông báo
  await NotificationController.requestPermissions();

  // Thiết lập các listener cho AwesomeNotifications để xử lý các sự kiện thông báo
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: onActionReceivedMethod,
    onNotificationCreatedMethod: onNotificationCreatedMethod,
    onNotificationDisplayedMethod: onNotificationDisplayedMethod,
    onDismissActionReceivedMethod: onDismissActionReceivedMethod,
  );

  // Chạy ứng dụng chính
  runApp(const GameNectApp());
}

// Hàm xử lý khi người dùng tương tác với thông báo (nhấn nút hành động)
// Được gọi khi người dùng nhấn vào thông báo hoặc nút trên thông báo
@pragma("vm:entry-point")
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  // Lấy payload và khóa hành động từ thông báo
  final payload = receivedAction.payload ?? {};
  final actionKey = receivedAction.buttonKeyPressed;
  
  // Ghi log để debug
  developer.log('Notification action: $actionKey, payload: $payload', name: 'Notification');

  // Nếu là thông báo cuộc gọi
  if (payload['type'] == 'call') {
    final matchId = payload['matchId'] ?? '';
    final peerUserId = payload['peerUserId'] ?? '';

    // Nếu nhấn chấp nhận cuộc gọi
    if (actionKey == 'accept') {
      developer.log('Accept call', name: 'Notification');
      await _handleAcceptCall(matchId, peerUserId);
    // Nếu nhấn từ chối cuộc gọi
    } else if (actionKey == 'decline') {
      developer.log('Decline call', name: 'Notification');
      await _handleDeclineCall(matchId);
    // Nếu chỉ nhấn vào thông báo (không phải nút hành động)
    } else {
      _showIncomingCallDialog(matchId, peerUserId);
    }
  }
  // Nếu là thông báo chat
  else if (payload['type'] == 'chat') {
    final matchId = payload['matchId'] ?? '';
    final peerUserId = payload['peerUserId'] ?? '';
    
    developer.log('Navigate to chat: $matchId', name: 'Notification');
    
    try {
      // Lấy thông tin người dùng từ Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(peerUserId)
          .get();
          
      if (userDoc.exists && userDoc.data() != null) {
        // Tạo đối tượng UserModel từ dữ liệu
        final peerUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
        
        // Điều hướng đến màn hình chat
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              matchId: matchId,
              peerUser: peerUser,
            ),
          ),
        );
      }
    } catch (e) {
      developer.log('Error: $e', name: 'Notification');
    }
  }
  // Nếu là thông báo phản ứng với moment
  else if (payload['type'] == 'moment_reaction') {
    final momentId = payload['momentId'] ?? '';
    final reactorUserId = payload['reactorUserId'] ?? '';
    developer.log('Navigate to moment: $momentId', name: 'Notification');
    // Điều hướng đến màn hình moments với đối số
    navigatorKey.currentState?.pushNamed(
      '/moments',
      arguments: {'momentId': momentId}
    );
  }
}

// Hàm xử lý khi thông báo được tạo
@pragma("vm:entry-point")
Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
  developer.log('Notification created: ${receivedNotification.id}', name: 'Notification');
}

// Hàm xử lý khi thông báo được hiển thị
@pragma("vm:entry-point")
Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
  developer.log('Notification displayed: ${receivedNotification.id}', name: 'Notification');
}

// Hàm xử lý khi thông báo bị bỏ qua
@pragma("vm:entry-point")
Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
  developer.log('Notification dismissed: ${receivedAction.id}', name: 'Notification');
}

// Hàm xử lý chấp nhận cuộc gọi từ thông báo
Future<void> _handleAcceptCall(String matchId, String peerUserId) async {
  try {
    // Cập nhật trạng thái cuộc gọi trong Firestore
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(matchId)
        .set({'answered': true, 'status': 'accepted'}, SetOptions(merge: true));

    // Lấy thông tin người dùng đối phương
    final peerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(peerUserId)
        .get();
        
    if (peerDoc.exists && peerDoc.data() != null) {
      final peerUser = UserModel.fromMap(peerDoc.data()!, peerDoc.id);

      // Điều hướng đến màn hình video call
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            channelName: matchId,
            peerUserId: peerUserId,
            peerUsername: peerUser.username,
            peerAvatarUrl: peerUser.avatarUrl,
            isVoiceCall: false,
          ),
        ),
      );
    }
  } catch (e) {
    developer.log('Error accepting call: $e', name: 'Notification');
  }
}

// Hàm xử lý từ chối cuộc gọi từ thông báo
Future<void> _handleDeclineCall(String matchId) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return;
  
  // Cập nhật trạng thái cuộc gọi trong Firestore
  await FirebaseFirestore.instance
      .collection('calls')
      .doc(matchId)
      .set({
        'status': 'declined',
        'answered': false,
        'endedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
  
  // Thêm tin nhắn cuộc gọi bị từ chối vào Firestore
  await FirestoreService().addCallMessage(
    matchId: matchId,
    senderId: currentUserId,
    duration: 0,
    declined: true,
  );
}

// Hàm hiển thị dialog cuộc gọi đến khi nhấn vào thông báo
void _showIncomingCallDialog(String matchId, String peerUserId) async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    developer.log('Cannot show dialog: context is null', name: 'Notification');
    return;
  }

  // Lấy thông tin người dùng từ Firestore
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(peerUserId)
      .get();
      
  if (!userDoc.exists || userDoc.data() == null) {
    developer.log('User not found for dialog', name: 'Notification');
    return;
  }

  final peerUsername = userDoc.data()!['username'] ?? '';
  final peerAvatarUrl = userDoc.data()!['avatarUrl'] ?? '';

  // Hiển thị dialog cuộc gọi đến
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
            // Avatar người gọi
            CircleAvatar(
              radius: 36,
              backgroundImage: peerAvatarUrl.isNotEmpty
                  ? NetworkImage(peerAvatarUrl)
                  : null,
              child: peerAvatarUrl.isEmpty ? Icon(Icons.person, size: 36) : null,
            ),
            const SizedBox(height: 16),
            // Tiêu đề
            Text('Cuộc gọi đến từ', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 4),
            // Tên người gọi
            Text(
              peerUsername,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
            ),
            const SizedBox(height: 24),
            // Các nút hành động
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Nút chấp nhận
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
                // Nút từ chối
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.call_end),
                  label: const Text('Từ chối'),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _handleDeclineCall(matchId);
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
        // AuthProvider phụ thuộc vào LocationProvider
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
        // Cấu hình theme của ứng dụng
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
        // Route ban đầu
        initialRoute: '/',
        // Định nghĩa các routes
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => LoginScreen(),
          '/home': (context) => const UserApp(),
          '/profile': (context) => ProfileScreen(),
          '/phone-login': (context) => const PhoneLoginScreen(),
          '/email-login': (context) => const EmailLoginScreen(),
          '/admin-test-users': (context) => const AdminTestUsersScreen(),
          '/moments': (context) => const UserApp(initialRoute: '/main'),
          // Route cho chat với arguments
          '/chat': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map;
            return ChatScreen(
              matchId: args['matchId'] as String,
              peerUser: args['peerUser'] as UserModel,
            );
          },
          // Route cho video call với arguments
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
        // Xử lý route động cho Firebase Auth
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
        // Xử lý route không xác định
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
        // Cấu hình localization cho tiếng Việt
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
        // Sử dụng navigator key toàn cục
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
    // Lấy AuthService từ provider
    final AuthService authService = Provider.of<AuthService>(context, listen: false);

    // Lắng nghe thay đổi trạng thái xác thực
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Nếu đang chờ kết nối
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

        // Nếu có lỗi
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

        // Nếu có người dùng đăng nhập
        if (snapshot.hasData && snapshot.data != null) {
          developer.log('User logged in: ${snapshot.data!.uid}', name: 'Auth');
          
          // Sau khi build xong, thực hiện các tác vụ sau đăng nhập
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              // Lấy FCM token
              final fcmToken = await NotificationController().getFirebaseToken();
              developer.log('FCM Token retrieved after login: $fcmToken', name: 'Auth');
              
              // Tiếp tục tải dữ liệu
              final locationProvider = Provider.of<LocationProvider>(context, listen: false);
              final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              final matchProvider = Provider.of<MatchProvider>(context, listen: false);
              final momentProvider = Provider.of<MomentProvider>(context, listen: false);

              // Cập nhật vị trí người dùng
              await locationProvider.updateUserLocation(snapshot.data!.uid);

              // Tải hồ sơ người dùng nếu chưa có
              if (profileProvider.userData == null) {
                await profileProvider.loadUserProfile();
              }

              // Tải cài đặt vị trí từ dữ liệu người dùng
              if (profileProvider.userData != null) {
                locationProvider.loadSettingsFromUser(profileProvider.userData!);
              }

              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId != null) {
                // Tải danh sách match và thiết lập listener cho tin nhắn và cuộc gọi
                final matches = await matchProvider.fetchMatchedUsersWithMatchId(currentUserId);
                for (var match in matches) {
                  final matchId = match['matchId'] as String;
                  final peerUser = match['user'] as UserModel;
                  chatProvider.messagesStream(matchId, peerUser).listen((_) {});
                  chatProvider.listenForIncomingCalls(matchId, peerUser);
                }

                developer.log('Starting moment reactions listener...', name: 'Auth');
                // Thiết lập listener cho moments
                await momentProvider.listenMoments(currentUserId);
                developer.log('Moment listener started', name: 'Auth');
              }
            } catch (e) {
              developer.log('Error getting FCM token: $e', name: 'Auth');
            }
          });
          
          // Kiểm tra vai trò người dùng từ Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              // Nếu đang chờ
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.deepOrange),
                        SizedBox(height: 16),
                        Text('Đang kiểm tra quyền truy cập...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }

              // Nếu có lỗi hoặc không có dữ liệu
              if (userSnapshot.hasError) {
                return LoginScreen();
              }

              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return LoginScreen();
              }

              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              
              if (userData == null) {
                return LoginScreen();
              }

              // Kiểm tra xem có phải admin không
              final isAdmin = userData['isAdmin'] ?? false;

              if (isAdmin == true) {
                developer.log('ADMIN DETECTED', name: 'Auth');
                return const AdminApp();
              }

              developer.log('Regular user detected', name: 'Auth');

              // Trả về ứng dụng người dùng thông thường
              return const UserApp();
            },
          );
        }

        // Nếu không có người dùng đăng nhập
        developer.log('No user logged in', name: 'Auth');
        return LoginScreen();
      },
    );
  }
}
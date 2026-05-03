import 'package:flutter/material.dart';
import '../../user/screens/auth/login_screen.dart';
import '../../user/user_app.dart';
import '../../user/screens/profile/edit_profile_screen.dart';
import '../../user/screens/auth/phone_login_screen.dart';
import '../../user/screens/auth/email_login_screen.dart';
import '../../admin/screens/users/admin_test_users_screen.dart';
import '../../user/screens/chat/chat_screen.dart';
import '../../user/screens/call/video_call_screen.dart';
import '../../main.dart'; // For AuthWrapper
import '../models/user_model.dart';

// Khóa navigator toàn cục
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static Map<String, WidgetBuilder> get routes => {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => const UserApp(),
        '/profile': (context) => const ProfileScreen(),
        '/phone-login': (context) => const PhoneLoginScreen(),
        '/email-login': (context) => const EmailLoginScreen(),
        '/admin-test-users': (context) => const AdminTestUsersScreen(),
        '/moments': (context) => const UserApp(initialRoute: '/main'),
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
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    if (name.startsWith('/__/auth')) {
      return MaterialPageRoute(
        builder: (_) => const SizedBox.shrink(),
        settings: const RouteSettings(name: '_firebase_auth_cb'),
      );
    }
    return null;
  }

  static Route<dynamic>? onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.orange.shade50,
        body: const Center(
          child: Text(
            'Quay lại trang trước xác nhận!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.deepOrange,
              letterSpacing: .5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

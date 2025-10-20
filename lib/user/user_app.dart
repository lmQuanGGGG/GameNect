// lib/user/user_app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/login_screen.dart';
import '../core/services/auth_service.dart';
import 'screens/home_profile_screen.dart';
import 'screens/main_screen.dart'; // Thêm import cho MainScreen
import 'screens/phone_login_screen.dart'; // Thêm import cho PhoneLoginScreen
import 'screens/email_login_screen.dart'; // Thêm import cho EmailLoginScreen
import 'screens/admin_test_users_screen.dart'; // Thêm import cho AdminTestUsersScreen
import 'screens/location_settings_screen.dart'; // Thêm import này
import 'screens/liked_me_screen.dart';
import 'screens/moment_screen.dart'; // Thêm dòng này
import 'screens/chat_screen.dart'; // Thêm dòng này
import 'screens/video_call_screen.dart'; // Thêm import này
import '../../core/providers/match_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/providers/moment_provider.dart'; // Đảm bảo đã import MomentProvider
import '../../core/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserApp extends StatelessWidget {
  final String? initialRoute;
  
  const UserApp({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        // Đảm bảo đã đăng ký MomentProvider
        ChangeNotifierProvider(create: (_) => MomentProvider()), // Đảm bảo đã đăng ký MomentProvider
        // ... các provider khác
      ],
      child: MaterialApp(
        title: 'GameNect User',
        theme: ThemeData(
          primarySwatch: Colors.deepOrange, // Đổi màu chủ đạo thành cam
          scaffoldBackgroundColor: Colors.white, // Đổi màu nền thành trắng
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Colors.deepOrange,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            elevation: 8,
          ),
        ),
        initialRoute: initialRoute ?? '/main', // Đổi route mặc định thành main
        routes: {
          '/main': (context) => const MainScreen(), // Thêm route cho MainScreen
          '/home': (context) => const HomeScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/login': (context) => const LoginScreen(),
          '/home_profile': (context) => const HomeProfileScreen(),
          '/phone-login': (context) => const PhoneLoginScreen(), // Thêm route cho PhoneLoginScreen
          '/email-login': (context) => const EmailLoginScreen(), // Thêm route cho EmailLoginScreen
          '/admin-test-users': (context) => const AdminTestUsersScreen(), // Thêm route cho AdminTestUsersScreen
          '/location-settings': (context) => const LocationSettingsScreen(), // Thêm dòng này
          '/liked-me': (context) => const LikedMeScreen(),
          '/moment': (context) => const MomentScreen(), // Thêm dòng này
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
      ),
    );
  }
}

void showIncomingCallDialog(BuildContext context, String matchId, String peerUserId) async {
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(peerUserId)
      .get();
  final peerUsername = userDoc.data()?['username'] ?? '';
  final peerAvatarUrl = userDoc.data()?['avatarUrl'] ?? '';

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
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
              child: peerAvatarUrl.isEmpty
                  ? Icon(Icons.person, size: 36)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Cuộc gọi đến từ',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              peerUsername,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.call),
                  label: const Text('Nghe'),
                  onPressed: () async {
                    // Đánh dấu đã nhận cuộc gọi
                    await Provider.of<ChatProvider>(context, listen: false).answerCall(matchId);

                    Navigator.of(context).pushNamed(
                      '/video_call',
                      arguments: {
                        'channelName': matchId,
                        'peerUserId': peerUserId,
                        'peerUsername': peerUsername,
                        'peerAvatarUrl': peerAvatarUrl,
                        'isVoiceCall': false,
                      },
                    );
                    Navigator.pop(context);
                  },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.call_end),
                  label: const Text('Từ chối'),
                  onPressed: () {
                    Navigator.pop(context);
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

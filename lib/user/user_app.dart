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
import '../../core/providers/match_provider.dart';
import '../../core/providers/chat_provider.dart';

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
        },
      ),
    );
  }
}

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

class UserApp extends StatelessWidget {
  final String? initialRoute;
  
  const UserApp({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [Provider<AuthService>(create: (_) => AuthService())],
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
        },
      ),
    );
  }
}

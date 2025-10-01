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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    Provider<AuthService>(create: (_) => AuthService(), child: GameNectApp()),
  );
}

class GameNectApp extends StatelessWidget {
  const GameNectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        
        ChangeNotifierProvider(create: (_) => EditProfileProvider()),
        // Thêm các providers khác nếu cần
      ],
      child: MaterialApp(
        title: 'GameNect',
        theme: ThemeData(primarySwatch: Colors.blue),
        initialRoute: '/',
        routes: {
          '/': (context) => AuthWrapper(),
          '/login': (context) => LoginScreen(),
          '/home': (context) => UserApp(),
          '/profile': (context) => ProfileScreen(),
          '/home_profile': (context) => const HomeProfileScreen(),
        },
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: Text('Page Not Found')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Route "${settings.name}" not found'),
                    ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                      child: Text('Go Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('vi', 'VN'), // Tiếng Việt
          Locale('en', ''), // Tiếng Anh (dự phòng)
        ],
        locale: const Locale('vi', 'VN'), // Đặt mặc định là tiếng Việt
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AuthService authService = Provider.of<AuthService>(context, listen: false);
    
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }
        
        // Check for errors
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Authentication Error'),
                  Text('${snapshot.error}'),
                  ElevatedButton(
                    onPressed: () {
                      // Retry by rebuilding the widget
                      Navigator.pushReplacementNamed(context, '/');
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        
        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          return UserApp();
        }
        
        // User is not signed in
        return LoginScreen();
      },
    );
  }
}
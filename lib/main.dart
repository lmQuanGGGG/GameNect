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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const GameNectApp());
}

class GameNectApp extends StatelessWidget {
  const GameNectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ===== SERVICES =====
        Provider<AuthService>(create: (_) => AuthService()),

        // ===== PROVIDERS =====

        // 1. LocationProvider - Tạo đầu tiên (không phụ thuộc ai)
        ChangeNotifierProvider(create: (_) => LocationProvider()),

        // 2. AuthProvider - Inject LocationProvider
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

        // 3. ProfileProvider
        ChangeNotifierProvider(create: (_) => ProfileProvider()),

        // 4. EditProfileProvider
        ChangeNotifierProvider(create: (_) => EditProfileProvider()),

        // 5. MatchProvider
        ChangeNotifierProvider(create: (_) => MatchProvider()),

        // 6. ChatProvider
        ChangeNotifierProvider(create: (_) => ChatProvider()),

        // Firestore service
        Provider(create: (_) => FirestoreService()),
      ],
      child: MaterialApp(
        title: 'GameNect',
        debugShowCheckedModeBanner: false,

        // Theme
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          useMaterial3: true,

          // AppBar theme
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
          ),

          // Card theme
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          // Button theme
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

          // Input theme
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[100],
          ),
        ),

        // Routes
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
        },
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';
          if (name.startsWith('/__/auth')) {
            // Firebase phone auth callback – chặn hiển thị
            return MaterialPageRoute(
              builder: (_) => const SizedBox.shrink(),
              settings: const RouteSettings(name: '_firebase_auth_cb'),
            );
          }
          return null;
        },
        // Unknown route handler
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

        // Localization
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('vi', 'VN'), // Tiếng Việt
          Locale('en', 'US'), // Tiếng Anh
        ],
        locale: const Locale('vi', 'VN'), // Mặc định tiếng Việt
      ),
    );
  }
}

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
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo hoặc icon
                  Icon(Icons.games, size: 80, color: Colors.deepOrange),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.deepOrange),
                  const SizedBox(height: 16),
                  const Text(
                    'Đang khởi động...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        // Error state
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
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/');
                      },
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

        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final locationProvider = Provider.of<LocationProvider>(context, listen: false);
            final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

            // Cập nhật vị trí
            await locationProvider.updateUserLocation(snapshot.data!.uid);

            // Lấy user từ Firestore nếu chưa có
            if (profileProvider.userData == null) {
              await profileProvider.loadUserProfile(); // KHÔNG cần truyền uid
            }

            // Load location settings từ user vào LocationProvider
            if (profileProvider.userData != null) {
              locationProvider.loadSettingsFromUser(profileProvider.userData!);
            }
          });

          return const UserApp();
        }

        // User is not signed in
        return LoginScreen();
      },
    );
  }
}

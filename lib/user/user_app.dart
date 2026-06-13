// lib/user/user_app.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'screens/matching/home_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/auth/login_screen.dart';
import '../core/services/auth_service.dart';
import 'screens/main/main_screen.dart'; 
import 'screens/auth/phone_login_screen.dart'; 
import 'screens/auth/email_login_screen.dart'; 
import '../../admin/screens/users/admin_test_users_screen.dart'; 
import 'screens/settings/location_settings_screen.dart'; 
import 'screens/matching/liked_me_screen.dart';
import 'screens/moments/moment_screen.dart';
import 'screens/chat/chat_screen.dart'; 
import 'screens/call/video_call_screen.dart'; 
import '../core/providers/theme_provider.dart';
import '../core/theme/app_theme.dart';
import '../../core/providers/match_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/providers/moment_provider.dart'; 
import '../../core/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/live/live_discover_screen.dart';
import 'screens/mentor/mentor_profile_screen.dart';
import 'screens/live/live_stream_screen.dart';
import 'screens/live/go_live_screen.dart';
import 'screens/mentor/mentor_apply_screen.dart';
import 'screens/mentor/mentor_requests_screen.dart';
import 'screens/wallet/wallet_screen.dart';

/// Widget gốc cho phần User của ứng dụng.
/// - Thiết lập các provider cần thiết (AuthService, MatchProvider, ChatProvider, MomentProvider)
/// - Cấu hình MaterialApp với theme và routes
class UserApp extends StatelessWidget {
  // initialRoute cho phép khởi tạo ứng dụng với route mong muốn khi tạo UserApp
  final String? initialRoute;
  final int? initialIndex;
  
  const UserApp({super.key, this.initialRoute, this.initialIndex});

  @override
  Widget build(BuildContext context) {
    // MultiProvider để đăng ký các provider cho toàn bộ cây widget con
    // Provider/AuthService: cung cấp dịch vụ xác thực
    // ChangeNotifierProvider cho các provider quản lý trạng thái ứng dụng (match, chat, moment)
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        // Đảm bảo đã đăng ký MomentProvider
        ChangeNotifierProvider(create: (_) => MomentProvider()), // Đảm bảo đã đăng ký MomentProvider
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'GameNect',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                  statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                  systemNavigationBarColor: isDark ? Colors.black : Colors.white,
                  systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            initialRoute: initialRoute ?? '/main',
            routes: {
          '/main': (context) => MainScreen(initialIndex: initialIndex ?? 0), // Thêm route cho MainScreen
          '/home': (context) => const HomeScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/login': (context) => const LoginScreen(),
          '/phone-login': (context) => const PhoneLoginScreen(), // Thêm route cho PhoneLoginScreen
          '/email-login': (context) => const EmailLoginScreen(), // Thêm route cho EmailLoginScreen
          '/admin-test-users': (context) => const AdminTestUsersScreen(), // Thêm route cho AdminTestUsersScreen
          '/location-settings': (context) => const LocationSettingsScreen(), // Thêm dòng này
          '/liked-me': (context) => const LikedMeScreen(),
          '/moment': (context) => const MomentScreen(), // Thêm dòng này
          '/chat': (context) {
            // Lấy đối số route đang được truyền khi gọi Navigator.pushNamed(..., arguments: {...})
            final args = ModalRoute.of(context)!.settings.arguments as Map;
            return ChatScreen(
              matchId: args['matchId'] as String,
              peerUser: args['peerUser'] as UserModel,
            );
          },
          // Route '/video_call' mong đợi arguments chứa thông tin kênh và thông tin người gọi
          '/video_call': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map;
            return VideoCallScreen(
              channelName: args['channelName'] as String,
              peerUserId: args['peerUserId'] as String,
              peerUsername: args['peerUsername'] as String,
              peerAvatarUrl: args['peerAvatarUrl'] as String?,
              // isVoiceCall có thể null, nếu null thì mặc định false (cuộc gọi video)
              isVoiceCall: args['isVoiceCall'] as bool? ?? false,
            );
          },
          '/mentor-apply': (ctx) => const MentorApplyScreen(),
          '/live-discover': (ctx) => const LiveDiscoverScreen(),
          '/go-live': (ctx) => const GoLiveScreen(),
          '/mentor-requests': (ctx) => const MentorRequestsScreen(),
          '/mentor-profile': (ctx) {
            final args = ModalRoute.of(ctx)!.settings.arguments as Map?;
            return MentorProfileScreen(
              mentorId: args?['mentorId'] as String? ?? '',
            );
          },
          '/live-stream': (ctx) {
            final args = ModalRoute.of(ctx)!.settings.arguments as Map?;
            return LiveStreamScreen(
              streamId: args?['streamId'] as String? ?? '',
              isMentor: args?['isMentor'] as bool? ?? false,
            );
          },
          '/wallet': (ctx) => const WalletScreen(),
        },
      );
    },
  ),
);
  }
}

/// Hiển thị dialog khi có cuộc gọi đến.
/// Hàm thực hiện:
/// 1. Truy vấn Firestore để lấy thông tin người gọi (username, avatarUrl)
/// 2. Hiển thị Dialog không cho dismiss bằng cách bấm ngoài (barrierDismissible: false)
/// 3. Nếu người dùng bấm "Nghe":
///    - Gọi method answerCall trên ChatProvider để đánh dấu đã nhận cuộc gọi
///    - Điều hướng sang route '/video_call' truyền các arguments cần thiết
/// 4. Nếu người dùng bấm "Từ chối":
///    - Đóng dialog, không làm gì thêm (có thể mở rộng để thông báo từ chối lên server)
void showIncomingCallDialog(BuildContext context, String matchId, String peerUserId) async {
  // Lấy document của peerUser từ collection 'users'
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(peerUserId)
      .get();

  // Nếu không có dữ liệu thì trả về chuỗi rỗng để tránh lỗi
  final peerUsername = userDoc.data()?['username'] ?? '';
  final peerAvatarUrl = userDoc.data()?['avatarUrl'] ?? '';

  // Hiển thị dialog cuộc gọi đến
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black, width: 4),
      ),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar người gọi: nếu có avatarUrl thì hiển thị NetworkImage, nếu không thì hiển thị icon mặc định
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                backgroundImage: peerAvatarUrl.isNotEmpty
                  ? NetworkImage(peerAvatarUrl)
                  : null,
              child: peerAvatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 36, color: Colors.black)
                  : null,
              ),
            ),
            const SizedBox(height: 16),
            // Tiêu đề nhỏ mô tả đây là cuộc gọi đến
            Text(
              'Cuộc gọi đến từ',
              style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            // Tên người gọi được hiển thị lớn hơn và nổi bật màu chủ đạo
            Text(
              peerUsername,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            // Hai nút hành động: Nghe và Từ chối
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Nút "Nghe"
                Container(
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.call, color: Colors.black),
                    label: const Text('Nghe', style: TextStyle(fontWeight: FontWeight.w900)),
                  onPressed: () async {
                    // Khi chấp nhận cuộc gọi:
                    // Gọi phương thức answerCall trên ChatProvider để xử lý logic nhận cuộc gọi
                    await Provider.of<ChatProvider>(context, listen: false).answerCall(matchId);

                    // Điều hướng sang màn hình video call, truyền các tham số cần thiết
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
                    // Đóng dialog sau khi đã điều hướng
                    Navigator.pop(context);
                  },
                ),
                ),
                // Nút "Từ chối"
                Container(
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.call_end, color: Colors.black),
                    label: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.w900)),
                  onPressed: () {
                    // Đóng dialog, không thực hiện hành động nào thêm
                    Navigator.pop(context);
                  },
                ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// lib/user/user_app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/login_screen.dart';
import '../core/services/auth_service.dart';
import 'screens/main_screen.dart'; 
import 'screens/phone_login_screen.dart'; 
import 'screens/email_login_screen.dart'; 
import 'screens/admin_test_users_screen.dart'; 
import 'screens/location_settings_screen.dart'; 
import 'screens/liked_me_screen.dart';
import 'screens/moment_screen.dart';
import 'screens/chat_screen.dart'; 
import 'screens/video_call_screen.dart'; 
import '../../core/providers/match_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/providers/moment_provider.dart'; 
import '../../core/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Widget gốc cho phần User của ứng dụng.
/// - Thiết lập các provider cần thiết (AuthService, MatchProvider, ChatProvider, MomentProvider)
/// - Cấu hình MaterialApp với theme và routes
class UserApp extends StatelessWidget {
  // initialRoute cho phép khởi tạo ứng dụng với route mong muốn khi tạo UserApp
  final String? initialRoute;
  
  const UserApp({super.key, this.initialRoute});

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar người gọi: nếu có avatarUrl thì hiển thị NetworkImage, nếu không thì hiển thị icon mặc định
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
            // Tiêu đề nhỏ mô tả đây là cuộc gọi đến
            Text(
              'Cuộc gọi đến từ',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            // Tên người gọi được hiển thị lớn hơn và nổi bật màu chủ đạo
            Text(
              peerUsername,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 24),
            // Hai nút hành động: Nghe và Từ chối
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Nút "Nghe"
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
                // Nút "Từ chối"
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
                    // Đóng dialog, không thực hiện hành động nào thêm
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

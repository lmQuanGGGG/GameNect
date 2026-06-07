import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../user/screens/auth/login_screen.dart';
import '../../user/user_app.dart';
import '../../user/screens/profile/edit_profile_screen.dart';
import '../../user/screens/auth/phone_login_screen.dart';
import '../../user/screens/auth/email_login_screen.dart';
import '../../admin/screens/users/admin_test_users_screen.dart';
import '../../user/screens/chat/chat_screen.dart';
import '../../user/screens/call/video_call_screen.dart';
import '../../user/screens/live_swipe_feed_screen.dart';
import '../../user/screens/live_stream_screen.dart';
import '../../user/screens/wallet/wallet_screen.dart';
import '../../core/models/livestream_model.dart';
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
        '/wallet': (context) => const WalletScreen(),
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

    // /live-stream: mở TikTok-style feed tại đúng stream
    if (name == '/live-stream') {
      final args = settings.arguments as Map? ?? {};
      final streamId = args['streamId'] as String? ?? '';
      final isMentor = args['isMentor'] as bool? ?? false;

      // Mentor vẫn mở LiveStreamScreen truyền thống (vì cần camera preview)
      if (isMentor) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) {
            // lazy import để tránh circular
            return _MentorLiveScreenWrapper(streamId: streamId);
          },
        );
      }

      // Viewer: load stream từ Firestore rồi mở feed
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => _ViewerFeedLauncher(streamId: streamId),
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

// ── Viewer: load stream từ Firestore → mở LiveSwipeFeedScreen ──────────────

class _ViewerFeedLauncher extends StatelessWidget {
  final String streamId;
  const _ViewerFeedLauncher({required this.streamId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('livestreams').doc(streamId).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6E40))),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: Text('Stream không tồn tại', style: TextStyle(color: Colors.white))),
          );
        }
        final stream = LivestreamModel.fromMap(
          snap.data!.data() as Map<String, dynamic>,
          snap.data!.id,
        );
        return LiveSwipeFeedScreen(
          streams: [stream],
          initialIndex: 0,
        );
      },
    );
  }
}



// ── Mentor: wrapper để tránh circular import với LiveStreamScreen ──────────

class _MentorLiveScreenWrapper extends StatelessWidget {
  final String streamId;
  const _MentorLiveScreenWrapper({required this.streamId});

  @override
  Widget build(BuildContext context) {
    return LiveStreamScreen(streamId: streamId, isMentor: true);
  }
}


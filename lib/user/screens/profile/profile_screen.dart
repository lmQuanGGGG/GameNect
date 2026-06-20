import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/widgets/network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';
import '../settings/location_settings_screen.dart';
import '../../../admin/admin_app.dart';
import 'package:logging/logging.dart';
import '../premium/subscription_screen.dart';
import '../../widgets/tab_bar_visibility.dart';
import '../shared/peer_profile_screen.dart';
import '../../../core/theme/theme_helper.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../core/controllers/notification_controller.dart';
import '../../../core/providers/mentor_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/web_page_visibility.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../wallet/wallet_screen.dart';

// Màn hình hồ sơ cá nhân của user
// Hiển thị avatar, thông tin cá nhân, game yêu thích, thống kê
// Cho phép chỉnh sửa profile, cài đặt vị trí matching và nâng cấp Premium
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  final Logger _logger = Logger('ProfilePage');
  DateTime? _lastProfileRefreshAt;

  Future<void> _refreshProfileState({bool force = false}) async {
    if (!mounted) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      context.read<ProfileProvider>().clearUserProfile();
      context.read<MentorProvider>().clearMyMentorProfile();
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastProfileRefreshAt != null &&
        now.difference(_lastProfileRefreshAt!) < const Duration(seconds: 8)) {
      return;
    }
    _lastProfileRefreshAt = now;

    final profileProvider = context.read<ProfileProvider>();
    final mentorProvider = context.read<MentorProvider>();
    await Future.wait([
      profileProvider.loadUserProfile(forceRefresh: force),
      mentorProvider.loadMyMentorProfile(userId, forceRefresh: force),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProfileState(force: true);
    }
  }

  // Widget hiển thị card quảng cáo Premium cho user Free
  // Liệt kê các tính năng Premium và nút nâng cấp
  Widget _buildPremiumPromoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: context.isDarkMode ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.textColor, width: 2.5),
        boxShadow: [
          BoxShadow(color: context.textColor, offset: const Offset(6, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nâng cấp Premium',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 8),
          _featureRow('Xem ai đã thích bạn'),
          const SizedBox(height: 6),
          _featureRow('Đăng khoảnh khắc không giới hạn'),
          const SizedBox(height: 6),
          _featureRow('Hoàn tác lượt vuốt, super like tăng khả năng kết nối'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.textColor,
                foregroundColor: context.scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Nâng cấp ngay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: context.scaffoldBackgroundColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị một tính năng Premium với icon check
  Widget _featureRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, size: 18, color: Color(0xFFFF6E40)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: context.textSecondaryColor),
          ),
        ),
      ],
    );
  }

  // Widget ví coin — kiểu credit card premium, hoạt động tốt cả nền sáng lẫn tối
  Widget _buildWalletCard(UserModel user) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WalletScreen()),
      ),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF9B51E0), // Solid bold purple
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.textColor, width: 2.5),
          boxShadow: [
            BoxShadow(color: context.textColor, offset: const Offset(6, 6)),
          ],
        ),
        child: Stack(
          children: [
            // Vòng trang trí nền
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Nội dung
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Icon coin
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.monetization_on_rounded,
                      color: Colors.amber,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Số dư
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Ví GameNect',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${user.coinBalance} Coin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Nút quản lý
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.textColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: context.textColor,
                          offset: const Offset(3, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      'Quản lý',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Admin Section — kiểu credit card, chỉ hiện với admin
  Widget _buildAdminSection(UserModel user) {
    if (!user.isAdmin) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => AdminApp(onBack: () => Navigator.of(ctx).pop()),
          ),
        );
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF2E1508), Color(0xFF662200)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF662200).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Vòng trang trí nền
            Positioned(
              right: -15,
              top: -25,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              right: 50,
              bottom: -25,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.03),
                ),
              ),
            ),
            // Nội dung
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.orangeAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Text
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Quản trị hệ thống',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Nút vào
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.dialogBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.textColor, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: context.textColor,
                          offset: const Offset(6, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      'Mở',
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Mentor Section — hiển thị trạng thái Mentor của user
  Widget _buildMentorSection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return Consumer<MentorProvider>(
      builder: (context, mentorProvider, _) {
        final mentor = mentorProvider.myMentorProfile;
        final status = mentor?.status ?? 'none';

        if (status == 'approved') {
          // Đã là Mentor → Dashboard card
          return Container(
            decoration: BoxDecoration(
              color: context.dialogBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.textColor, width: 2.5),
              boxShadow: [
                BoxShadow(color: context.textColor, offset: const Offset(6, 6)),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header - tap to view own mentor profile
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/mentor-profile',
                    arguments: {'mentorId': mentor!.userId},
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.school_rounded,
                        color: Color(0xFFFF6E40),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mentor Dashboard',
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.dialogBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.textColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.textColor,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.person_crop_circle,
                              color: Color(0xFFFF6E40),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Xem profile',
                              style: TextStyle(
                                color: Color(0xFFFF6E40),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Stats row - Followers is tappable
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _mentorStat(
                      Icons.live_tv_rounded,
                      '${mentor!.totalStreams}',
                      'Streams',
                      onTap: null,
                    ),
                    GestureDetector(
                      onTap: () => _showFollowerList(mentor.userId),
                      behavior: HitTestBehavior.opaque,
                      child: _mentorStat(
                        Icons.people_alt_rounded,
                        '${mentor.followerCount}',
                        'Followers',
                        onTap: null,
                      ),
                    ),
                    _mentorStat(
                      Icons.card_giftcard_rounded,
                      '${mentor.totalGiftsReceived}',
                      'Gifts',
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildNeoButton(
                        onTap: () =>
                            Navigator.pushNamed(context, '/mentor-requests'),
                        icon: const Icon(
                          Icons.sports_esports,
                          size: 16,
                          color: Color(0xFFFF6E40),
                        ),
                        label: 'Match Requests',
                        backgroundColor: context.dialogBgColor,
                        foregroundColor: const Color(0xFFFF6E40),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNeoButton(
                        onTap: () => Navigator.pushNamed(context, '/go-live'),
                        icon: const Icon(
                          Icons.live_tv_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: 'Go Live',
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        if (status == 'pending') {
          // Đang chờ duyệt
          return Container(
            decoration: BoxDecoration(
              color: context.dialogBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.textColor, width: 2.5),
              boxShadow: [
                BoxShadow(color: context.textColor, offset: const Offset(6, 6)),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.amber,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đơn đăng ký Mentor đang chờ duyệt',
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Admin sẽ phản hồi sớm nhất có thể',
                        style: TextStyle(
                          color: context.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // none hoặc rejected → card mời đăng ký
        return Container(
          decoration: BoxDecoration(
            color: context.dialogBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.textColor, width: 2.5),
            boxShadow: [
              BoxShadow(color: context.textColor, offset: const Offset(6, 6)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(
                Icons.school_rounded,
                color: Color(0xFFFF6E40),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trở thành Mentor',
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      status == 'rejected'
                          ? 'Đơn bị từ chối. Có thể gửi lại đơn mới.'
                          : 'Hướng dẫn gaming, livestream & nhận gift',
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/mentor-apply'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6E40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.textColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: context.textColor,
                        offset: const Offset(3, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Đăng ký',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mentorStat(
    IconData iconData,
    String value,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(iconData, size: 24, color: const Color(0xFFFF6E40)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: onTap != null
                  ? const Color(0xFFFF6E40)
                  : context.textTertiaryColor,
              fontSize: 11,
              decoration: onTap != null
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeoButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ?? (isDark ? Colors.black : Colors.white);
    final fgColor = foregroundColor ?? (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.textColor, width: 2.5),
          boxShadow: [
            BoxShadow(color: context.textColor, offset: const Offset(3, 3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFollowerList(String mentorId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FollowerListSheet(mentorId: mentorId),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load lại profile/quyền khi mở màn, đặc biệt cần cho web/PWA sau khi resume.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfileState(force: true);
    });
    if (kIsWeb) {
      WebPageVisibilityService.start(() => _refreshProfileState(force: true));
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WebPageVisibilityService.stop();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Hàm test để request quyền location và lấy vị trí hiện tại
  // Cập nhật vị trí vào Firestore sau khi lấy thành công
  Future<void> _testLocationPermission() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    _logger.info('Test: Bắt đầu request location permission...');

    // Request quyền truy cập vị trí
    final hasPermission = await locationProvider.requestLocationPermission();

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn cần cấp quyền truy cập vị trí'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _logger.info('Test: Đã có permission, đang lấy vị trí...');

    // Lấy vị trí hiện tại
    final success = await locationProvider.getCurrentLocation();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vị trí hiện tại: ${locationProvider.currentLocation ?? "Không xác định"}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Cập nhật vị trí lên Firestore và tự động lưu cài đặt match
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await locationProvider.updateUserLocation(user.uid);
          await locationProvider.saveSettings(user.uid); // Tự động lưu settings
          if (mounted) {
            await context.read<ProfileProvider>().loadUserProfile(forceRefresh: true);
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi: ${locationProvider.error ?? "Không thể lấy vị trí"}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final authService = context.read<AuthService>();
    final navigator = Navigator.of(context);
    final profileProvider = context.read<ProfileProvider>();
    final mentorProvider = context.read<MentorProvider>();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.dialogBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Đăng xuất',
          style: TextStyle(color: context.textDialogColor),
        ),
        content: Text(
          'Bạn có chắc muốn đăng xuất?',
          style: TextStyle(color: context.textDialogSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Hủy',
              style: TextStyle(color: context.textTertiaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF3B30),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      if (!context.mounted) return;
      profileProvider.clearUserProfile();
      mentorProvider.clearMyMentorProfile();
      await authService.signOut();
      if (!context.mounted) return;
      navigator.pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final isPremium = provider.userData?.isPremium ?? false;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: context.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 60,
            titleSpacing: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                color: context.scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: context.isDarkMode ? Colors.white24 : Colors.black12,
                    width: 1,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12.0),
                  child: Icon(
                    Icons.sports_esports,
                    color: Color(0xFFFF6E40),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'gamenect',
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFFF6E40).withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Hiển thị badge Premium hoặc nút Nâng cấp
              Consumer<ProfileProvider>(
                builder: (context, provider, _) {
                  final isPremium = provider.userData?.isPremium == true;
                  if (isPremium) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: context.textColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.textColor,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.textColor,
                                offset: const Offset(4, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.workspace_premium_rounded,
                                color: Color(0xFFFF6E40),
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Premium',
                                style: TextStyle(
                                  color: context.scaffoldBackgroundColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    return TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFFF6E40),
                        size: 20,
                      ),
                      label: Text(
                        'Nâng cấp',
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          // Body hiển thị loading, empty state hoặc profile content
          body: Stack(
            children: [
              SafeArea(
                child: provider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6E40),
                        ),
                      )
                    : provider.userData == null
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: const Color(0xFFFF6E40),
                        backgroundColor: const Color(0xFF1A1A1E),
                        displacement: 20,
                        onRefresh: () async {
                          await _refreshProfileState(force: true);
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            try {
                              TabBarVisibility.of(context).update(n);
                            } catch (_) {}
                            return false;
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Trên web rộng, căn giữa và giới hạn chiều rộng tối đa
                              final isWide =
                                  kIsWeb && constraints.maxWidth > 700;

                              Widget content = SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        top: 24,
                                        bottom: 8,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          // Avatar
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PeerProfileScreen(
                                                        peerUser:
                                                            provider.userData!,
                                                      ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              height: 100,
                                              width: 100,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: context.textColor,
                                                  width: 3,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: context.textColor,
                                                    offset: const Offset(6, 6),
                                                  ),
                                                ],
                                                color: context.cardBgColor,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                                child: GamenectNetworkImage(
                                                  imageUrl:
                                                      provider
                                                          .userData!
                                                          .avatarUrl ??
                                                      '',
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                        color:
                                                            context.cardBgColor,
                                                      ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          const Icon(
                                                            Icons.person,
                                                            size: 40,
                                                          ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          // Thông tin và nút Edit
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        provider
                                                            .userData!
                                                            .username,
                                                        style: TextStyle(
                                                          fontSize: 28,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color:
                                                              context.textColor,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                OutlinedButton.icon(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            const ProfileScreen(),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    CupertinoIcons.pencil,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    'Chỉnh sửa',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        context.textColor,
                                                    side: BorderSide(
                                                      color: context.textColor,
                                                      width: 2,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 16),
                                          // ─── Wallet Card ───────────────────────────────
                                          if (provider.userData != null)
                                            _buildWalletCard(
                                              provider.userData!,
                                            ),
                                          const SizedBox(height: 16),
                                          // ─── Mentor Section ────────────────────────────
                                          _buildMentorSection(),
                                          const SizedBox(height: 16),

                                          // Card hiển thị vị trí và cài đặt matching
                                          Consumer<LocationProvider>(
                                            builder: (context, locationProvider, child) {
                                              return Container(
                                                decoration: BoxDecoration(
                                                  color: context.dialogBgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: context.textColor,
                                                    width: 2.5,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: context.textColor,
                                                      offset: const Offset(
                                                        6,
                                                        6,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          CupertinoIcons
                                                              .location_solid,
                                                          color: Color(
                                                            0xFFFF6E40,
                                                          ),
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          'Vị trí & Khoảng cách',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: context
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),

                                                    // Hiển thị vị trí hiện tại
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Vị trí hiện tại:',
                                                          style: TextStyle(
                                                            color: context
                                                                .textTertiaryColor,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          locationProvider
                                                                  .currentLocation ??
                                                              'Chưa cập nhật',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 14,
                                                            color: context
                                                                .textColor,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),

                                                    // Hiển thị khoảng cách tìm kiếm
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Khoảng cách tìm kiếm:',
                                                          style: TextStyle(
                                                            color: context
                                                                .textTertiaryColor,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${locationProvider.maxDistance.toInt()} km',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                  0xFFFF6E40,
                                                                ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),

                                                    // Hiển thị độ tuổi tìm kiếm
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Độ tuổi:',
                                                          style: TextStyle(
                                                            color: context
                                                                .textTertiaryColor,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${locationProvider.minAge} - ${locationProvider.maxAge} tuổi',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                  0xFFFF6E40,
                                                                ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 16),

                                                    // 2 nút: Lấy vị trí và Cài đặt match
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: _buildNeoButton(
                                                            onTap:
                                                                _testLocationPermission,
                                                            icon:
                                                                locationProvider
                                                                    .isLoading
                                                                ? const SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                      color: Color(
                                                                        0xFFFF6E40,
                                                                      ),
                                                                    ),
                                                                  )
                                                                : const Icon(
                                                                    CupertinoIcons
                                                                        .refresh,
                                                                    size: 18,
                                                                    color: Color(
                                                                      0xFFFF6E40,
                                                                    ),
                                                                  ),
                                                            label:
                                                                locationProvider
                                                                    .isLoading
                                                                ? 'Đang lấy...'
                                                                : 'Lấy vị trí',
                                                            backgroundColor:
                                                                context
                                                                    .dialogBgColor,
                                                            foregroundColor:
                                                                const Color(
                                                                  0xFFFF6E40,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: _buildNeoButton(
                                                            onTap: () {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (
                                                                        context,
                                                                      ) =>
                                                                          const LocationSettingsScreen(),
                                                                ),
                                                              );
                                                            },
                                                            icon: const Icon(
                                                              CupertinoIcons
                                                                  .settings,
                                                              size: 18,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            label:
                                                                'Cài đặt match',
                                                            backgroundColor:
                                                                const Color(
                                                                  0xFFFF6E40,
                                                                ),
                                                            foregroundColor:
                                                                Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),

                                          const SizedBox(height: 16),

                                          // ─── Admin Section ────────────────────────────
                                          if (provider.userData != null)
                                            _buildAdminSection(
                                              provider.userData!,
                                            ),

                                          if (provider.userData?.isAdmin ??
                                              false)
                                            const SizedBox(height: 16),

                                          // Card cài đặt giao diện
                                          Consumer<ThemeProvider>(
                                            builder: (context, themeProvider, child) {
                                              return GestureDetector(
                                                onTap: () =>
                                                    themeProvider.toggleTheme(),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color:
                                                        context.dialogBgColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: context.textColor,
                                                      width: 2.5,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color:
                                                            context.textColor,
                                                        offset: const Offset(
                                                          6,
                                                          6,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 12,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        themeProvider
                                                                .isSystemMode
                                                            ? Icons
                                                                  .brightness_auto_rounded
                                                            : themeProvider
                                                                  .isDarkMode
                                                            ? CupertinoIcons
                                                                  .moon_stars_fill
                                                            : CupertinoIcons
                                                                  .sun_max_fill,
                                                        color: const Color(
                                                          0xFFFF6E40,
                                                        ),
                                                        size: 22,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Giao diện',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: context
                                                                    .textColor,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              themeProvider
                                                                      .isSystemMode
                                                                  ? 'Theo hệ thống → nhấn để đổi'
                                                                  : themeProvider
                                                                        .isDarkMode
                                                                  ? 'Giao diện tối → nhấn để đổi'
                                                                  : 'Giao diện sáng → nhấn để đổi',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: context
                                                                    .textTertiaryColor,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Hiện badge trạng thái
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFFF6E40,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          border: Border.all(
                                                            color: context
                                                                .textColor,
                                                            width: 1.5,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          themeProvider
                                                                  .isSystemMode
                                                              ? 'Auto'
                                                              : themeProvider
                                                                    .isDarkMode
                                                              ? 'Tối'
                                                              : 'Sáng',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),

                                          // Hiển thị card quảng cáo Premium nếu chưa Premium
                                          if (!isPremium) ...[
                                            const SizedBox(height: 8),
                                            _buildPremiumPromoCard(),
                                            const SizedBox(height: 16),
                                          ],

                                          // Nút Bật thông báo Web
                                          if (kIsWeb)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 16,
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: context.dialogBgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: context.textColor,
                                                    width: 2.5,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: context.textColor,
                                                      offset: const Offset(
                                                        6,
                                                        6,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      CupertinoIcons.bell_solid,
                                                      color: Color(0xFFFF6E40),
                                                      size: 22,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Thông báo Web',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: context
                                                                  .textColor,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            'Bật thông báo trên trình duyệt',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: context
                                                                  .textTertiaryColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        try {
                                                          final messaging =
                                                              FirebaseMessaging
                                                                  .instance;
                                                          final settings =
                                                              await messaging
                                                                  .requestPermission();
                                                          if (settings
                                                                  .authorizationStatus ==
                                                              AuthorizationStatus
                                                                  .authorized) {
                                                            final token =
                                                                await NotificationController()
                                                                    .getFirebaseToken();
                                                            if (context
                                                                .mounted) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    token !=
                                                                            null
                                                                        ? 'Đã bật thông báo thành công!'
                                                                        : 'Có lỗi khi lấy token',
                                                                  ),
                                                                  backgroundColor:
                                                                      token !=
                                                                          null
                                                                      ? Colors
                                                                            .green
                                                                      : Colors
                                                                            .red,
                                                                ),
                                                              );
                                                            }
                                                          } else {
                                                            if (context
                                                                .mounted) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    'Chưa cấp quyền thông báo',
                                                                  ),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        } catch (e) {
                                                          _logger.severe(
                                                            'Lỗi thông báo web: $e',
                                                          );
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'Lỗi: $e',
                                                                ),
                                                                backgroundColor:
                                                                    Colors.red,
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFFFF6E40,
                                                            ),
                                                        foregroundColor:
                                                            Colors.white,
                                                        elevation: 0,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 10,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                      ),
                                                      child: const Text('Bật'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: GestureDetector(
                                        onTap: _handleLogout,
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF3B30),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: context.textColor,
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: context.textColor,
                                                offset: const Offset(5, 5),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              Icon(
                                                CupertinoIcons
                                                    .square_arrow_right,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Đăng xuất',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 32),
                                  ],
                                ),
                              );
                              // Trên web rộng: căn giữa + giới hạn max-width
                              if (isWide) {
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 800,
                                    ),
                                    child: content,
                                  ),
                                );
                              }
                              return content;
                            },
                          ),
                        ),
                      ), // đóng NotificationListener
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget hiển thị empty state khi chưa có profile
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.person_circle,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có thông tin hồ sơ',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Mở màn hình tạo profile
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Tạo hồ sơ'),
          ),
        ],
      ),
    );
  }

  // Widget helper để tạo một section với title và content

  // Widget helper để hiển thị một dòng thống kê (label - value)
}

// ── Follower List Bottom Sheet ──────────────────────────────────────────────
class _FollowerListSheet extends StatefulWidget {
  final String mentorId;
  const _FollowerListSheet({required this.mentorId});

  @override
  State<_FollowerListSheet> createState() => _FollowerListSheetState();
}

class _FollowerListSheetState extends State<_FollowerListSheet> {
  late final Stream<QuerySnapshot> _followersStream;
  final Map<String, Future<DocumentSnapshot>> _userFutures = {};

  @override
  void initState() {
    super.initState();
    _followersStream = FirebaseFirestore.instance
        .collection('mentor_followers')
        .where('mentorId', isEqualTo: widget.mentorId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.person_2_fill,
                      color: Color(0xFFFF6E40),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Người theo dõi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Follower list from Firestore
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _followersStream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6E40),
                        ),
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    final sorted = [...docs];
                    sorted.sort((a, b) {
                      final aT =
                          (a.data() as Map<String, dynamic>)['followedAt'];
                      final bT =
                          (b.data() as Map<String, dynamic>)['followedAt'];
                      if (aT == null && bT == null) return 0;
                      if (aT == null) return 1;
                      if (bT == null) return -1;
                      return (bT as Timestamp).compareTo(aT as Timestamp);
                    });
                    if (sorted.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.person_badge_plus,
                              size: 48,
                              color: Colors.grey.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Chưa có người theo dõi',
                              style: TextStyle(
                                color: Colors.grey.withValues(alpha: 0.6),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollCtrl,
                      itemCount: sorted.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, i) {
                        final d = sorted[i].data() as Map<String, dynamic>;
                        final followerId = d['followerId'] as String? ?? '';
                        final future = _userFutures.putIfAbsent(
                          followerId,
                          () => FirebaseFirestore.instance
                              .collection('users')
                              .doc(followerId)
                              .get(),
                        );
                        return FutureBuilder<DocumentSnapshot>(
                          future: future,
                          builder: (ctx, userSnap) {
                            final userData =
                                userSnap.data?.data() as Map<String, dynamic>?;
                            final name =
                                userData?['username'] as String? ??
                                userData?['displayName'] as String? ??
                                'Người dùng';
                            final avatar =
                                userData?['avatarUrl'] as String? ?? '';
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(
                                  0xFFFF6E40,
                                ).withValues(alpha: 0.15),
                                child: avatar.isNotEmpty
                                    ? ClipOval(
                                        child: GamenectNetworkImage(
                                          imageUrl: avatar,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        CupertinoIcons.person_solid,
                                        color: Color(0xFFFF6E40),
                                        size: 22,
                                      ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: const Icon(
                                CupertinoIcons.chevron_forward,
                                size: 14,
                                color: Colors.grey,
                              ),
                              onTap:
                                  (followerId.isNotEmpty &&
                                      userSnap.hasData &&
                                      userData != null)
                                  ? () {
                                      final userModel = UserModel.fromMap(
                                        userData,
                                        followerId,
                                      );
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PeerProfileScreen(
                                            peerUser: userModel,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

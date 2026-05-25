import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gamenect_new/core/widgets/profile_card.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';
import '../settings/location_settings_screen.dart';
import 'package:logging/logging.dart';
import 'dart:ui';
import '../premium/subscription_screen.dart';
import '../../widgets/tab_bar_visibility.dart';
import '../shared/peer_profile_screen.dart';
import '../../../core/theme/theme_helper.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../core/controllers/notification_controller.dart';

// Màn hình hồ sơ cá nhân của user
// Hiển thị avatar, thông tin cá nhân, game yêu thích, thống kê
// Cho phép chỉnh sửa profile, cài đặt vị trí matching và nâng cấp Premium
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Logger _logger = Logger('ProfilePage');
  
  // Widget hiển thị card quảng cáo Premium cho user Free
  // Liệt kê các tính năng Premium và nút nâng cấp
  Widget _buildPremiumPromoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6E40).withValues(alpha: 0.15),
            const Color(0xFFFF8A65).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6E40).withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nâng cấp Premium',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
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
                // Mở màn hình đăng ký Premium
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6E40),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Nâng cấp ngay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    // Load thông tin profile sau khi build frame đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadUserProfile();
    });
  }

  // Hàm test để request quyền location và lấy vị trí hiện tại
  // Cập nhật vị trí vào Firestore sau khi lấy thành công
  Future<void> _testLocationPermission() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
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
        
        // Cập nhật vị trí lên Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await locationProvider.updateUserLocation(user.uid);
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
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.dialogBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Đăng xuất', style: TextStyle(color: context.textDialogColor)),
        content: Text('Bạn có chắc muốn đăng xuất?', style: TextStyle(color: context.textDialogSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: context.textTertiaryColor)),
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
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
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
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: context.appBarBgColor,
                ),
              ),
            ),
            // Logo và tên app ở góc trên
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
                    shadows: [Shadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.5), blurRadius: 12)],
                  ),
                ),
              ],
            ),
            actions: [
              // Hiển thị badge Premium hoặc nút Nâng cấp
              if (isPremium)
                // Badge Premium với gradient vàng cam
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber, Colors.orange.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                // Nút Nâng cấp cho user Free
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                  },
                  icon: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFF6E40),
                    size: 20,
                  ),
                  label: const Text(
                    'Nâng cấp',
                    style: TextStyle(
                      color: Color(0xFFFF6E40),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
            ],
          ),

          // Body hiển thị loading, empty state hoặc profile content
          body: Stack(
            children: [
              // Background Orbs
              Positioned(
                top: 50, right: -50,
                child: Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF6E40).withValues(alpha: 0.12 * context.bgOrbOpacityMultiplier),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.1 * context.bgOrbOpacityMultiplier), blurRadius: 100, spreadRadius: 40)],
                  ),
                ),
              ),
              Positioned(
                bottom: -80, left: -80,
                child: Container(
                  width: 350, height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFBF360C).withValues(alpha: 0.15 * context.bgOrbOpacityMultiplier),
                    boxShadow: [BoxShadow(color: const Color(0xFFBF360C).withValues(alpha: 0.1 * context.bgOrbOpacityMultiplier), blurRadius: 120, spreadRadius: 50)],
                  ),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(color: Colors.transparent),
                ),
              ),
              
              SafeArea(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6E40)))
                    : provider.userData == null
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: const Color(0xFFFF6E40),
                        backgroundColor: const Color(0xFF1A1A1E),
                        displacement: 20,
                        onRefresh: () async {
                          await Provider.of<ProfileProvider>(context, listen: false).loadUserProfile();
                        },
                        child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              try { TabBarVisibility.of(context).update(n); } catch (_) {}
                              return false;
                            },
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Trên web rộng, căn giữa và giới hạn chiều rộng tối đa
                                final isWide = kIsWeb && constraints.maxWidth > 700;
                                final avatarSize = isWide
                                    ? 220.0 // Cố định 220px trên web
                                    : constraints.maxWidth * 0.8; // 80% trên mobile
                                Widget content = SingleChildScrollView(
                                  child: Column(
                                    children: [
                      Stack(
                        children: [
                          // Avatar lớn ở giữa màn hình, tap để xem ProfileCard
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PeerProfileScreen(
                                    peerUser: provider.userData!,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                                height: avatarSize,
                                width: avatarSize,
                                margin: EdgeInsets.all(isWide ? 24 : constraints.maxWidth * 0.1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.5), width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF6E40).withValues(alpha: 0.3),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      provider.userData!.avatarUrl ?? 'https://via.placeholder.com/400',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                          ),
                          // Nút Edit ở góc dưới bên phải avatar
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: FloatingActionButton(
                                  onPressed: () {
                                    // Mở màn hình chỉnh sửa profile
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ProfileScreen(),
                                      ),
                                    );
                                  },
                                  backgroundColor: context.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(color: context.isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1), width: 1),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.pencil,
                                    color: context.textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tên và tuổi
                            Row(
                              children: [
                                Text(
                                  provider.userData!.username,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: context.textColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${provider.userData!.age}',
                                  style: TextStyle(fontSize: 22, color: context.textSecondaryColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Card hiển thị vị trí và cài đặt matching
                            Consumer<LocationProvider>(
                              builder: (context, locationProvider, child) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: context.cardBgColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: context.cardBorderColor, width: 1),
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                CupertinoIcons.location_solid,
                                                color: Color(0xFFFF6E40),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Vị trí & Khoảng cách',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: context.textColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          
                                          // Hiển thị vị trí hiện tại
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Vị trí hiện tại:',
                                                style: TextStyle(color: context.textTertiaryColor, fontSize: 13),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                locationProvider.currentLocation ?? 'Chưa cập nhật',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                  color: context.textColor,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          
                                          // Hiển thị khoảng cách tìm kiếm
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Khoảng cách tìm kiếm:',
                                                style: TextStyle(color: context.textTertiaryColor),
                                              ),
                                              Text(
                                                '${locationProvider.maxDistance.toInt()} km',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFFFF6E40),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          
                                          // Hiển thị độ tuổi tìm kiếm
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Độ tuổi:',
                                                style: TextStyle(color: context.textTertiaryColor),
                                              ),
                                              Text(
                                                '${locationProvider.minAge} - ${locationProvider.maxAge} tuổi',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFFFF6E40),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          
                                          // 2 nút: Lấy vị trí và Cài đặt match
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: _testLocationPermission,
                                                  icon: locationProvider.isLoading
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Color(0xFFFF6E40),
                                                          ),
                                                        )
                                                      : const Icon(
                                                          CupertinoIcons.refresh,
                                                          size: 18,
                                                        ),
                                                  label: Text(
                                                    locationProvider.isLoading
                                                        ? 'Đang lấy...'
                                                        : 'Lấy vị trí',
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFFFF6E40),
                                                    side: BorderSide(
                                                      color: const Color(0xFFFF6E40).withValues(alpha: 0.5),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    // Mở màn hình cài đặt matching
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            const LocationSettingsScreen(),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    CupertinoIcons.settings,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    'Cài đặt match',
                                                    style: TextStyle(fontSize: 13),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFFF6E40),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                  )
                                );
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Hiển thị card quảng cáo Premium nếu chưa Premium
                            if (!isPremium) _buildPremiumPromoCard(),

                            const SizedBox(height: 16),

                            // Card cài đặt giao diện
                            Consumer<ThemeProvider>(
                              builder: (context, themeProvider, child) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: context.cardBgColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: context.cardBorderColor, width: 1),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          Icon(
                                            themeProvider.isDarkMode
                                                ? CupertinoIcons.moon_stars_fill
                                                : CupertinoIcons.sun_max_fill,
                                            color: const Color(0xFFFF6E40),
                                            size: 22,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Giao diện tối',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: context.textColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  themeProvider.isDarkMode
                                                      ? 'Đang bật chế độ tối'
                                                      : 'Đang bật chế độ sáng',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: context.textTertiaryColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          CupertinoSwitch(
                                            value: themeProvider.isDarkMode,
                                            activeTrackColor: const Color(0xFFFF6E40),
                                            onChanged: (value) {
                                              themeProvider.toggleTheme();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Nút Bật thông báo Web
                            if (kIsWeb)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: context.cardBgColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: context.cardBorderColor, width: 1),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Thông báo Web',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: context.textColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Bật thông báo trên trình duyệt',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: context.textTertiaryColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              try {
                                                final messaging = FirebaseMessaging.instance;
                                                final settings = await messaging.requestPermission();
                                                if (settings.authorizationStatus == AuthorizationStatus.authorized) {
                                                  final token = await NotificationController().getFirebaseToken();
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(token != null ? 'Đã bật thông báo thành công!' : 'Có lỗi khi lấy token'),
                                                        backgroundColor: token != null ? Colors.green : Colors.red,
                                                      ),
                                                    );
                                                  }
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Chưa cấp quyền thông báo'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                _logger.severe('Lỗi thông báo web: $e');
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Lỗi: $e'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFFF6E40),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            child: const Text('Bật'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 16),
                            
                            // Section Game yêu thích
                            _buildSection(
                              'Game yêu thích',
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: provider.userData!.favoriteGames
                                    .map(
                                      (game) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: context.cardBgColor,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.4), width: 1),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFF6E40).withValues(alpha: 0.15),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(CupertinoIcons.game_controller_solid, size: 14, color: Color(0xFFFF6E40)),
                                            const SizedBox(width: 6),
                                            Text(
                                              game, 
                                              style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Section Thống kê game
                            _buildSection(
                              'Thống kê',
                              Column(
                                children: [
                                  _buildStatRow('Rank', provider.userData!.rank),
                                  _buildStatRow(
                                    'Thời gian chơi',
                                    '${provider.userData!.playTime} phút/ngày',
                                  ),
                                  _buildStatRow(
                                    'Tỷ lệ thắng',
                                    '${provider.userData!.winRate}%',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton.icon(
                          onPressed: _handleLogout,
                          icon: const Icon(CupertinoIcons.square_arrow_right, color: Color(0xFFFF3B30)),
                          label: const Text('Đăng xuất', style: TextStyle(color: Color(0xFFFF3B30))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFF3B30)),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: content,
                    ),
                  );
                }
                return content;
              },
            ),
        ),
      ), // đóng NotificationListener
              )
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
  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textColor),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  // Widget helper để hiển thị một dòng thống kê (label - value)
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: context.textSecondaryColor)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6E40),
            ),
          ),
        ],
      ),
    );
  }
}
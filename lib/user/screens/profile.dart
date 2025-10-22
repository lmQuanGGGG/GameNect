import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_profile_screen.dart';
import 'edit_profile_screen.dart';
import 'location_settings_screen.dart';
import 'package:logging/logging.dart';
import 'subscription_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Logger _logger = Logger('ProfilePage');
  
  Widget _buildPremiumPromoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepOrange.withOpacity(0.12),
            Colors.orange.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepOrange.withOpacity(0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nâng cấp Premium',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          _featureRow('Xem ai đã thích bạn'),
          const SizedBox(height: 6),
          _featureRow('Đăng khoảnh khắc không giới hạn'),
          const SizedBox(height: 6),
          _featureRow('Hoàn tác lượt vuốt, super like tăng khả năng kết nối'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Nâng cấp ngay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, size: 18, color: Colors.deepOrange),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.black87))),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadUserProfile();
    });
  }

  Future<void> _testLocationPermission() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    _logger.info('Test: Bắt đầu request location permission...');
    
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final isPremium = provider.userData?.isPremium ?? false;
        
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 60,
            titleSpacing: 0,
            title: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12.0),
                  child: Icon(
                    CupertinoIcons.game_controller_solid,
                    color: Colors.deepOrange,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 8), 
                const Text(
                  'gamenect',
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            actions: [
              // THÊM: Premium Button/Badge
              if (isPremium)
                // Hiển thị badge Premium nếu đã đăng ký
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
                // Hiển thị nút Nâng cấp nếu chưa Premium
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                  },
                  icon: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.deepOrange,
                    size: 20,
                  ),
                  label: const Text(
                    'Nâng cấp',
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              
              // Settings Menu
              PopupMenuButton<String>(
                icon: const Icon(
                  CupertinoIcons.settings,
                  color: Colors.grey,
                  size: 24,
                ),
                onSelected: (value) async {
                  if (value == 'logout') {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Đăng xuất'),
                        content: const Text('Bạn có chắc muốn đăng xuất?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Hủy'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Đăng xuất'),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true) {
                      final authService = Provider.of<AuthService>(context, listen: false);
                      await authService.signOut();
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    }
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.settings, size: 20),
                        SizedBox(width: 8),
                        Text('Cài đặt'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.square_arrow_right, 
                          size: 20, 
                          color: Colors.red
                        ),
                        SizedBox(width: 8),
                        Text('Đăng xuất', 
                          style: TextStyle(color: Colors.red)
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.userData == null
              ? _buildEmptyState()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      HomeProfileScreen(userId: provider.userData!.id),
                                ),
                              );
                            },
                            child: Container(
                              height:
                                  MediaQuery.of(context).size.width *
                                  0.8,
                              width: MediaQuery.of(context).size.width * 0.8,
                              margin: EdgeInsets.all(
                                MediaQuery.of(context).size.width * 0.1,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                                image: DecorationImage(
                                  image: NetworkImage(
                                    provider.userData!.avatarUrl ??
                                        'https://via.placeholder.com/400',
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileScreen(),
                                  ),
                                );
                              },
                              backgroundColor: Colors.white,
                              child: const Icon(
                                CupertinoIcons.pencil,
                                color: Colors.deepOrange,
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
                            Row(
                              children: [
                                Text(
                                  provider.userData!.username,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${provider.userData!.age}',
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            Consumer<LocationProvider>(
                              builder: (context, locationProvider, child) {
                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              CupertinoIcons.location_solid,
                                              color: Colors.deepOrange,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Vị trí & Khoảng cách',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Vị trí hiện tại:',
                                              style: TextStyle(color: Colors.grey),
                                            ),
                                            Text(
                                              locationProvider.currentLocation ?? 'Chưa cập nhật',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Khoảng cách tìm kiếm:',
                                              style: TextStyle(color: Colors.grey),
                                            ),
                                            Text(
                                              '${locationProvider.maxDistance.toInt()} km',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.deepOrange,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Độ tuổi:',
                                              style: TextStyle(color: Colors.grey),
                                            ),
                                            Text(
                                              '${locationProvider.minAge} - ${locationProvider.maxAge} tuổi',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.deepOrange,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        
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
                                                  foregroundColor: Colors.deepOrange,
                                                  side: const BorderSide(
                                                    color: Colors.deepOrange,
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
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
                                                  'Cài đặt',
                                                  style: TextStyle(fontSize: 13),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.deepOrange,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            if (!isPremium) _buildPremiumPromoCard(),

                            const SizedBox(height: 16),
                            
                            _buildSection(
                              'Game yêu thích',
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: provider.userData!.favoriteGames
                                    .map(
                                      (game) => Chip(
                                        label: Text(game),
                                        backgroundColor: Colors.deepOrange
                                            .withValues(alpha: 0.1),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
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
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/admin-test-users');
                          },
                          icon: const Icon(CupertinoIcons.person_3_fill),
                          label: const Text('Tạo Test Users (Admin)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
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
                ),
        );
      },
    );
  }

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

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }
}
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Gọi loadUserProfile khi widget được khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadUserProfile();
    });
  }

  // Test location permission
  Future<void> _testLocationPermission() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    print('Test: Bắt đầu request location permission...');
    
    // Request permission
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
    
    print('Test: Đã có permission, đang lấy vị trí...');
    
    // Get current location
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
        
        // Update location to Firestore
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
              PopupMenuButton<String>(
                icon: const Icon(
                  CupertinoIcons.settings,
                  color: Colors.grey,
                  size: 24,
                ),
                onSelected: (value) async {
                  if (value == 'logout') {
                    // Show confirmation dialog
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
                      // Ảnh đại diện và nút chỉnh sửa
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              // Mở HomeProfileScreen để xem trước
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
                                    color: Colors.black.withOpacity(0.2),
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
                          // Nút chỉnh sửa
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
                      // Thông tin cơ bản
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
                            
                            // THÊM PHẦN NÀY - Location Info
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
                                        
                                        // Current Location
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
                                        
                                        // Max Distance
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
                                        
                                        // Age Range - THÊM MỚI
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
                                        
                                        // Buttons Row
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
                            
                            // Game yêu thích
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
                                            .withOpacity(0.1),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Thông tin game
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

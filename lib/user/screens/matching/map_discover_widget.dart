import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/match_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/theme/theme_helper.dart';
import '../shared/peer_profile_screen.dart';

class MapDiscoverWidget extends StatefulWidget {
  const MapDiscoverWidget({super.key});

  @override
  State<MapDiscoverWidget> createState() => _MapDiscoverWidgetState();
}

class _MapDiscoverWidgetState extends State<MapDiscoverWidget> {
  bool _isLoadingLocation = true;
  int _mapViewCount = 0;
  bool _isPremium = false;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _checkPremiumAndShowLimit();
  }

  Future<void> _fetchLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    // Yêu cầu lấy vị trí hiện tại (và xin quyền nếu chưa có)
    await locationProvider.getCurrentLocation();
    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _checkPremiumAndShowLimit() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _isGuest = true;
      // Chế độ Guest: Không hiển thị thông báo mua Premium
      return;
    }

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    _isPremium = profileProvider.userData?.isPremium ?? false;

    if (!_isPremium) {
      final prefs = await SharedPreferences.getInstance();
      _mapViewCount = (prefs.getInt('map_view_count') ?? 0) + 1;
      await prefs.setInt('map_view_count', _mapViewCount);
      
      if (mounted) {
        // Chỉ hiện sau khi widget build xong
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLimitNotification();
        });
      }
    }
  }

  void _showLimitNotification() {
    if (_mapViewCount <= 2) {
      // Hiện Popup giữa màn hình (Lần 1, Lần 2)
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(8, 8)),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map, size: 50, color: Color(0xFFFF6E40)),
                const SizedBox(height: 16),
                const Text(
                  'GIỚI HẠN BẢN ĐỒ',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bạn chỉ được xem tối đa 10 người trên Bản đồ. Để xem tất cả, vui lòng chuyển sang chế độ Quẹt hoặc Nâng cấp Premium!',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6E40),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('ĐÃ HIỂU', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Từ Lần 3 trở đi: Hiện Snack bar sát mép trên
      final screenHeight = MediaQuery.of(context).size.height;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(4, 4)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Icon(Icons.workspace_premium, color: Color(0xFFFF6E40)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đang hiển thị 10 người. Nâng cấp Premium để gỡ giới hạn.',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          // Đẩy snackbar lên sát top bar (chừa kToolbarHeight + safe area)
          margin: EdgeInsets.only(
            bottom: screenHeight - kToolbarHeight - 140, // Điều chỉnh tùy biến
            left: 16,
            right: 16,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final matchProvider = Provider.of<MatchProvider>(context);

    if (_isLoadingLocation || locationProvider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6E40)));
    }

    if (locationProvider.latitude == null || locationProvider.longitude == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Không thể lấy vị trí của bạn'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6E40),
                foregroundColor: Colors.black,
              ),
              child: const Text('Thử lại'),
            )
          ],
        ),
      );
    }

    final myLocation = LatLng(locationProvider.latitude!, locationProvider.longitude!);
    
    // Giới hạn số lượng user
    final usersToDisplay = (_isPremium || _isGuest)
        ? matchProvider.recommendations 
        : matchProvider.recommendations.take(10).toList();

    // Tạo markers từ recommendations đã lọc
    final List<Marker> markers = [];
    
    // Marker của chính mình
    markers.add(
      Marker(
        point: myLocation,
        width: 60,
        height: 60,
        child: _buildMarkerWidget(
          imageUrl: null, 
          isMe: true,
          onTap: null,
        ),
      ),
    );

    // Marker của những người khác
    for (var user in usersToDisplay) {
      if (user.latitude != null && user.longitude != null) {
        markers.add(
          Marker(
            point: LatLng(user.latitude!, user.longitude!),
            width: 60,
            height: 60,
            child: _buildMarkerWidget(
              imageUrl: user.avatarUrl,
              isMe: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PeerProfileScreen(peerUser: user, showActions: true)),
                );
              },
            ),
          ),
        );
      }
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: myLocation,
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&hl=vi&gl=VN',
          userAgentPackageName: 'com.gamenect.app',
          retinaMode: true,
        ),
        MarkerLayer(
          markers: markers,
        ),
      ],
    );
  }

  Widget _buildMarkerWidget({String? imageUrl, bool isMe = false, VoidCallback? onTap}) {
    final bool isDark = context.isDarkMode;
    final borderColor = isDark ? Colors.white : Colors.black;
    final bgColor = isMe ? const Color(0xFFFF6E40) : (isDark ? Colors.black : Colors.white);

    Widget avatarContent;
    if (isMe) {
      avatarContent = const Icon(Icons.person_pin_circle, color: Colors.white, size: 30);
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      avatarContent = ClipOval(
        child: GamenectNetworkImage(
          imageUrl: imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.grey[800]),
          errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white, size: 30),
        ),
      );
    } else {
      avatarContent = const Icon(Icons.person, color: Colors.grey, size: 30);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('====> CLICKED ON AVATAR <====');
        if (onTap != null) onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: borderColor,
              offset: const Offset(3, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: avatarContent,
          ),
        ),
      ),
    );
  }
}

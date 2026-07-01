// File này định nghĩa màn hình cài đặt vị trí và các tùy chọn matching cho người dùng.
// Người dùng có thể điều chỉnh khoảng cách tối đa, độ tuổi, giới tính muốn tìm, và các cài đặt khác.
// Sử dụng provider để quản lý trạng thái và lưu trữ vào Firestore.
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../../../core/providers/location_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/theme/theme_helper.dart';

// Flag để theo dõi liệu LocationProvider đã được đồng bộ từ Firestore chưa trong phiên hiện tại
// Tránh việc mở màn hình lần 2 sẽ reset lại settings mà user vừa thay đổi nhưng chưa lưu
bool _locationSettingsLoaded = false;

/// Màn hình cài đặt khoảng cách matching như Tinder
class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Chỉ load settings từ userData nếu chưa load trong phiên hiện tại.
    // Điều này tránh reset lại các thay đổi chưa lưu của user khi màn hình rebuild,
    // và tránh dữ liệu cũ ghi đè lên state hiện tại của LocationProvider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_locationSettingsLoaded) {
        final profileProvider = context.read<ProfileProvider>();
        final locationProvider = context.read<LocationProvider>();
        if (profileProvider.userData != null) {
          locationProvider.loadSettingsFromUser(profileProvider.userData!);
          _locationSettingsLoaded = true;
        }
      }
    });
  }

  @override
  void dispose() {
    // Reset flag khi màn hình bị hủy hoàn toàn (pop khỏi navigator stack)
    // để lần mở sau sẽ load lại từ Firestore (phản ánh dữ liệu đã lưu)
    _locationSettingsLoaded = false;
    super.dispose();
  }

  /// Lưu settings vào Firestore
  Future<void> _saveSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final locationProvider = context.read<LocationProvider>();
    final success = await locationProvider.saveSettings(userId);

    if (mounted) {
      if (success) {
        // Sau khi lưu thành công, refresh ProfileProvider để userData
        // phản ánh giá trị mới nhất từ Firestore. Điều này đảm bảo lần
        // mở màn hình tiếp theo sẽ load đúng dữ liệu đã lưu.
        await context.read<ProfileProvider>().loadUserProfile();
        // Reset flag để lần mở tiếp theo sẽ đọc lại từ userData mới
        _locationSettingsLoaded = false;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã lưu cài đặt'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi: ${locationProvider.error ?? "Không xác định"}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Refresh location hiện tại
  Future<void> _refreshLocation() async {
    final locationProvider = context.read<LocationProvider>();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await locationProvider.updateUserLocation(userId);
    } else {
      await locationProvider.getCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        return Scaffold(
          backgroundColor: context.scaffoldBackgroundColor,
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.appBarBgColor,
                    border: Border(
                      bottom: BorderSide(
                        color: context.cardBorderColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: IconButton(
                            icon: const Icon(
                              CupertinoIcons.back,
                              color: Color(0xFFFF6E40),
                              size: 28,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cài đặt vị trí & bộ lọc',
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: locationProvider.isLoading ? null : _saveSettings,
                          child: Text(
                            'Lưu',
                            style: TextStyle(
                              color: locationProvider.isLoading
                                  ? context.textTertiaryColor
                                  : context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: locationProvider.isLoading
              ? Center(child: CircularProgressIndicator(color: context.textColor))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Stack(
                  children: [
                    SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Phần hiển thị vị trí hiện tại
                            _buildSection(
                              title: 'Vị trí hiện tại',
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: context.scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(0),
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
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: context.textColor.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(CupertinoIcons.location_solid, color: Color(0xFFFF6E40),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            locationProvider.currentLocation ?? 'Đang tải...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: context.textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Cập nhật tự động',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: context.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(CupertinoIcons.refresh, color: Color(0xFFFF6E40),
                                      ),
                                      onPressed: _refreshLocation,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Phần cài đặt khoảng cách tối đa
                            _buildSection(
                              title: 'Khoảng cách tối đa',
                              subtitle: 'Tìm người chơi trong bán kính ${locationProvider.maxDistance.round()} km',
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFFFF6E40),
                                      inactiveTrackColor: context.cardBorderColor,
                                      thumbColor: const Color(0xFFFF6E40),
                                      overlayColor: const Color(0xFFFF6E40).withValues(alpha: 0.2),
                                      trackHeight: 6,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                                    ),
                                    child: Slider(
                                      value: locationProvider.maxDistance,
                                      min: 1,
                                      max: 2000,
                                      divisions: 1999,
                                      onChanged: locationProvider.setMaxDistance,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('1 km', style: TextStyle(color: context.textTertiaryColor, fontSize: 12)),
                                        Text('2000 km', style: TextStyle(color: context.textTertiaryColor, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(child: _buildQuickSelectButton(label: '10 km', value: 10, currentValue: locationProvider.maxDistance, onTap: locationProvider.setMaxDistance)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildQuickSelectButton(label: '50 km', value: 50, currentValue: locationProvider.maxDistance, onTap: locationProvider.setMaxDistance)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildQuickSelectButton(label: '100 km', value: 100, currentValue: locationProvider.maxDistance, onTap: locationProvider.setMaxDistance)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildQuickSelectButton(label: '500 km', value: 500, currentValue: locationProvider.maxDistance, onTap: locationProvider.setMaxDistance)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Phần cài đặt độ tuổi
                            _buildSection(
                              title: 'Độ tuổi',
                              subtitle: 'Chỉ hiển thị người chơi từ ${locationProvider.minAge} đến ${locationProvider.maxAge} tuổi',
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFFFF6E40),
                                      inactiveTrackColor: context.cardBorderColor,
                                      thumbColor: const Color(0xFFFF6E40),
                                      overlayColor: const Color(0xFFFF6E40).withValues(alpha: 0.2),
                                      trackHeight: 6,
                                      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 12),
                                    ),
                                    child: RangeSlider(
                                      values: RangeValues(
                                        locationProvider.minAge.toDouble(),
                                        locationProvider.maxAge.toDouble(),
                                      ),
                                      min: 18,
                                      max: 99,
                                      divisions: 81,
                                      onChanged: (RangeValues values) {
                                        locationProvider.setMinAge(values.start.round());
                                        locationProvider.setMaxAge(values.end.round());
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('18 tuổi', style: TextStyle(color: context.textTertiaryColor, fontSize: 12)),
                                        Text('99 tuổi', style: TextStyle(color: context.textTertiaryColor, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(child: _buildAgeRangeButton(label: '18-25', minAge: 18, maxAge: 25, locationProvider: locationProvider)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildAgeRangeButton(label: '26-35', minAge: 26, maxAge: 35, locationProvider: locationProvider)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildAgeRangeButton(label: '36+', minAge: 36, maxAge: 99, locationProvider: locationProvider)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Phần cài đặt giới tính muốn tìm
                            _buildSection(
                              title: 'Tìm kiếm',
                              subtitle: 'Giới tính bạn muốn tìm',
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(child: _buildGenderButton(label: 'Nam', isSelected: locationProvider.interestedInGender == 'Nam', onTap: () => locationProvider.setInterestedInGender('Nam'))),
                                    Expanded(child: _buildGenderButton(label: 'Nữ', isSelected: locationProvider.interestedInGender == 'Nữ', onTap: () => locationProvider.setInterestedInGender('Nữ'))),
                                    Expanded(child: _buildGenderButton(label: 'Tất cả', isSelected: locationProvider.interestedInGender == 'Tất cả', onTap: () => locationProvider.setInterestedInGender('Tất cả'))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Toggle hiển thị khoảng cách
                            _buildSection(
                              title: 'Hiển thị khoảng cách',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: context.cardBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.cardBorderColor),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Hiển thị khoảng cách trên profile',
                                        style: TextStyle(fontSize: 16, color: context.textColor),
                                      ),
                                    ),
                                    CupertinoSwitch(
                                      value: locationProvider.showDistance,
                                      activeTrackColor: const Color(0xFFFF6E40),
                                      onChanged: locationProvider.setShowDistance,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Toggle lọc theo game chung
                            _buildSection(
                              title: 'Lọc theo game',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: context.cardBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.cardBorderColor),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Chỉ hiện người chơi chung game',
                                            style: TextStyle(fontSize: 16, color: context.textColor),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tắt → ML AI tự sắp xếp theo độ phù hợp',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    CupertinoSwitch(
                                      value: locationProvider.filterCommonGame,
                                      activeTrackColor: const Color(0xFFFF6E40),
                                      onChanged: locationProvider.setFilterCommonGame,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Thông tin hướng dẫn
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.textColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.textColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(CupertinoIcons.info_circle_fill, color: context.textColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Vị trí của bạn sẽ được cập nhật tự động để tìm người chơi gần bạn. Bạn có thể thay đổi khoảng cách matching bất cứ lúc nào.',
                                      style: TextStyle(
                                        color: context.textColor.withValues(alpha: 0.8),
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: context.textColor,
            letterSpacing: 1.0,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
        ],
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildQuickSelectButton({
    required String label,
    required double value,
    required double currentValue,
    required Function(double) onTap,
  }) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6E40) : context.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? context.textColor : context.textColor.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: context.textColor, offset: const Offset(4, 4))]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? context.scaffoldBackgroundColor : context.textSecondaryColor,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAgeRangeButton({
    required String label,
    required int minAge,
    required int maxAge,
    required LocationProvider locationProvider,
  }) {
    final isSelected = locationProvider.minAge == minAge && locationProvider.maxAge == maxAge;
    return GestureDetector(
      onTap: () {
        locationProvider.setMinAge(minAge);
        locationProvider.setMaxAge(maxAge);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6E40) : context.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? context.textColor : context.textColor.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: context.textColor, offset: const Offset(4, 4))]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? context.scaffoldBackgroundColor : context.textSecondaryColor,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildGenderButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6E40) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: context.textColor, width: 3) : null,
          boxShadow: isSelected
              ? [BoxShadow(color: context.textColor, offset: const Offset(4, 4))]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? context.scaffoldBackgroundColor : context.textSecondaryColor,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
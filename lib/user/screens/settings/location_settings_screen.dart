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
    // Load settings from user profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider = context.read<ProfileProvider>();
      final locationProvider = context.read<LocationProvider>();
      
      if (profileProvider.userData != null) {
        locationProvider.loadSettingsFromUser(profileProvider.userData!);
      }
    });
  }

  /// Lưu settings vào Firestore
  Future<void> _saveSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final locationProvider = context.read<LocationProvider>();
    final success = await locationProvider.saveSettings(userId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cài đặt'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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
    await locationProvider.getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101012),
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 0.8,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.back,
                                    color: Color(0xFFFF6E40),
                                    size: 24,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Cài đặt vị trí & bộ lọc',
                            style: TextStyle(
                              color: Colors.white,
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
                                  ? Colors.white38
                                  : const Color(0xFFFF6E40),
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
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6E40)))
              : Stack(
                  children: [
                    // Orbs background
                    Positioned(
                      top: 100,
                      left: -80,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF6E40).withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6E40).withValues(alpha: 0.1),
                              blurRadius: 100,
                              spreadRadius: 40,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 100,
                      right: -80,
                      child: Container(
                        width: 350,
                        height: 350,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFBF360C).withValues(alpha: 0.12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBF360C).withValues(alpha: 0.1),
                              blurRadius: 120,
                              spreadRadius: 50,
                            ),
                          ],
                        ),
                      ),
                    ),
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
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6E40).withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.location_solid,
                                        color: Color(0xFFFF6E40),
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
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Cập nhật tự động',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        CupertinoIcons.refresh,
                                        color: Color(0xFFFF6E40),
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
                                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
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
                                        Text('1 km', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                                        Text('2000 km', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
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
                                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
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
                                        Text('18 tuổi', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                                        Text('99 tuổi', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
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
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
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
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Hiển thị khoảng cách trên profile',
                                        style: TextStyle(fontSize: 16, color: Colors.white),
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
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Chỉ hiện người chơi chung game',
                                            style: TextStyle(fontSize: 16, color: Colors.white),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tắt → ML AI tự sắp xếp theo độ phù hợp',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.5),
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
                                color: const Color(0xFFFF6E40).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    CupertinoIcons.info_circle_fill,
                                    color: Color(0xFFFF6E40),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Vị trí của bạn sẽ được cập nhật tự động để tìm người chơi gần bạn. Bạn có thể thay đổi khoảng cách matching bất cứ lúc nào.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
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
          color: isSelected ? const Color(0xFFFF6E40) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6E40) : Colors.white.withValues(alpha: 0.15),
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
          color: isSelected ? const Color(0xFFFF6E40) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6E40) : Colors.white.withValues(alpha: 0.15),
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
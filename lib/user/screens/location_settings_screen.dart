// File này định nghĩa màn hình cài đặt vị trí và các tùy chọn matching cho người dùng.
// Người dùng có thể điều chỉnh khoảng cách tối đa, độ tuổi, giới tính muốn tìm, và các cài đặt khác.
// Sử dụng provider để quản lý trạng thái và lưu trữ vào Firestore.
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/providers/location_provider.dart';
import '../../core/providers/profile_provider.dart';

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
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Cài đặt vị trí',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              TextButton(
                onPressed: locationProvider.isLoading ? null : _saveSettings,
                child: Text(
                  'Lưu',
                  style: TextStyle(
                    color: locationProvider.isLoading 
                        ? Colors.grey 
                        : Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          body: locationProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Phần hiển thị vị trí hiện tại
                      _buildSection(
                        title: 'Vị trí hiện tại',
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.location_solid,
                                color: Colors.deepOrange,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locationProvider.currentLocation ?? 
                                          'Đang tải...',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Cập nhật tự động',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  CupertinoIcons.refresh,
                                  color: Colors.deepOrange,
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
                            
                            // Slider để chọn khoảng cách
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.deepOrange,
                                inactiveTrackColor: Colors.grey[300],
                                thumbColor: Colors.deepOrange,
                                overlayColor: Colors.deepOrange.withValues(alpha: 0.2),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 12,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 24,
                                ),
                              ),
                              child: Slider(
                                value: locationProvider.maxDistance,
                                min: 1,
                                max: 2000,
                                divisions: 1999,
                                label: '${locationProvider.maxDistance.round()} km',
                                onChanged: (value) {
                                  locationProvider.setMaxDistance(value);
                                },
                              ),
                            ),

                            // Nhãn khoảng cách
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '1 km',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '2000 km',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Các nút chọn nhanh khoảng cách
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickSelectButton(
                                    label: '10 km',
                                    value: 10,
                                    currentValue: locationProvider.maxDistance,
                                    onTap: locationProvider.setMaxDistance,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildQuickSelectButton(
                                    label: '50 km',
                                    value: 50,
                                    currentValue: locationProvider.maxDistance,
                                    onTap: locationProvider.setMaxDistance,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildQuickSelectButton(
                                    label: '100 km',
                                    value: 100,
                                    currentValue: locationProvider.maxDistance,
                                    onTap: locationProvider.setMaxDistance,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildQuickSelectButton(
                                    label: '500 km',
                                    value: 500,
                                    currentValue: locationProvider.maxDistance,
                                    onTap: locationProvider.setMaxDistance,
                                  ),
                                ),
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
                            
                            // Range Slider cho độ tuổi
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.deepOrange,
                                inactiveTrackColor: Colors.grey[300],
                                rangeThumbShape: const RoundRangeSliderThumbShape(
                                  enabledThumbRadius: 12,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 24,
                                ),
                              ),
                              child: RangeSlider(
                                values: RangeValues(
                                  locationProvider.minAge.toDouble(),
                                  locationProvider.maxAge.toDouble(),
                                ),
                                min: 18,
                                max: 99,
                                divisions: 81,
                                labels: RangeLabels(
                                  '${locationProvider.minAge}',
                                  '${locationProvider.maxAge}',
                                ),
                                onChanged: (RangeValues values) {
                                  locationProvider.setMinAge(values.start.round());
                                  locationProvider.setMaxAge(values.end.round());
                                },
                              ),
                            ),

                            // Nhãn độ tuổi
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '18 tuổi',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '99 tuổi',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Các nút chọn nhanh độ tuổi
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAgeRangeButton(
                                    label: '18-25',
                                    minAge: 18,
                                    maxAge: 25,
                                    locationProvider: locationProvider,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAgeRangeButton(
                                    label: '26-35',
                                    minAge: 26,
                                    maxAge: 35,
                                    locationProvider: locationProvider,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAgeRangeButton(
                                    label: '36+',
                                    minAge: 36,
                                    maxAge: 99,
                                    locationProvider: locationProvider,
                                  ),
                                ),
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
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildGenderButton(
                                  label: 'Nam',
                                  isSelected: locationProvider.interestedInGender == 'Nam',
                                  onTap: () => locationProvider.setInterestedInGender('Nam'),
                                ),
                              ),
                              Expanded(
                                child: _buildGenderButton(
                                  label: 'Nữ',
                                  isSelected: locationProvider.interestedInGender == 'Nữ',
                                  onTap: () => locationProvider.setInterestedInGender('Nữ'),
                                ),
                              ),
                              Expanded(
                                child: _buildGenderButton(
                                  label: 'Tất cả',
                                  isSelected: locationProvider.interestedInGender == 'Tất cả',
                                  onTap: () => locationProvider.setInterestedInGender('Tất cả'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Toggle hiển thị khoảng cách
                      _buildSection(
                        title: 'Hiển thị khoảng cách',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Hiển thị khoảng cách trên profile',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              CupertinoSwitch(
                                value: locationProvider.showDistance,
                                activeTrackColor: Colors.deepOrange,
                                onChanged: locationProvider.setShowDistance,
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
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange[200]!,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              CupertinoIcons.info_circle_fill,
                              color: Colors.orange[700],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Vị trí của bạn sẽ được cập nhật tự động để tìm người chơi gần bạn. Bạn có thể thay đổi khoảng cách matching bất cứ lúc nào.',
                                style: TextStyle(
                                  color: Colors.grey[800],
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
        );
      },
    );
  }

  // Widget helper để xây dựng một section với title và child
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
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  // Widget helper cho nút chọn nhanh khoảng cách
  Widget _buildQuickSelectButton({
    required String label,
    required double value,
    required double currentValue,
    required Function(double) onTap,
  }) {
    final isSelected = currentValue == value;
    
    return OutlinedButton(
      onPressed: () => onTap(value),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.deepOrange : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.deepOrange,
        side: BorderSide(
          color: isSelected ? Colors.deepOrange : Colors.grey[300]!,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Widget helper cho nút chọn nhanh độ tuổi
  Widget _buildAgeRangeButton({
    required String label,
    required int minAge,
    required int maxAge,
    required LocationProvider locationProvider,
  }) {
    final isSelected = locationProvider.minAge == minAge && 
                      locationProvider.maxAge == maxAge;
    
    return OutlinedButton(
      onPressed: () {
        locationProvider.setMinAge(minAge);
        locationProvider.setMaxAge(maxAge);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.deepOrange : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.deepOrange,
        side: BorderSide(
          color: isSelected ? Colors.deepOrange : Colors.grey[300]!,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Widget helper cho nút chọn giới tính
  Widget _buildGenderButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

/// Provider quản lý location và distance settings
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();

  // State
  bool _isLoading = false;
  String? _error;
  String? _currentLocation;
  double? _latitude;
  double? _longitude;
  String? _address;
  String? _city;
  String? _country;
  
  // Settings
  double _maxDistance = 50.0;
  bool _showDistance = true;
  int _minAge = 18;
  int _maxAge = 99;
  String _interestedInGender = 'Tất cả';

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentLocation => _currentLocation;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get address => _address;
  String? get city => _city;
  String? get country => _country;
  double get maxDistance => _maxDistance;
  bool get showDistance => _showDistance;
  int get minAge => _minAge;
  int get maxAge => _maxAge;
  String get interestedInGender => _interestedInGender;

  /// Request quyền truy cập location
  Future<bool> requestLocationPermission() async {
    try {
      _error = null;
      notifyListeners();

      final hasPermission = await _locationService.requestLocationPermission();
      
      if (!hasPermission) {
        _error = 'Bạn cần cấp quyền truy cập vị trí để sử dụng tính năng này';
        notifyListeners();
      }

      return hasPermission;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Lấy vị trí hiện tại
  Future<bool> getCurrentLocation() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Đang lấy vị trí hiện tại...');

      // Kiểm tra quyền trước
      final hasPermission = await _locationService.requestLocationPermission();
      if (!hasPermission) {
        _error = 'Không có quyền truy cập vị trí';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Lấy vị trí
      final position = await _locationService.getCurrentLocation();

      if (position == null) {
        _error = 'Không thể lấy vị trí hiện tại';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Lưu tọa độ
      _latitude = position.latitude;
      _longitude = position.longitude;

      // Chuyển đổi thành địa chỉ
      final addressData = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      _address = addressData['address'];
      _city = addressData['city'];
      _country = addressData['country'];
      _currentLocation = _address ?? _city ?? 'Không xác định'; // ✅ FIX 1

      print('Đã lấy vị trí: $_currentLocation');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Lỗi khi lấy vị trí: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật location lên Firestore
  Future<bool> updateUserLocation(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Đang cập nhật location cho user: $userId');

      // Lấy location data
      final locationData = await _locationService.getLocationData();

      if (locationData == null) {
        _error = 'Không thể lấy dữ liệu vị trí';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Cập nhật vào Firestore
      await _firestoreService.updateUserLocation(userId, locationData);

      // Cập nhật local state
      _latitude = locationData['latitude'];
      _longitude = locationData['longitude'];
      _address = locationData['address'];
      _city = locationData['city'];
      _country = locationData['country'];
      _currentLocation = _address ?? _city ?? 'Không xác định'; // ✅ FIX 2

      print('Đã cập nhật location thành công');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Lỗi khi cập nhật location: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load settings từ UserModel
  void loadSettingsFromUser(UserModel user) {
    _maxDistance = user.maxDistance;
    _showDistance = user.showDistance;
    _minAge = user.minAge;
    _maxAge = user.maxAge;
    _interestedInGender = user.interestedInGender;
    _latitude = user.latitude;
    _longitude = user.longitude;
    _address = user.address;
    _city = user.city;
    _country = user.country;
    _currentLocation = user.address ?? user.city ?? user.location; // ✅ FIX 3
    
    notifyListeners();
  }

  /// Set max distance
  void setMaxDistance(double distance) {
    _maxDistance = distance;
    notifyListeners();
  }

  /// Set show distance
  void setShowDistance(bool value) {
    _showDistance = value;
    notifyListeners();
  }

  /// Set min age
  void setMinAge(int age) {
    _minAge = age;
    notifyListeners();
  }

  /// Set max age
  void setMaxAge(int age) {
    _maxAge = age;
    notifyListeners();
  }

  /// Set interested in gender
  void setInterestedInGender(String gender) {
    _interestedInGender = gender;
    notifyListeners();
  }

  /// Lưu settings lên Firestore
  Future<bool> saveSettings(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Đang lưu settings...');

      await _firestoreService.updateLocationSettings(
        userId,
        maxDistance: _maxDistance,
        showDistance: _showDistance,
        minAge: _minAge, // THÊM
        maxAge: _maxAge, // THÊM
        interestedInGender: _interestedInGender, // THÊM
      );

      print('Đã lưu settings thành công');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Lỗi khi lưu settings: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Tính khoảng cách đến user khác
  double? calculateDistanceTo({
    required double targetLat,
    required double targetLon,
  }) {
    if (_latitude == null || _longitude == null) {
      return null;
    }

    return _locationService.calculateDistance(
      lat1: _latitude!,
      lon1: _longitude!,
      lat2: targetLat,
      lon2: targetLon,
    );
  }

  /// Format khoảng cách để hiển thị
  String formatDistance(double distanceInKm) {
    return _locationService.formatDistance(distanceInKm);
  }

  /// Kiểm tra user có trong bán kính matching không
  bool isWithinMatchingRadius({
    required double targetLat,
    required double targetLon,
  }) {
    if (_latitude == null || _longitude == null) {
      return false;
    }

    return _locationService.isWithinMatchingRadius(
      userLat: _latitude!,
      userLon: _longitude!,
      targetLat: targetLat,
      targetLon: targetLon,
      maxDistanceKm: _maxDistance,
    );
  }

  /// Reset state
  void reset() {
    _isLoading = false;
    _error = null;
    _currentLocation = null;
    _latitude = null;
    _longitude = null;
    _address = null;
    _city = null;
    _country = null;
    _maxDistance = 50.0;
    _showDistance = true;
    notifyListeners();
  }
}
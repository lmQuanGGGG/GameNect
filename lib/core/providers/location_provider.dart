import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'package:logging/logging.dart';

// Lớp LocationProvider quản lý toàn bộ logic về vị trí và cài đặt khoảng cách matching của người dùng.
// Bao gồm lấy vị trí hiện tại, cập nhật vị trí lên Firestore, cài đặt khoảng cách, độ tuổi, giới tính mong muốn khi ghép đôi.
// Sử dụng ChangeNotifier để cập nhật giao diện khi dữ liệu thay đổi.
// Sử dụng Logger để ghi log quá trình xử lý và lỗi.

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService(); // Service lấy vị trí GPS và xử lý khoảng cách
  final FirestoreService _firestoreService = FirestoreService(); // Service cập nhật dữ liệu lên Firestore
  final Logger _logger = Logger('LocationProvider'); // Logger ghi log thông tin và lỗi

  // State lưu thông tin vị trí hiện tại và trạng thái loading/lỗi
  bool _isLoading = false;
  String? _error;
  String? _currentLocation;
  double? _latitude;
  double? _longitude;
  String? _address;
  String? _city;
  String? _country;

  // Các cài đặt matching: khoảng cách, độ tuổi, giới tính mong muốn
  double _maxDistance = 50.0;
  bool _showDistance = true;
  int _minAge = 18;
  int _maxAge = 99;
  String _interestedInGender = 'Tất cả';

  // Các getter để truy cập dữ liệu từ bên ngoài
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

  // Hàm xin quyền truy cập vị trí từ hệ điều hành
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

  // Hàm lấy vị trí GPS hiện tại của thiết bị, chuyển đổi sang địa chỉ, lưu vào state
  Future<bool> getCurrentLocation() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _logger.info('Đang lấy vị trí hiện tại...');

      // Kiểm tra quyền trước khi lấy vị trí
      final hasPermission = await _locationService.requestLocationPermission();
      if (!hasPermission) {
        _error = 'Không có quyền truy cập vị trí';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Lấy vị trí GPS
      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        _error = 'Không thể lấy vị trí hiện tại';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Lưu tọa độ vào state
      _latitude = position.latitude;
      _longitude = position.longitude;

      // Chuyển đổi tọa độ sang địa chỉ (address, city, country)
      final addressData = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      _address = addressData['address'];
      _city = addressData['city'];
      _country = addressData['country'];
      _currentLocation = _address ?? _city ?? 'Không xác định';

      _logger.info('Đã lấy vị trí: $_currentLocation');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _logger.severe('Lỗi khi lấy vị trí: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Hàm cập nhật vị trí hiện tại của user lên Firestore
  Future<bool> updateUserLocation(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _logger.info('Đang cập nhật location cho user: $userId');

      // Lấy dữ liệu vị trí từ service
      final locationData = await _locationService.getLocationData();
      if (locationData == null) {
        _error = 'Không thể lấy dữ liệu vị trí';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Cập nhật dữ liệu vị trí lên Firestore
      await _firestoreService.updateUserLocation(userId, locationData);

      // Cập nhật lại state local
      _latitude = locationData['latitude'];
      _longitude = locationData['longitude'];
      _address = locationData['address'];
      _city = locationData['city'];
      _country = locationData['country'];
      _currentLocation = _address ?? _city ?? 'Không xác định';

      _logger.info('Đã cập nhật location thành công');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _logger.severe('Lỗi khi cập nhật location: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Hàm load các cài đặt matching từ UserModel khi đăng nhập
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
    _currentLocation = user.address ?? user.city ?? user.location;
    notifyListeners();
  }

  // Hàm cập nhật khoảng cách tối đa matching
  void setMaxDistance(double distance) {
    _maxDistance = distance;
    notifyListeners();
  }

  // Hàm cập nhật trạng thái hiển thị khoảng cách
  void setShowDistance(bool value) {
    _showDistance = value;
    notifyListeners();
  }

  // Hàm cập nhật tuổi tối thiểu matching
  void setMinAge(int age) {
    _minAge = age;
    notifyListeners();
  }

  // Hàm cập nhật tuổi tối đa matching
  void setMaxAge(int age) {
    _maxAge = age;
    notifyListeners();
  }

  // Hàm cập nhật giới tính mong muốn khi matching
  void setInterestedInGender(String gender) {
    _interestedInGender = gender;
    notifyListeners();
  }

  // Hàm lưu các cài đặt matching lên Firestore cho user
  Future<bool> saveSettings(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _logger.info('Đang lưu settings...');

      await _firestoreService.updateLocationSettings(
        userId,
        maxDistance: _maxDistance,
        showDistance: _showDistance,
        minAge: _minAge,
        maxAge: _maxAge,
        interestedInGender: _interestedInGender,
      );

      _logger.info('Đã lưu settings thành công');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _logger.severe('Lỗi khi lưu settings: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Hàm tính khoảng cách từ vị trí hiện tại đến vị trí của user khác
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

  // Hàm format khoảng cách thành chuỗi để hiển thị
  String formatDistance(double distanceInKm) {
    return _locationService.formatDistance(distanceInKm);
  }

  // Hàm kiểm tra user khác có nằm trong bán kính matching không
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

  // Hàm reset lại toàn bộ state về mặc định
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
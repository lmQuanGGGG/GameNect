import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:logging/logging.dart';

/// Service xử lý location như Tinder
class LocationService {

  final Logger _logger = Logger('LocationService');
  
  /// Kiểm tra trạng thái quyền truy cập vị trí
  Future<bool> checkLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
             permission == LocationPermission.whileInUse;
    } catch (e, st) {
      _logger.severe('Lỗi khi kiểm tra quyền vị trí: $e', e, st);
      return false;
    }
  }
  
  /// Xin quyền truy cập vị trí
  Future<bool> requestLocationPermission() async {
    try {
      _logger.info('Đang kiểm tra quyền hiện tại...');
      
      LocationPermission permission = await Geolocator.checkPermission();
      
      _logger.fine('Quyền hiện tại: $permission');

      if (permission == LocationPermission.denied) {
        _logger.info('Chưa có quyền, đang yêu cầu...');
        permission = await Geolocator.requestPermission();
        _logger.fine('Sau khi yêu cầu: $permission');
      }

      if (permission == LocationPermission.deniedForever) {
        _logger.warning('Quyền bị từ chối vĩnh viễn, mở settings...');
        await Geolocator.openLocationSettings();
        return false;
      }

      if (permission == LocationPermission.denied) {
        _logger.warning('Quyền vẫn bị từ chối');
        return false;
      }

      _logger.info('Đã có quyền truy cập vị trí!');
      return true;
    } catch (e, st) {
      _logger.severe('Lỗi khi xin quyền vị trí: $e', e, st);
      return false;
    }
  }
  
  /// Kiểm tra location service có bật không
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  /// Lấy vị trí hiện tại của user
  Future<Position?> getCurrentLocation() async {
    try {
      // Kiểm tra quyền
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        _logger.info('Chưa có quyền, đang yêu cầu...');
        final granted = await requestLocationPermission();
        if (!granted) {
          _logger.warning('Không được cấp quyền');
          return null;
        }
      }
      
      // Kiểm tra location service
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.warning('Dịch vụ vị trí chưa được bật');
        return null;
      }
      
      // Lấy vị trí hiện tại
      _logger.info('Đang lấy vị trí hiện tại...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      _logger.info('Đã lấy được vị trí: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e, st) {
      _logger.severe('Lỗi khi lấy vị trí: $e', e, st);
      return null;
    }
  }
  
  /// Chuyển đổi tọa độ thành địa chỉ
  Future<Map<String, String?>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      _logger.info('Đang chuyển đổi tọa độ thành địa chỉ...');
      
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isEmpty) {
        return {
          'address': null,
          'city': null,
          'country': null,
        };
      }
      
      final place = placemarks.first;
      
      // Tạo địa chỉ CHỈ đến phường (không có số nhà/đường)
      final addressParts = [
        place.subLocality,  // Phường
        place.locality,      // Quận
      ].where((part) => part != null && part.isNotEmpty).toList();
      
      final fullAddress = addressParts.join(', ');
      
      _logger.fine('Địa chỉ: $fullAddress');
      
      return {
        'address': fullAddress,
        'city': place.locality ?? place.administrativeArea,
        'country': place.country,
      };
    } catch (e, st) {
      _logger.severe('Lỗi khi chuyển đổi địa chỉ: $e', e, st);
      return {
        'address': null,
        'city': null,
        'country': null,
      };
    }
  }
  
  /// Tính khoảng cách giữa 2 điểm (km)
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    // Sử dụng Haversine formula
    final distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distanceInMeters / 1000; // Chuyển sang km
  }
  
  /// Format khoảng cách để hiển thị
  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      // Dưới 1km thì hiển thị mét
      return '${(distanceInKm * 1000).round()} m';
    } else if (distanceInKm < 100) {
      // Dưới 100km thì làm tròn 1 chữ số
      return '${distanceInKm.toStringAsFixed(1)} km';
    } else {
      // Trên 100km thì làm tròn số nguyên
      return '${distanceInKm.round()} km';
    }
  }
  
  /// Kiểm tra user có trong bán kính matching không
  bool isWithinMatchingRadius({
    required double userLat,
    required double userLon,
    required double targetLat,
    required double targetLon,
    required double maxDistanceKm,
  }) {
    final distance = calculateDistance(
      lat1: userLat,
      lon1: userLon,
      lat2: targetLat,
      lon2: targetLon,
    );
    
    return distance <= maxDistanceKm;
  }
  
  /// Lấy đầy đủ thông tin vị trí
  Future<Map<String, dynamic>?> getLocationData() async {
    try {
      // Lấy vị trí hiện tại
      final position = await getCurrentLocation();
      if (position == null) return null;
      
      // Chuyển đổi thành địa chỉ
      final addressData = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': addressData['address'],
        'city': addressData['city'],
        'country': addressData['country'],
        'location': addressData['city'] ?? 'Không xác định',
        'lastLocationUpdate': DateTime.now().toIso8601String(),
      };
    } catch (e, st) {
      _logger.severe('Lỗi khi lấy dữ liệu vị trí: $e', e, st);
      return null;
    }
  }
  
  /// Theo dõi thay đổi vị trí theo thời gian thực
  Stream<Position> getLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100, // Cập nhật khi di chuyển 100m
    );
    
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
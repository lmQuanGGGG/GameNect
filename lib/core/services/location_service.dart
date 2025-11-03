import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:logging/logging.dart';

// Service xử lý location như Tinder
// Quản lý các chức năng liên quan đến vị trí địa lý của người dùng
// Bao gồm xin quyền, lấy tọa độ, chuyển đổi địa chỉ, tính khoảng cách
class LocationService {

  // Khởi tạo logger để ghi log các hoạt động của service
  // Giúp theo dõi và debug các vấn đề liên quan đến location
  final Logger _logger = Logger('LocationService');
  
  // Kiểm tra trạng thái quyền truy cập vị trí
  // Trả về true nếu đã có quyền always hoặc whileInUse
  // Trả về false nếu chưa có quyền hoặc bị từ chối
  Future<bool> checkLocationPermission() async {
    try {
      // Gọi API Geolocator để kiểm tra quyền hiện tại
      LocationPermission permission = await Geolocator.checkPermission();
      // Chỉ chấp nhận quyền always hoặc whileInUse
      // Hai loại quyền này đều cho phép ứng dụng truy cập vị trí
      return permission == LocationPermission.always ||
             permission == LocationPermission.whileInUse;
    } catch (e, st) {
      // Bắt lỗi nếu không thể kiểm tra quyền
      // Ghi log với mức severe kèm stack trace để debug
      _logger.severe('Lỗi khi kiểm tra quyền vị trí: $e', e, st);
      return false;
    }
  }
  
  // Xin quyền truy cập vị trí từ người dùng
  // Trả về true nếu người dùng cấp quyền
  // Trả về false nếu bị từ chối hoặc có lỗi
  Future<bool> requestLocationPermission() async {
    try {
      _logger.info('Đang kiểm tra quyền hiện tại...');
      
      // Kiểm tra quyền hiện tại trước khi yêu cầu
      LocationPermission permission = await Geolocator.checkPermission();
      
      _logger.fine('Quyền hiện tại: $permission');

      // Nếu quyền đang ở trạng thái denied thì yêu cầu lại
      // Denied nghĩa là người dùng chưa cấp quyền hoặc từ chối trước đó
      if (permission == LocationPermission.denied) {
        _logger.info('Chưa có quyền, đang yêu cầu...');
        // Hiển thị dialog xin quyền cho người dùng
        permission = await Geolocator.requestPermission();
        _logger.fine('Sau khi yêu cầu: $permission');
      }

      // Nếu quyền bị từ chối vĩnh viễn thì mở settings
      // DeniedForever nghĩa là người dùng đã chọn không cho phép vĩnh viễn
      // Lúc này chỉ có thể vào settings của hệ thống để bật lại
      if (permission == LocationPermission.deniedForever) {
        _logger.warning('Quyền bị từ chối vĩnh viễn, mở settings...');
        // Mở settings để người dùng tự bật quyền
        await Geolocator.openLocationSettings();
        return false;
      }

      // Nếu vẫn bị denied sau khi yêu cầu thì trả về false
      if (permission == LocationPermission.denied) {
        _logger.warning('Quyền vẫn bị từ chối');
        return false;
      }

      // Nếu đến đây nghĩa là đã có quyền
      _logger.info('Đã có quyền truy cập vị trí!');
      return true;
    } catch (e, st) {
      // Bắt lỗi nếu quá trình xin quyền gặp vấn đề
      _logger.severe('Lỗi khi xin quyền vị trí: $e', e, st);
      return false;
    }
  }
  
  // Kiểm tra location service có bật không
  // Location service là GPS hoặc dịch vụ định vị trên thiết bị
  // Trả về true nếu đang bật, false nếu tắt
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  // Lấy vị trí hiện tại của user
  // Trả về Position chứa tọa độ latitude longitude
  // Trả về null nếu không lấy được do thiếu quyền hoặc lỗi
  Future<Position?> getCurrentLocation() async {
    try {
      // Kiểm tra quyền trước khi lấy vị trí
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        _logger.info('Chưa có quyền, đang yêu cầu...');
        // Nếu chưa có quyền thì yêu cầu quyền
        final granted = await requestLocationPermission();
        if (!granted) {
          // Nếu không được cấp quyền thì dừng lại
          _logger.warning('Không được cấp quyền');
          return null;
        }
      }
      
      // Kiểm tra location service có bật không
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Nếu GPS tắt thì không thể lấy vị trí
        _logger.warning('Dịch vụ vị trí chưa được bật');
        return null;
      }
      
      // Lấy vị trí hiện tại với độ chính xác cao
      _logger.info('Đang lấy vị trí hiện tại...');
      final position = await Geolocator.getCurrentPosition(
        // Sử dụng độ chính xác cao để có tọa độ chính xác nhất
        desiredAccuracy: LocationAccuracy.high,
        // Giới hạn thời gian 10 giây để tránh treo ứng dụng
        timeLimit: const Duration(seconds: 10),
      );
      
      // Ghi log tọa độ vừa lấy được
      _logger.info('Đã lấy được vị trí: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e, st) {
      // Bắt lỗi nếu không lấy được vị trí
      _logger.severe('Lỗi khi lấy vị trí: $e', e, st);
      return null;
    }
  }
  
  // Chuyển đổi tọa độ thành địa chỉ con người đọc được
  // Nhận vào latitude và longitude
  // Trả về Map chứa address city country
  Future<Map<String, String?>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      _logger.info('Đang chuyển đổi tọa độ thành địa chỉ...');
      
      // Gọi API geocoding để chuyển tọa độ thành placemark
      // Placemark chứa các thông tin địa chỉ chi tiết
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      // Nếu không tìm thấy địa chỉ nào thì trả về null
      if (placemarks.isEmpty) {
        return {
          'address': null,
          'city': null,
          'country': null,
        };
      }
      
      // Lấy placemark đầu tiên vì thường là chính xác nhất
      final place = placemarks.first;
      
      // Tạo địa chỉ CHỈ đến phường để bảo vệ privacy
      // Không hiển thị số nhà và tên đường để tránh lộ vị trí chính xác
      final addressParts = [
        place.subLocality,  // Phường hoặc khu vực nhỏ
        place.locality,      // Quận hoặc thành phố nhỏ
      ].where((part) => part != null && part.isNotEmpty).toList();
      
      // Ghép các phần địa chỉ bằng dấu phẩy
      final fullAddress = addressParts.join(', ');
      
      _logger.fine('Địa chỉ: $fullAddress');
      
      // Trả về Map chứa địa chỉ thành phố và quốc gia
      return {
        'address': fullAddress,
        // City ưu tiên locality nếu không có thì dùng administrativeArea
        'city': place.locality ?? place.administrativeArea,
        'country': place.country,
      };
    } catch (e, st) {
      // Bắt lỗi nếu không thể chuyển đổi địa chỉ
      _logger.severe('Lỗi khi chuyển đổi địa chỉ: $e', e, st);
      // Trả về Map với các giá trị null
      return {
        'address': null,
        'city': null,
        'country': null,
      };
    }
  }
  
  // Tính khoảng cách giữa 2 điểm trên bản đồ
  // Nhận vào tọa độ của 2 điểm
  // Trả về khoảng cách tính bằng km
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    // Sử dụng Haversine formula để tính khoảng cách chính xác trên mặt cầu Trái Đất
    // Geolocator tự động tính toán theo công thức này
    final distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    // Chuyển từ mét sang km bằng cách chia cho 1000
    return distanceInMeters / 1000;
  }
  
  // Format khoảng cách để hiển thị cho người dùng
  // Tự động chọn đơn vị phù hợp là mét hoặc km
  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      // Dưới 1km thì hiển thị bằng mét cho dễ đọc
      // Làm tròn thành số nguyên và thêm đơn vị m
      return '${(distanceInKm * 1000).round()} m';
    } else if (distanceInKm < 100) {
      // Dưới 100km thì hiển thị 1 chữ số thập phân
      // Ví dụ 5.3 km để chính xác hơn
      return '${distanceInKm.toStringAsFixed(1)} km';
    } else {
      // Trên 100km thì làm tròn số nguyên
      // Ví dụ 150 km không cần chữ số thập phân
      return '${distanceInKm.round()} km';
    }
  }
  
  // Kiểm tra user có trong bán kính matching không
  // Dùng để filter các đề xuất match theo khoảng cách
  // Trả về true nếu trong bán kính, false nếu ngoài
  bool isWithinMatchingRadius({
    required double userLat,
    required double userLon,
    required double targetLat,
    required double targetLon,
    required double maxDistanceKm,
  }) {
    // Tính khoảng cách giữa user và target
    final distance = calculateDistance(
      lat1: userLat,
      lon1: userLon,
      lat2: targetLat,
      lon2: targetLon,
    );
    
    // So sánh với bán kính tối đa cho phép
    return distance <= maxDistanceKm;
  }
  
  // Lấy đầy đủ thông tin vị trí bao gồm tọa độ và địa chỉ
  // Trả về Map chứa tất cả thông tin location
  // Trả về null nếu không lấy được vị trí
  Future<Map<String, dynamic>?> getLocationData() async {
    try {
      // Lấy vị trí hiện tại trước
      final position = await getCurrentLocation();
      if (position == null) return null;
      
      // Chuyển đổi tọa độ thành địa chỉ con người đọc được
      final addressData = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      // Trả về Map chứa đầy đủ thông tin
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': addressData['address'],
        'city': addressData['city'],
        'country': addressData['country'],
        // location là tên thành phố để hiển thị
        'location': addressData['city'] ?? 'Không xác định',
        // Lưu thời gian cập nhật vị trí để biết độ mới của dữ liệu
        'lastLocationUpdate': DateTime.now().toIso8601String(),
      };
    } catch (e, st) {
      // Bắt lỗi nếu không lấy được dữ liệu vị trí
      _logger.severe('Lỗi khi lấy dữ liệu vị trí: $e', e, st);
      return null;
    }
  }
  
  // Theo dõi thay đổi vị trí theo thời gian thực
  // Trả về Stream để lắng nghe vị trí mới khi user di chuyển
  // Dùng để cập nhật vị trí liên tục khi người dùng đang di chuyển
  Stream<Position> getLocationStream() {
    // Cấu hình settings cho stream
    const locationSettings = LocationSettings(
      // Sử dụng độ chính xác cao để tracking chính xác
      accuracy: LocationAccuracy.high,
      // Chỉ cập nhật khi di chuyển 100m để tránh cập nhật quá nhiều
      // Giúp tiết kiệm pin và giảm số lần gọi API
      distanceFilter: 100,
    );
    
    // Trả về stream theo dõi vị trí
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
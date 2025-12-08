import 'dart:async';

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

  /// Lấy vị trí hiện tại của user - TỐI ƯU CHO ANDROID
  Future<Position?> getCurrentLocation() async {
    Position? lastKnownPosition;

    try {
      _logger.info(' ========== BẮT ĐẦU LẤY VỊ TRÍ ==========');

      // BƯỚC 1: KIỂM TRA GPS CÓ BẬT KHÔNG (QUAN TRỌNG!)
      _logger.info(' [1/5] Kiểm tra GPS...');
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.warning(' GPS chưa bật, mở settings...');
        await Geolocator.openLocationSettings();
        throw Exception('Vui lòng bật GPS rồi thử lại');
      }
      _logger.info('[1/5] GPS đã bật');

      // BƯỚC 2: KIỂM TRA QUYỀN (KHÔNG XIN QUYỀN Ở ĐÂY)
      _logger.info(' [2/5] Kiểm tra quyền...');
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        _logger.warning(' Chưa có quyền location');
        throw Exception('Vui lòng cấp quyền truy cập vị trí');
      }
      _logger.info('[2/5] Đã có quyền');

      // BƯỚC 3: LẤY LAST KNOWN POSITION (NHANH)
      _logger.info(' [3/5] Lấy last known position...');
      try {
        lastKnownPosition = await Geolocator.getLastKnownPosition();
        if (lastKnownPosition != null) {
          final age = DateTime.now().difference(lastKnownPosition.timestamp!);
          _logger.info(
            ' [3/5] Có last known: (${lastKnownPosition.latitude}, ${lastKnownPosition.longitude}), cách đây ${age.inMinutes} phút',
          );

          // Nếu last known còn mới (< 10 phút) thì dùng luôn
          if (age.inMinutes < 10) {
            _logger.info(' Last known còn mới, dùng ngay!');
            return lastKnownPosition;
          }
        } else {
          _logger.info(' [3/5] Không có last known position');
        }
      } catch (e) {
        _logger.warning(' [3/5] Lỗi lấy last known: $e');
      }

      // BƯỚC 4: LẤY VỊ TRÍ MỚI - 3 LEVELS ACCURACY
      _logger.info(' [4/5] Lấy vị trí GPS mới...');
      Position? currentPosition;

      // TRY 1: HIGH accuracy
      try {
        _logger.info(' [4a] Thử HIGH accuracy (30s)...');
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        );
        _logger.info(
          ' [4a] HIGH OK: (${currentPosition.latitude}, ${currentPosition.longitude})',
        );
        return currentPosition;
      } on TimeoutException {
        _logger.warning(' [4a] HIGH timeout');
      } catch (e) {
        _logger.warning(' [4a] HIGH error: $e');
      }

      // TRY 2: MEDIUM accuracy
      try {
        _logger.info('[4b] Thử MEDIUM accuracy (30s)...');
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 30),
        );
        _logger.info(
          '[4b] MEDIUM OK: (${currentPosition.latitude}, ${currentPosition.longitude})',
        );
        return currentPosition;
      } on TimeoutException {
        _logger.warning('4b] MEDIUM timeout');
      } catch (e) {
        _logger.warning('[4b] MEDIUM error: $e');
      }

      // TRY 3: LOW accuracy
      try {
        _logger.info('[4c] Thử LOW accuracy (30s)...');
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 30),
        );
        _logger.info(
          '[4c] LOW OK: (${currentPosition.latitude}, ${currentPosition.longitude})',
        );
        return currentPosition;
      } on TimeoutException {
        _logger.warning('[4c] LOW timeout');
      } catch (e) {
        _logger.warning('[4c] LOW error: $e');
      }

      // BƯỚC 5: FALLBACK VỀ LAST KNOWN (nếu tất cả đều fail)
      if (lastKnownPosition != null) {
        _logger.info(' [5/5] Fallback về last known position');
        return lastKnownPosition;
      }

      _logger.severe('Không lấy được vị trí sau 3 lần thử!');
      throw Exception('Không thể lấy vị trí. Vui lòng kiểm tra GPS và thử lại');
    } catch (e, st) {
      _logger.severe(' Lỗi: $e', e, st);

      // Fallback cuối cùng: trả về last known nếu có
      if (lastKnownPosition != null) {
        _logger.info(' Fallback về last known do lỗi');
        return lastKnownPosition;
      }

      return null;
    } finally {
      _logger.info(' ========== KẾT THÚC ==========');
    }
  }

  /// Chuyển đổi tọa độ thành địa chỉ - HIỂN THỊ ĐẦY ĐỦ
  Future<Map<String, String?>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      _logger.info(' Đang geocoding ($latitude, $longitude)...');

      final placemarks =
          await placemarkFromCoordinates(
            latitude,
            longitude,
            localeIdentifier: 'vi_VN', // Tiếng Việt
          ).timeout(
            Duration(seconds: 15),
            onTimeout: () {
              _logger.warning(' Geocoding timeout');
              return [];
            },
          );

      if (placemarks.isEmpty) {
        _logger.warning(' Không tìm thấy địa chỉ');
        return {'address': 'Vị trí hiện tại', 'city': null, 'country': null};
      }

      final place = placemarks.first;

      //  TẠO ĐỊA CHỈ ĐẦY ĐỦ: Phường + Quận + Thành phố
      final addressParts = <String>[];

      // 1. Phường/Xã (subLocality)
      if (place.subLocality != null && place.subLocality!.isNotEmpty) {
        addressParts.add(place.subLocality!);
      }

      // 2. Quận/Huyện (subAdministrativeArea)
      if (place.subAdministrativeArea != null &&
          place.subAdministrativeArea!.isNotEmpty) {
        addressParts.add(place.subAdministrativeArea!);
      }

      // 3. Thành phố/Tỉnh (locality hoặc administrativeArea)
      String? cityPart = place.locality;
      if (cityPart == null || cityPart.isEmpty) {
        cityPart = place.administrativeArea;
      }
      if (cityPart != null && cityPart.isNotEmpty) {
        addressParts.add(cityPart);
      }

      // Ghép thành địa chỉ đầy đủ
      final fullAddress = addressParts.join(', ');

      _logger.info(' Địa chỉ đầy đủ: $fullAddress');

      // FALLBACK CHO CITY (Android thường locality null)
      String? city = place.locality;
      if (city == null || city.isEmpty) {
        city = place.administrativeArea;
        _logger.info('locality null, dùng administrativeArea: $city');
      }
      if (city == null || city.isEmpty) {
        city = place.subAdministrativeArea;
        _logger.info(
          'administrativeArea null, dùng subAdministrativeArea: $city',
        );
      }
      if (city == null || city.isEmpty) {
        city = 'Việt Nam';
        _logger.info(' Tất cả null, dùng fallback: $city');
      }

      return {
        'address': fullAddress.isNotEmpty ? fullAddress : 'Vị trí hiện tại',
        'city': city,
        'country': place.country ?? 'Việt Nam',
      };
    } catch (e, st) {
      _logger.severe(' Lỗi geocoding: $e', e, st);
      return {'address': 'Vị trí hiện tại', 'city': null, 'country': null};
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

  // Lấy đầy đủ thông tin vị trí - TRẢ VỀ ĐỊA CHỈ ĐẦY ĐỦ
  Future<Map<String, dynamic>?> getLocationData() async {
    try {
      final position = await getCurrentLocation();
      if (position == null) {
        // ✅ FALLBACK: Trả về vị trí mặc định thay vì null
        _logger.warning('⚠️ Không lấy được GPS, dùng vị trí mặc định');
        return {
          'latitude': 21.028511,
          'longitude': 105.804817,
          'address': 'Hà Nội',
          'city': 'Hà Nội',
          'country': 'Việt Nam',
          'location': 'Hà Nội, Việt Nam',
          'lastLocationUpdate': DateTime.now().toIso8601String(),
        };
      }

      final addressData = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': addressData['address'], // Địa chỉ ĐẦY ĐỦ: Phường, Quận, TP
        'city': addressData['city'],
        'country': addressData['country'],
        'location':
            addressData['address'] ??
            addressData['city'] ??
            'Vị trí hiện tại', // Ưu tiên address đầy đủ
        'lastLocationUpdate': DateTime.now().toIso8601String(),
      };
    } catch (e, st) {
      _logger.severe('Lỗi getLocationData: $e', e, st);

      //  FALLBACK cuối cùng
      return {
        'latitude': 21.028511,
        'longitude': 105.804817,
        'address': 'Hà Nội',
        'city': 'Hà Nội',
        'country': 'Việt Nam',
        'location': 'Hà Nội, Việt Nam',
        'lastLocationUpdate': DateTime.now().toIso8601String(),
      };
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

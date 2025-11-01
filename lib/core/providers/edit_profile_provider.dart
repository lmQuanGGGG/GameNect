import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

// Lớp EditProfileProvider quản lý logic lấy dữ liệu cấu hình cho màn hình chỉnh sửa hồ sơ người dùng.
// Bao gồm các lựa chọn như rank, giới tính, phong cách chơi game, mục tiêu tìm kiếm, sở thích.
// Sử dụng ChangeNotifier để cập nhật giao diện khi dữ liệu thay đổi.
// Sử dụng Logger để ghi log quá trình lấy dữ liệu và lỗi.

class EditProfileProvider extends ChangeNotifier {
  // Logger dùng để ghi log thông tin và lỗi trong quá trình xử lý.
  final Logger _logger = Logger('EditProfileProvider');

  // Biến trạng thái loading khi đang lấy dữ liệu từ Firestore.
  bool _isLoading = true;
  // Biến lưu lỗi nếu có lỗi xảy ra khi lấy dữ liệu.
  String? _error;

  // Các danh sách lựa chọn lấy từ Firestore, dùng cho các trường trong hồ sơ.
  List<String> _rankOptions = [];
  List<String> _genderOptions = [];
  List<String> _gameStyleOptions = [];
  List<String> _lookingForOptions = [];
  List<String> _interestOptions = [];

  // Các getter để truy cập dữ liệu từ bên ngoài.
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get rankOptions => _rankOptions;
  List<String> get genderOptions => _genderOptions;
  List<String> get gameStyleOptions => _gameStyleOptions;
  List<String> get lookingForOptions => _lookingForOptions;
  List<String> get interestOptions => _interestOptions;

  // Hàm khởi tạo dữ liệu cấu hình từ Firestore.
  // Lấy các lựa chọn cho từng trường theo ngôn ngữ langCode (mặc định là 'vi').
  Future<void> initialize({String langCode = 'vi'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Lấy dữ liệu các lựa chọn từ Firestore cho từng trường.
      await Future.wait([
        _loadOptionsFromFirestore(
          'rankOptions',
          langCode,
          (data) => _rankOptions = data,
        ),
        _loadOptionsFromFirestore(
          'genderOptions',
          langCode,
          (data) => _genderOptions = data,
        ),
        _loadOptionsFromFirestore(
          'gameStyleOptions',
          langCode,
          (data) => _gameStyleOptions = data,
        ),
        _loadOptionsFromFirestore(
          'lookingForOptions',
          langCode,
          (data) => _lookingForOptions = data,
        ),
        _loadOptionsFromFirestore(
          'interestOptions',
          langCode,
          (data) => _interestOptions = data,
        ),
      ]);

      // Ghi log các lựa chọn đã lấy được.
      _logger.info('Loaded options:');
      _logger.info('Ranks: $_rankOptions');
      _logger.info('Genders: $_genderOptions');
      _logger.info('Game Styles: $_gameStyleOptions');
      _logger.info('Looking For: $_lookingForOptions');
      _logger.info('Interests: $_interestOptions');
    } catch (e) {
      // Nếu có lỗi, lưu lỗi và ghi log lỗi.
      _error = e.toString();
      _logger.severe('Error loading options: $_error');
    } finally {
      // Kết thúc quá trình loading, thông báo cho giao diện cập nhật lại.
      _isLoading = false;
      notifyListeners();
    }
  }

  // Hàm lấy dữ liệu lựa chọn cho từng trường từ Firestore.
  // docName là tên document trong collection 'configurations'.
  // langCode là mã ngôn ngữ để lấy dữ liệu đúng ngôn ngữ.
  // onData là hàm callback để gán dữ liệu vào biến tương ứng.
  Future<void> _loadOptionsFromFirestore(
    String docName,
    String langCode,
    Function(List<String>) onData,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configurations')
          .doc(docName)
          .get();

      final data = doc.data();
      if (data != null && data['values'] is List) {
        // Lấy danh sách các lựa chọn, mỗi lựa chọn là một map chứa các ngôn ngữ.
        final rawList = List<Map<String, dynamic>>.from(data['values']);
        // Lấy đúng ngôn ngữ theo langCode, nếu không có thì lấy tiếng Việt.
        final localizedList = rawList
            .map((item) => item[langCode] ?? item['vi'])
            .whereType<String>() // Lọc ra đúng kiểu String
            .toList();

        onData(localizedList);
      }
    } catch (e) {
      // Nếu có lỗi, ghi log lỗi và lưu thông báo lỗi để hiển thị cho người dùng.
      _logger.severe('Error loading $docName: $e');
      _error = 'Lỗi khi tải $docName: $e';
    }
  }
}

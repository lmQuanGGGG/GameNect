import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import 'location_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  LocationProvider? _locationProvider; // Làm optional

  bool _isLoading = false;
  String? _error;
  String? _verificationId;
  bool _isVerifying = false;

  // Constructor với optional parameter
  AuthProvider([this._locationProvider]);

  // Method để inject LocationProvider sau
  void setLocationProvider(LocationProvider locationProvider) {
    _locationProvider = locationProvider;
  }

  Future<void> _updateLocationAfterAuth(String userId) async {
    final provider = _locationProvider;
    if (provider == null) return;

    if (kIsWeb) {
      Future<void>(() async {
        await provider.updateUserLocation(userId);
      });
      return;
    }

    await provider.updateUserLocation(userId);
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isVerifying => _isVerifying;

  /// Đăng nhập với Google và lấy location
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. Đăng nhập Google
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        // 2. Lấy và cập nhật vị trí (nếu có LocationProvider)
        await _updateLocationAfterAuth(user.uid);

        return true;
      }

      return false;
    } catch (e) {
      _error = _getReadableErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Đăng nhập với Facebook và lấy location
  /*Future<bool> signInWithFacebook() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. Đăng nhập Facebook
      final user = await _authService.signInWithFacebook();
      
      if (user != null) {
        // 2. Lấy và cập nhật vị trí (nếu có LocationProvider)
        await _updateLocationAfterAuth(user.uid);
        
        return true;
      }
      
      return false;
    } catch (e) {
      _error = _getReadableErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }*/

  /// Đăng ký với Email/Password
  Future<bool> signUpWithEmailPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. Đăng ký với Email/Password
      final user = await _authService.signUpWithEmailPassword(email, password);

      if (user != null) {
        // 2. Lấy và cập nhật vị trí (nếu có LocationProvider)
        await _updateLocationAfterAuth(user.uid);

        return true;
      }

      return false;
    } catch (e) {
      _error = _getReadableErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Đăng nhập với Email/Password
  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. Đăng nhập với Email/Password
      final user = await _authService.signInWithEmailPassword(email, password);

      if (user != null) {
        // 2. Lấy và cập nhật vị trí (nếu có LocationProvider)
        await _updateLocationAfterAuth(user.uid);

        return true;
      }

      return false;
    } catch (e) {
      _error = _getReadableErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Xác thực OTP và lấy location
  Future<bool> verifyOTP(String otp) async {
    if (_verificationId == null) {
      _error = 'Chưa gửi mã OTP hoặc mã đã hết hạn';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. Xác thực OTP
      final user = await _authService.verifyOTP(_verificationId!, otp);

      if (user != null) {
        _isVerifying = false;
        _verificationId = null;

        // 2. Lấy và cập nhật vị trí (nếu có LocationProvider)
        await _updateLocationAfterAuth(user.uid);

        return true;
      }

      return false;
    } catch (e) {
      _error = _getReadableErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Gửi mã OTP
  Future<bool> sendOTP(String phoneNumber) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _verificationId = await _authService.verifyPhoneNumber(phoneNumber);
      _isVerifying = true;
      return true;
    } catch (e) {
      _error = _getReadableErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set verifying state
  void setVerifying(bool value) {
    _isVerifying = value;
    notifyListeners();
  }

  /// Reset verification
  void resetVerification() {
    _isVerifying = false;
    _verificationId = null;
    _error = null;
    notifyListeners();
  }

  /// Đăng xuất
  Future<void> signOut() async {
    await _authService.signOut();
    _locationProvider?.reset(); // Reset location data nếu có
    notifyListeners();
  }

  /// Helper format lỗi thân thiện với người dùng
  String _getReadableErrorMessage(Object e) {
    final errorString = e.toString();
    if (errorString.contains('user-not-found')) {
      return 'Không tìm thấy tài khoản. Vui lòng kiểm tra lại.';
    } else if (errorString.contains('wrong-password')) {
      return 'Sai mật khẩu. Vui lòng thử lại.';
    } else if (errorString.contains('email-already-in-use')) {
      return 'Email này đã được đăng ký cho một tài khoản khác.';
    } else if (errorString.contains('invalid-email')) {
      return 'Địa chỉ email không hợp lệ.';
    } else if (errorString.contains('weak-password')) {
      return 'Mật khẩu quá yếu. Vui lòng chọn mật khẩu từ 6 ký tự trở lên.';
    } else if (errorString.contains('invalid-credential')) {
      return 'Thông tin đăng nhập không chính xác hoặc đã hết hạn.';
    } else if (errorString.contains('network-request-failed')) {
      return 'Lỗi mạng. Vui lòng kiểm tra lại kết nối Internet.';
    } else if (errorString.contains('too-many-requests')) {
      return 'Thử quá nhiều lần. Vui lòng chờ một lát rồi thử lại.';
    } else if (errorString.contains('invalid-verification-code')) {
      return 'Mã OTP không chính xác hoặc đã hết hạn.';
    } else if (errorString.contains('invalid-phone-number')) {
      return 'Số điện thoại không hợp lệ.';
    } else if (errorString.contains('session-expired')) {
      return 'Phiên xác thực đã hết hạn. Vui lòng gửi lại mã OTP.';
    }
    return 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
  }
}

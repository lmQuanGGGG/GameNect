import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _error;
  String? _verificationId;
  bool _isVerifying = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isVerifying => _isVerifying;

  // Thêm method setVerifying
  void setVerifying(bool value) {
    _isVerifying = value;
    notifyListeners();
  }

  // Gửi mã OTP
  Future<bool> sendOTP(String phoneNumber) async {
    try {
      _isLoading = true;
      _error = null;
      _isVerifying = false;
      notifyListeners();

      // Gọi service gửi OTP
      _verificationId = await _authService.verifyPhoneNumber(
        phoneNumber,
        onTimeout: () {
          // Khi OTP hết hạn → reset
          resetVerification();
          _error = "Mã OTP đã hết hạn, vui lòng yêu cầu lại.";
          notifyListeners();
        },
      );

      if (_verificationId != null) {
        _isVerifying = true;
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Xác thực OTP
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

      final user = await _authService.verifyOTP(_verificationId!, otp);
      _isVerifying = false;
      _verificationId = null;
      return user != null;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset trạng thái (khi OTP hết hạn hoặc user bấm gửi lại)
  void resetVerification() {
    _isVerifying = false;
    _verificationId = null;
    _error = null;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signInWithGoogle();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithFacebook() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signInWithFacebook();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signOut();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'dart:async';
import 'package:logging/logging.dart'; // { changed code }

// Quản lý số lần gửi OTP
class OTPAttempt {
  int attempts;
  DateTime? lastAttempt;

  OTPAttempt({
    this.attempts = 0,
    this.lastAttempt,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger('AuthService'); // { changed code }

  // Biến theo dõi OTP
  final Map<String, OTPAttempt> _otpAttempts = {};
  static const int MAX_OTP_ATTEMPTS = 3; // Giới hạn số lần gửi OTP
  static const int COOLDOWN_DURATION = 300; // 5 phút cooldown

  int? _resendToken; // token để resend OTP

  Future<bool> checkAuthState() async {
    await FirebaseAuth.instance.authStateChanges().first;
    return _auth.currentUser != null;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Đăng nhập Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      _logger.info('Đăng nhập Google thành công: ${userCredential.user?.uid}'); // { changed code }
      return userCredential.user;
    } catch (e) {
      _logger.severe('Lỗi đăng nhập Google: $e'); // { changed code }
      return null;
    }
  }

  // Đăng nhập Facebook
  Future<User?> signInWithFacebook() async {
    try {
      final LoginResult loginResult = await FacebookAuth.instance.login();
      if (loginResult.status != LoginStatus.success) return null;

      final OAuthCredential facebookAuthCredential =
          FacebookAuthProvider.credential(loginResult.accessToken!.tokenString);
      final UserCredential userCredential =
          await _auth.signInWithCredential(facebookAuthCredential);
      _logger.info('Đăng nhập Facebook thành công: ${userCredential.user?.uid}'); // { changed code }
      return userCredential.user;
    } catch (e) {
      _logger.severe('Lỗi đăng nhập Facebook: $e'); // { changed code }
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
    await FacebookAuth.instance.logOut();
  }

  // Validate số điện thoại Việt Nam
  bool _isValidVietnamesePhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final RegExp vietnamesePhone =
        RegExp(r'^(?:(?:\+?84)|0)(?:3|5|7|8|9)\d{8}$');
    return vietnamesePhone.hasMatch(phone);
  }

  // Format số điện thoại sang chuẩn E.164
  String _formatToE164(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (phone.startsWith('0')) {
      phone = '+84${phone.substring(1)}';
    } else if (phone.startsWith('84')) {
      phone = '+$phone';
    } else if (!phone.startsWith('+84')) {
      phone = '+84$phone';
    }
    return phone;
  }

  // Kiểm tra giới hạn gửi OTP
  bool _canSendOTP(String phoneNumber) {
    final attempt = _otpAttempts[phoneNumber] ?? OTPAttempt();

    if (attempt.attempts >= MAX_OTP_ATTEMPTS) {
      final lastAttempt = attempt.lastAttempt;
      if (lastAttempt != null) {
        final cooldownEnd =
            lastAttempt.add(Duration(seconds: COOLDOWN_DURATION));
        if (DateTime.now().isBefore(cooldownEnd)) {
          final remainingTime = cooldownEnd.difference(DateTime.now());
          throw Exception(
              'Vui lòng thử lại sau ${(remainingTime.inMinutes + 1)} phút');
        } else {
          // Reset khi hết cooldown
          attempt.attempts = 0;
        }
      }
    }

    return true;
  }

  // Gửi mã OTP
  Future<String> verifyPhoneNumber(
    String phoneNumber, {
    Function()? onTimeout,
    bool isResend = false,
  }) async {
    Completer<String> verificationIdCompleter = Completer<String>();

    try {
      if (!_isValidVietnamesePhone(phoneNumber)) {
        throw Exception('Số điện thoại không hợp lệ');
      }

      phoneNumber = _formatToE164(phoneNumber);

      if (!isResend) {
        if (!_canSendOTP(phoneNumber)) {
          throw Exception('Vượt quá số lần gửi OTP cho phép');
        }
        final attempt = _otpAttempts[phoneNumber] ?? OTPAttempt();
        attempt.attempts++;
        attempt.lastAttempt = DateTime.now();
        _otpAttempts[phoneNumber] = attempt;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: isResend ? _resendToken : null,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          _logger.info('Xác thực tự động thành công'); // { changed code }
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _logger.warning('Lỗi xác thực: ${e.message}'); // { changed code }
          if (!verificationIdCompleter.isCompleted) {
            verificationIdCompleter
                .completeError('Lỗi gửi mã OTP: ${e.message}');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _logger.info('Đã gửi mã OTP đến $phoneNumber'); // { changed code }
          _resendToken = resendToken;
          if (!verificationIdCompleter.isCompleted) {
            verificationIdCompleter.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _logger.warning('Hết thời gian chờ OTP'); // { changed code }
          onTimeout?.call();
        },
      );

      return verificationIdCompleter.future;
    } catch (e) {
      _logger.severe('Lỗi gửi mã OTP: $e'); // { changed code }
      throw Exception(e.toString());
    }
  }

  // Xác thực OTP
  Future<User?> verifyOTP(String verificationId, String otp) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      _logger.info('Đăng nhập số điện thoại thành công: ${userCredential.user?.uid}'); // { changed code }
      return userCredential.user;
    } catch (e) {
      _logger.severe('Lỗi xác thực OTP: $e'); // { changed code }
      throw Exception('Mã OTP không hợp lệ');
    }
  }

  /// Đăng ký với Email và Password
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  /// Đăng nhập với Email và Password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }
}

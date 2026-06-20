import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

// ProfileProvider quản lý trạng thái và logic liên quan đến dữ liệu hồ sơ người dùng, bao gồm lấy thông tin, cập nhật thông tin và kiểm tra trạng thái premium.
class ProfileProvider extends ChangeNotifier {
  // Đối tượng FirestoreService để thao tác với dữ liệu người dùng trên Firestore
  final FirestoreService _firestoreService = FirestoreService();
  // Biến lưu dữ liệu người dùng hiện tại
  UserModel? _userData;
  // Biến trạng thái đang tải dữ liệu
  bool _isLoading = true;
  // Biến lưu thông báo lỗi nếu có
  String? _error;
  Future<void>? _loadingFuture;
  String? _loadedUserId;

  // Getter trả về dữ liệu người dùng
  UserModel? get userData => _userData;
  // Getter trả về trạng thái loading
  bool get isLoading => _isLoading;
  // Getter trả về thông báo lỗi
  String? get error => _error;

  void clearUserProfile() {
    _userData = null;
    _loadedUserId = null;
    _loadingFuture = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  void deductCoins(int amount) {
    if (_userData != null) {
      _userData = _userData!.copyWith(
        coinBalance: _userData!.coinBalance - amount,
      );
      notifyListeners();
    }
  }

  // Hàm lấy dữ liệu hồ sơ người dùng hiện tại từ Firestore
  Future<void> loadUserProfile({bool forceRefresh = false}) {
    final authUserId = FirebaseAuth.instance.currentUser?.uid;
    if (authUserId == null || authUserId.isEmpty) {
      clearUserProfile();
      return Future.value();
    }

    if (_loadedUserId != null && _loadedUserId != authUserId) {
      _userData = null;
      _error = null;
      _loadingFuture = null;
      notifyListeners();
    }
    _loadedUserId = authUserId;

    if (_loadingFuture != null && !forceRefresh) {
      return _loadingFuture!;
    }
    _loadingFuture = _loadUserProfileInternal(authUserId);
    return _loadingFuture!.whenComplete(() => _loadingFuture = null);
  }

  Future<void> _loadUserProfileInternal(String expectedUserId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Lấy dữ liệu người dùng hiện tại
      _userData = await _firestoreService.getCurrentUser();
      if (FirebaseAuth.instance.currentUser?.uid != expectedUserId) {
        return;
      }

      // Cập nhật createdAt từ Firebase Auth Metadata cho các người dùng cũ bị thiếu
      final authUser = FirebaseAuth.instance.currentUser;
      if (_userData != null &&
          _userData!.createdAt == null &&
          authUser != null) {
        final creationTime = authUser.metadata.creationTime;
        if (creationTime != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_userData!.id)
              .update({'createdAt': creationTime.toIso8601String()});
          _userData = _userData!.copyWith(createdAt: creationTime);
        }
      }

      // Kiểm tra nếu tài khoản đang là premium thì kiểm tra ngày hết hạn
      if (_userData != null && _userData!.isPremium) {
        final premiumEndDate = _userData!.premiumEndDate;
        final now = DateTime.now();
        // Nếu đã hết hạn thì cập nhật lại trạng thái premium trên Firestore
        if (premiumEndDate != null && premiumEndDate.isBefore(now)) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_userData!.id)
              .update({'isPremium': false});
          // Cập nhật lại dữ liệu local
          _userData = _userData!.copyWith(isPremium: false);
        }
      }
    } catch (e) {
      // Nếu có lỗi thì lưu lại thông báo lỗi
      _error = e.toString();
    } finally {
      // Kết thúc quá trình tải dữ liệu
      _isLoading = false;
      notifyListeners();
    }
  }

  // Hàm cập nhật thông tin hồ sơ người dùng lên Firestore
  Future<void> updateProfile(UserModel updatedUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Gọi FirestoreService để cập nhật thông tin người dùng
      await _firestoreService.updateUser(updatedUser);
      // Cập nhật lại dữ liệu local
      _userData = updatedUser;
      _loadedUserId = updatedUser.id;
    } catch (e) {
      // Nếu có lỗi thì lưu lại thông báo lỗi
      _error = e.toString();
    } finally {
      // Kết thúc quá trình cập nhật
      _isLoading = false;
      notifyListeners();
    }
  }
}

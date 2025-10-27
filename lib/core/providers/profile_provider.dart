import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class ProfileProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  UserModel? _userData;
  bool _isLoading = true;
  String? _error;

  // Getters
  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userData = await _firestoreService.getCurrentUser();

      // Kiểm tra hết hạn premium
      if (_userData != null && _userData!.isPremium) {
        final premiumEndDate = _userData!.premiumEndDate;
        final now = DateTime.now();
        if (premiumEndDate != null && premiumEndDate.isBefore(now)) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_userData!.id)
              .update({'isPremium': false});
          _userData = _userData!.copyWith(isPremium: false);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(UserModel updatedUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.updateUser(updatedUser);
      _userData = updatedUser;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
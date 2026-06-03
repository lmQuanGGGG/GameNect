// lib/core/providers/mentor_provider.dart
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../models/mentor_model.dart';
import '../services/firestore_service.dart';

/// MentorProvider — Quản lý toàn bộ state liên quan đến Mentor.
/// Theo Plan Task 5.1.
class MentorProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  // ─── State ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  List<Map<String, dynamic>> _approvedMentors = [];
  MentorModel? _myMentorProfile;
  String? _error;
  String? _selectedGameFilter;

  // ─── Getters ──────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get approvedMentors =>
      List.unmodifiable(_approvedMentors);
  MentorModel? get myMentorProfile => _myMentorProfile;
  String? get error => _error;
  String? get selectedGameFilter => _selectedGameFilter;
  bool get isMentor => _myMentorProfile?.status == 'approved';
  bool get isPending => _myMentorProfile?.status == 'pending';
  bool get isRejected => _myMentorProfile?.status == 'rejected';

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// Load danh sách approved mentors, có thể lọc theo game.
  Future<void> loadApprovedMentors({String? gameFilter}) async {
    _isLoading = true;
    _error = null;
    _selectedGameFilter = gameFilter;
    notifyListeners();

    try {
      _approvedMentors = await _service.getApprovedMentors(
        gameFilter: gameFilter,
      );
    } catch (e) {
      _error = e.toString();
      developer.log('loadApprovedMentors error: $e', name: 'MentorProvider');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load mentor profile của bản thân.
  Future<void> loadMyMentorProfile(String userId) async {
    try {
      _myMentorProfile = await _service.getMentorProfile(userId);
      notifyListeners();
    } catch (e) {
      developer.log('loadMyMentorProfile error: $e', name: 'MentorProvider');
    }
  }

  /// Gửi đơn đăng ký Mentor.
  Future<bool> applyForMentor(
    String userId, {
    required List<String> games,
    required String bio,
    required String achievements,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final mentor = MentorModel(
        userId: userId,
        games: games,
        bio: bio,
        achievements: achievements,
        status: 'pending',
        appliedAt: DateTime.now(),
      );
      await _service.applyForMentor(userId, mentor);
      _myMentorProfile = mentor;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      developer.log('applyForMentor error: $e', name: 'MentorProvider');
      return false;
    }
  }

  /// Follow mentor.
  Future<void> followMentor(String mentorId, String followerId) async {
    try {
      await _service.followMentor(mentorId, followerId);
      // Refresh danh sách để cập nhật followerCount nếu đang hiển thị
      await loadApprovedMentors(gameFilter: _selectedGameFilter);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      developer.log('followMentor error: $e', name: 'MentorProvider');
    }
  }

  /// Unfollow mentor.
  Future<void> unfollowMentor(String mentorId, String followerId) async {
    try {
      await _service.unfollowMentor(mentorId, followerId);
      await loadApprovedMentors(gameFilter: _selectedGameFilter);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      developer.log('unfollowMentor error: $e', name: 'MentorProvider');
    }
  }

  /// Kiểm tra đang follow mentor chưa.
  Future<bool> checkIsFollowing(String mentorId, String followerId) async {
    try {
      return await _service.isFollowingMentor(mentorId, followerId);
    } catch (e) {
      developer.log('checkIsFollowing error: $e', name: 'MentorProvider');
      return false;
    }
  }

  /// Gửi Match Request đến mentor.
  Future<bool> sendMatchRequest(
    String fromUserId,
    String toMentorId,
    String? message,
  ) async {
    try {
      await _service.sendMentorMatchRequest(fromUserId, toMentorId, message);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      developer.log('sendMatchRequest error: $e', name: 'MentorProvider');
      return false;
    }
  }

  /// Đánh giá Mentor
  Future<bool> rateMentor({
    required String fromUserId,
    required String toMentorId,
    required double rating,
    required String comment,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.rateMentor(
        fromUserId: fromUserId,
        toMentorId: toMentorId,
        rating: rating,
        comment: comment,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      developer.log('rateMentor error: $e', name: 'MentorProvider');
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

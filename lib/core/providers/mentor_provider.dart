// lib/core/providers/mentor_provider.dart
import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // Listener cho mentor live notifications
  StreamSubscription? _mentorLiveSub;
  final Set<String> _notifiedStreamIds = {}; // tránh notify 2 lần
  String? _currentUserId;

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

  // ─── MENTOR LIVE NOTIFICATIONS ────────────────────────────────────────────

  /// Bắt đầu lắng nghe các livestream mới từ mentor mà user đang follow.
  /// Gọi sau khi user đăng nhập, truyền vào userId của chính user đó.
  void startMentorLiveListener(String userId) {
    if (_currentUserId == userId) return; // đã chạy cho user này rồi
    stopMentorLiveListener();
    _currentUserId = userId;
    _notifiedStreamIds.clear();

    final startedAfter = Timestamp.now();

    _mentorLiveSub = FirebaseFirestore.instance
        .collection('livestreams')
        .where('status', isEqualTo: 'live')
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        // Chỉ xử lý document MỚI được thêm (mentor vừa bắt đầu live)
        if (change.type != DocumentChangeType.added) continue;

        final streamId = change.doc.id;
        if (_notifiedStreamIds.contains(streamId)) continue;

        final data = change.doc.data();
        if (data == null) continue;

        // Kiểm tra stream này mới tạo sau khi user login (tránh notify cho stream cũ)
        final startedAt = data['startedAt'] as Timestamp?;
        if (startedAt != null && startedAt.compareTo(startedAfter) <= 0) continue;

        final mentorId = data['mentorId'] as String? ?? '';
        final mentorUsername = data['mentorUsername'] as String? ?? 'Mentor';
        final title = data['title'] as String? ?? '';
        if (mentorId.isEmpty || mentorId == userId) continue; // không tự notify chính mình

        // Kiểm tra user có follow mentor này không
        final isFollowing = await _service.isFollowingMentor(mentorId, userId);
        if (!isFollowing) continue;

        _notifiedStreamIds.add(streamId);
        developer.log(
          'Mentor live notification: mentorId=$mentorId streamId=$streamId',
          name: 'MentorProvider',
        );

        await _showMentorLiveNotification(
          mentorUsername: mentorUsername,
          streamTitle: title,
          streamId: streamId,
        );
      }
    }, onError: (e) {
      developer.log('startMentorLiveListener error: $e', name: 'MentorProvider');
    });

    developer.log('Mentor live listener started for userId=$userId', name: 'MentorProvider');
  }

  /// Dừng listener khi user logout.
  void stopMentorLiveListener() {
    _mentorLiveSub?.cancel();
    _mentorLiveSub = null;
    _currentUserId = null;
    _notifiedStreamIds.clear();
    developer.log('Mentor live listener stopped', name: 'MentorProvider');
  }

  /// Hiển thị local notification khi mentor bắt đầu live.
  static Future<void> _showMentorLiveNotification({
    required String mentorUsername,
    required String streamTitle,
    required String streamId,
  }) async {
    if (kIsWeb) return;
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: streamId.hashCode.abs() % 100000,
          channelKey: 'mentor_live_channel',
          title: '🔴 $mentorUsername đang LIVE!',
          body: streamTitle.isNotEmpty ? streamTitle : 'Nhấn để xem ngay',
          payload: {
            'type': 'mentor_live',
            'streamId': streamId,
          },
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          wakeUpScreen: true,
          displayOnForeground: true,
          displayOnBackground: true,
        ),
      );
    } catch (e) {
      developer.log('_showMentorLiveNotification error: $e', name: 'MentorProvider');
    }
  }

  @override
  void dispose() {
    stopMentorLiveListener();
    super.dispose();
  }
}

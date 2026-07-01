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
  final List<Map<String, dynamic>> _approvedMentors = [];
  MentorModel? _myMentorProfile;
  String? _error;
  String? _selectedGameFilter;
  String? _loadedMyMentorUserId;
  Future<void>? _myMentorLoadFuture;
  StreamSubscription? _approvedMentorsSub;
  Future<void>? _approvedMentorsListenFuture;
  String? _approvedMentorsListenGameFilter;

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

  void clearMyMentorProfile() {
    _myMentorProfile = null;
    _loadedMyMentorUserId = null;
    _myMentorLoadFuture = null;
    _error = null;
    notifyListeners();
  }

  /// Start listening to approved mentors. Initial snapshot reads the current
  /// approved list once; later Firestore sends only changed documents.
  Future<void> loadApprovedMentors({String? gameFilter}) {
    if (_approvedMentorsSub != null &&
        _approvedMentorsListenGameFilter == gameFilter) {
      return _approvedMentorsListenFuture ?? Future.value();
    }

    _approvedMentorsListenFuture = _listenApprovedMentors(gameFilter);
    return _approvedMentorsListenFuture!;
  }

  Future<void> _listenApprovedMentors(String? gameFilter) async {
    await _approvedMentorsSub?.cancel();
    _approvedMentorsSub = null;
    _approvedMentorsListenGameFilter = gameFilter;

    final firstSnapshot = Completer<void>();
    _isLoading = true;
    _error = null;
    _selectedGameFilter = gameFilter;
    notifyListeners();

    Query query = _service.db
        .collection('mentor_profiles')
        .where('status', isEqualTo: 'approved');

    if (gameFilter != null && gameFilter.isNotEmpty) {
      query = query.where('games', arrayContains: gameFilter);
    }

    _approvedMentorsSub = query.snapshots().listen(
      (snapshot) async {
        var changed = false;
        try {
          final upsertDocs = snapshot.docChanges
              .where((change) => change.type != DocumentChangeType.removed)
              .map((change) => change.doc)
              .toList();
          final userDocsMap = await _loadUserDocsForMentors(
            upsertDocs.map((doc) => doc.id).toList(),
          );

          for (final change in snapshot.docChanges) {
            final docId = change.doc.id;

            if (change.type == DocumentChangeType.removed) {
              final before = _approvedMentors.length;
              _approvedMentors.removeWhere(
                (mentor) => mentor['userId'] == docId,
              );
              changed = changed || before != _approvedMentors.length;
              continue;
            }

            final mentorData = change.doc.data() as Map<String, dynamic>;
            final userData = userDocsMap[docId] ?? {};
            final merged = {
              ...mentorData,
              'userId': docId,
              'username': userData['username'] ?? '',
              'avatarUrl': userData['avatarUrl'] ?? '',
            };
            final index = _approvedMentors.indexWhere(
              (mentor) => mentor['userId'] == docId,
            );
            if (index == -1) {
              _approvedMentors.add(merged);
            } else {
              _approvedMentors[index] = merged;
            }
            changed = true;
          }

          if (changed) {
            _sortApprovedMentors();
          }
        } catch (e) {
          _error = e.toString();
          developer.log(
            'listenApprovedMentors snapshot error: $e',
            name: 'MentorProvider',
          );
        } finally {
          final wasLoading = _isLoading;
          if (_isLoading) {
            _isLoading = false;
          }
          if (changed || _error != null || wasLoading) {
            notifyListeners();
          }
          if (!firstSnapshot.isCompleted) {
            firstSnapshot.complete();
          }
        }
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
        developer.log(
          'listenApprovedMentors error: $e',
          name: 'MentorProvider',
        );
        if (!firstSnapshot.isCompleted) {
          firstSnapshot.complete();
        }
      },
    );

    return firstSnapshot.future;
  }

  Future<Map<String, Map<String, dynamic>>> _loadUserDocsForMentors(
    List<String> mentorIds,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    if (mentorIds.isEmpty) return result;

    for (var i = 0; i < mentorIds.length; i += 30) {
      final chunk = mentorIds.sublist(
        i,
        i + 30 > mentorIds.length ? mentorIds.length : i + 30,
      );
      final usersSnap = await _service.db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final userDoc in usersSnap.docs) {
        result[userDoc.id] = userDoc.data();
      }
    }

    return result;
  }

  void _sortApprovedMentors() {
    _approvedMentors.sort((a, b) {
      final aTs = a['approvedAt'] as Timestamp? ?? a['appliedAt'] as Timestamp?;
      final bTs = b['approvedAt'] as Timestamp? ?? b['appliedAt'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    });
  }

  void removeApprovedMentorFromCache(String userId) {
    final before = _approvedMentors.length;
    _approvedMentors.removeWhere((mentor) => mentor['userId'] == userId);
    if (_approvedMentors.length != before) {
      notifyListeners();
    }
  }

  /// Load mentor profile của bản thân.
  Future<void> loadMyMentorProfile(String userId, {bool forceRefresh = false}) {
    if (userId.isEmpty) {
      clearMyMentorProfile();
      return Future.value();
    }

    if (_loadedMyMentorUserId != null && _loadedMyMentorUserId != userId) {
      _myMentorProfile = null;
      _error = null;
      _myMentorLoadFuture = null;
      notifyListeners();
    }

    if (!forceRefresh &&
        _loadedMyMentorUserId == userId &&
        _myMentorLoadFuture != null) {
      return _myMentorLoadFuture!;
    }
    if (!forceRefresh && _loadedMyMentorUserId == userId) {
      return Future.value();
    }

    _loadedMyMentorUserId = userId;
    _myMentorLoadFuture = _loadMyMentorProfileInternal(userId);
    return _myMentorLoadFuture!.whenComplete(() => _myMentorLoadFuture = null);
  }

  Future<void> _loadMyMentorProfileInternal(String userId) async {
    try {
      final mentorProfile = await _service.getMentorProfile(userId);
      if (_loadedMyMentorUserId != userId) return;
      _myMentorProfile = mentorProfile;
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
      _loadedMyMentorUserId = userId;
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
      // Cập nhật local trước (optimistic) — không gọi loadApprovedMentors để tránh reload list
      final idx = _approvedMentors.indexWhere((m) => m['userId'] == mentorId);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(_approvedMentors[idx]);
        updated['followerCount'] =
            ((updated['followerCount'] as int? ?? 0) + 1);
        _approvedMentors[idx] = updated;
        notifyListeners();
      }
      await _service.followMentor(mentorId, followerId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      developer.log('followMentor error: $e', name: 'MentorProvider');
    }
  }

  /// Unfollow mentor.
  Future<void> unfollowMentor(String mentorId, String followerId) async {
    try {
      // Cập nhật local trước (optimistic) — không gọi loadApprovedMentors để tránh reload list
      final idx = _approvedMentors.indexWhere((m) => m['userId'] == mentorId);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(_approvedMentors[idx]);
        final current = updated['followerCount'] as int? ?? 0;
        updated['followerCount'] = current > 0 ? current - 1 : 0;
        _approvedMentors[idx] = updated;
        notifyListeners();
      }
      await _service.unfollowMentor(mentorId, followerId);
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
        .listen(
          (snap) async {
            for (final change in snap.docChanges) {
              // Chỉ xử lý document MỚI được thêm (mentor vừa bắt đầu live)
              if (change.type != DocumentChangeType.added) continue;

              final streamId = change.doc.id;
              if (_notifiedStreamIds.contains(streamId)) continue;

              final data = change.doc.data();
              if (data == null) continue;

              // Kiểm tra stream này mới tạo sau khi user login (tránh notify cho stream cũ)
              final startedAt = data['startedAt'] as Timestamp?;
              if (startedAt != null && startedAt.compareTo(startedAfter) <= 0) {
                continue;
              }

              final mentorId = data['mentorId'] as String? ?? '';
              final mentorUsername =
                  data['mentorUsername'] as String? ?? 'Mentor';
              final title = data['title'] as String? ?? '';
              if (mentorId.isEmpty || mentorId == userId) {
                continue; // không tự notify chính mình
              }

              // Kiểm tra user có follow mentor này không
              final isFollowing = await _service.isFollowingMentor(
                mentorId,
                userId,
              );
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
          },
          onError: (e) {
            developer.log(
              'startMentorLiveListener error: $e',
              name: 'MentorProvider',
            );
          },
        );

    developer.log(
      'Mentor live listener started for userId=$userId',
      name: 'MentorProvider',
    );
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
          payload: {'type': 'mentor_live', 'streamId': streamId},
          actionType: ActionType.Default,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          wakeUpScreen: true,
          displayOnForeground: true,
          displayOnBackground: true,
        ),
      );
    } catch (e) {
      developer.log(
        '_showMentorLiveNotification error: $e',
        name: 'MentorProvider',
      );
    }
  }

  @override
  void dispose() {
    _approvedMentorsSub?.cancel();
    stopMentorLiveListener();
    super.dispose();
  }
}

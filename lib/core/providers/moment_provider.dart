import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gamenect_new/core/services/notification_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../models/moment_model.dart';
import '../services/firestore_service.dart';
//import 'package:firebase_auth/firebase_auth.dart';

final Logger _logger = Logger();

// MomentProvider quản lý trạng thái và logic liên quan đến tính năng Moment (story), bao gồm lấy dữ liệu, lắng nghe realtime, xử lý reaction và reply.
class MomentProvider with ChangeNotifier {
  // Danh sách các moment hiện tại
  List<MomentModel> _moments = [];
  // Trạng thái đang tải dữ liệu
  bool _isLoading = false;

  // Getter trả về danh sách moment
  List<MomentModel> get moments => _moments;
  // Getter trả về trạng thái loading
  bool get isLoading => _isLoading;

  // Biến lưu subscription stream realtime moments
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _momentsSub;

  // Map lưu lại các reaction đã gửi thông báo để tránh gửi lặp lại
  final Map<String, Set<String>> _notifiedReactions = {};

  // Biến cờ để bỏ qua snapshot đầu tiên khi vừa đăng nhập (tránh gửi thông báo cũ)
  bool _isFirstSnapshot = true;

  // Hàm lấy danh sách user đã match với userId
  Future<List<String>> getMatchedUserIds(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('matches')
        .where('userIds', arrayContains: userId)
        .where('status', isEqualTo: 'confirmed')
        .get();

    List<String> matchedUserIds = [];
    for (var doc in snap.docs) {
      final userIds = List<String>.from(doc.data()['userIds'] ?? []);
      matchedUserIds.addAll(userIds.where((id) => id != userId));
    }
    return matchedUserIds.toSet().toList();
  }

  // Hàm lắng nghe realtime moments, tự động phát hiện reaction mới để gửi thông báo cho chủ moment
  Future<void> listenMoments(String userId) async {
    await _momentsSub?.cancel();
    _isLoading = true;
    _isFirstSnapshot = true; // Reset cờ snapshot đầu tiên
    notifyListeners();

    _momentsSub = FirebaseFirestore.instance
        .collection('moments')
        .where('matchIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(
          (snap) async {
            final newMoments = snap.docs
                .map((d) => MomentModel.fromMap(d.data(), d.id))
                .toList();

            // Bỏ qua snapshot đầu tiên để không gửi thông báo cho các reaction cũ
            if (_isFirstSnapshot) {
              //_logger.i('🔇 Skipping first snapshot (initial load)', name: 'MomentProvider');
              _isFirstSnapshot = false;
              // Lưu lại tất cả reaction hiện có để không thông báo lại
              for (var moment in newMoments) {
                if (moment.userId != userId) continue;
                _notifiedReactions[moment.id] ??= {};
                for (var reaction in moment.reactions) {
                  final reactorUserId = reaction['userId'] as String?;
                  final emoji = reaction['emoji'] as String?;
                  if (reactorUserId != null &&
                      emoji != null &&
                      reactorUserId != userId) {
                    final reactionKey =
                        '$reactorUserId-$emoji-${reaction['reactedAt']?.seconds ?? 0}';
                    _notifiedReactions[moment.id]!.add(reactionKey);
                  }
                }
              }

              _moments = newMoments;
              _isLoading = false;
              notifyListeners();
              return;
            }

            // Kiểm tra các reaction mới (chỉ thực hiện từ snapshot thứ hai trở đi)
            for (var moment in newMoments) {
              // Chỉ kiểm tra moment của chính mình
              if (moment.userId != userId) continue;

              // Khởi tạo set reaction nếu chưa có
              _notifiedReactions[moment.id] ??= {};

              // Duyệt qua các reaction
              for (var reaction in moment.reactions) {
                final reactorUserId = reaction['userId'] as String?;
                final emoji = reaction['emoji'] as String?;

                if (reactorUserId == null || emoji == null) continue;

                // Bỏ qua reaction của chính mình
                if (reactorUserId == userId) continue;

                // Tạo key duy nhất cho mỗi reaction
                final reactionKey =
                    '$reactorUserId-$emoji-${reaction['reactedAt']?.seconds ?? 0}';

                // Nếu chưa gửi thông báo cho reaction này thì gửi thông báo
                if (!_notifiedReactions[moment.id]!.contains(reactionKey)) {
                  _notifiedReactions[moment.id]!.add(reactionKey);

                  // Lấy thông tin người đã react
                  try {
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(reactorUserId)
                        .get();

                    final reactorUsername =
                        userDoc.data()?['username'] ?? 'Người dùng';

                    // Gửi thông báo cho chủ moment
                    await showMomentReactionNotification(
                      momentOwnerId: userId,
                      reactorUsername: reactorUsername,
                      reactorUserId: reactorUserId,
                      momentId: moment.id,
                      emoji: emoji,
                    );

                    _logger.i(
                      'Sent reaction notification: $reactorUsername reacted $emoji to moment ${moment.id}',
                    );
                  } catch (e) {
                    _logger.e('Error sending reaction notification: $e');
                  }
                }
              }
            }

            _moments = newMoments;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _logger.e('listenMoments error: $e');
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  // Hàm lấy moments của user và các user đã match
  Future<void> fetchMoments(String userId, List<String> matchIds) async {
    _isLoading = true;
    notifyListeners();

    try {
      _moments = await FirestoreService().getMomentsForUser(userId, matchIds);
      _logger.i('Fetched ${_moments.length} moments');
    } catch (e) {
      _logger.e('Error fetching moments: $e');
      _moments = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> canPostMoment({
    required String userId,
    required bool isVideo,
  }) async {
    return FirestoreService().canPostMoment(userId, isVideo: isVideo);
  }

  // Hàm đăng moment mới (ảnh/video)
  Future<void> postMoment({
    required String userId,
    required String mediaUrl,
    required bool isVideo,
    required List<String> matchIds,
    String? caption,
    String? thumbnailUrl,
  }) async {
    try {
      await FirestoreService().postMoment(
        userId: userId,
        mediaUrl: mediaUrl,
        isVideo: isVideo,
        matchIds: matchIds,
        caption: caption,
        thumbnailUrl: thumbnailUrl,
      );
      // Stream sẽ tự động cập nhật khi có moment mới
    } catch (e) {
      rethrow;
    }
  }

  // Hàm thêm reaction vào moment
  Future<void> reactToMoment(
    String momentId,
    String userId,
    String emoji,
  ) async {
    // 1. Cập nhật offline cục bộ (Optimistic local update) để UI hiển thị lập tức
    final index = _moments.indexWhere((m) => m.id == momentId);
    if (index != -1) {
      final moment = _moments[index];
      final newReactions = List<Map<String, dynamic>>.from(moment.reactions);

      // Kiểm tra xem user đã thả reaction này chưa để tránh add trùng cục bộ
      final exists = newReactions.any(
        (r) => r['userId'] == userId && r['emoji'] == emoji,
      );
      if (!exists) {
        newReactions.add({
          'userId': userId,
          'emoji': emoji,
          'reactedAt': Timestamp.now(),
        });

        _moments[index] = MomentModel(
          id: moment.id,
          userId: moment.userId,
          mediaUrl: moment.mediaUrl,
          thumbnailUrl: moment.thumbnailUrl,
          isVideo: moment.isVideo,
          createdAt: moment.createdAt,
          matchIds: moment.matchIds,
          reactions: newReactions,
          replies: moment.replies,
          caption: moment.caption,
        );
        notifyListeners();
      }
    }

    // 2. Gửi request lên Firestore
    try {
      await FirestoreService().addReactionToMoment(momentId, userId, emoji);
      _logger.i('Reaction added to Firestore: $emoji on moment $momentId');
    } catch (e) {
      _logger.e('Error reacting to moment: $e');
      rethrow;
    }
  }

  // Hàm trả lời (reply) vào moment
  Future<void> replyToMoment(
    String momentId,
    String userId,
    String text,
  ) async {
    try {
      await FirestoreService().addReplyToMoment(momentId, userId, text);
      final index = _moments.indexWhere((m) => m.id == momentId);
      if (index != -1) {
        _moments[index].replies.add({
          'userId': userId,
          'text': text,
          'repliedAt': Timestamp.now(),
        });
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error replying to moment: $e');
      rethrow;
    }
  }

  // Hàm hủy subscription khi dispose provider
  @override
  void dispose() {
    _momentsSub?.cancel();
    _notifiedReactions.clear();
    super.dispose();
  }
}

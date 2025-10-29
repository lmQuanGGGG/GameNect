import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gamenect_new/core/services/notification_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../models/moment_model.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

final Logger _logger = Logger();

class MomentProvider with ChangeNotifier {
  List<MomentModel> _moments = [];
  bool _isLoading = false;

  List<MomentModel> get moments => _moments;
  bool get isLoading => _isLoading;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _momentsSub;
  
  // THÊM: Map để lưu lại reaction đã thông báo (tránh duplicate)
  final Map<String, Set<String>> _notifiedReactions = {};
  
  // THÊM: Flag để bỏ qua snapshot đầu tiên
  bool _isFirstSnapshot = true;

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

  // NGHE REALTIME VÀ DETECT REACTIONS MỚI
  Future<void> listenMoments(String userId) async {
    await _momentsSub?.cancel();
    _isLoading = true;
    _isFirstSnapshot = true; // ⭐ RESET flag
    notifyListeners();

    _momentsSub = FirebaseFirestore.instance
        .collection('moments')
        .where('matchIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) async {
          final newMoments = snap.docs
              .map((d) => MomentModel.fromMap(d.data(), d.id))
              .toList();

          // ⭐ BỎ QUA SNAPSHOT ĐẦU TIÊN (khi mới đăng nhập)
          if (_isFirstSnapshot) {
            //_logger.i('🔇 Skipping first snapshot (initial load)', name: 'MomentProvider');
            _isFirstSnapshot = false;
            
            // Lưu lại tất cả reactions hiện có để không thông báo lại
            for (var moment in newMoments) {
              if (moment.userId != userId) continue;
              _notifiedReactions[moment.id] ??= {};
              for (var reaction in moment.reactions) {
                final reactorUserId = reaction['userId'] as String?;
                final emoji = reaction['emoji'] as String?;
                if (reactorUserId != null && emoji != null && reactorUserId != userId) {
                  final reactionKey = '$reactorUserId-$emoji-${reaction['reactedAt']?.seconds ?? 0}';
                  _notifiedReactions[moment.id]!.add(reactionKey);
                }
              }
            }
            
            _moments = newMoments;
            _isLoading = false;
            notifyListeners();
            return;
          }

          // KIỂM TRA REACTION MỚI (chỉ từ snapshot thứ 2 trở đi)
          for (var moment in newMoments) {
            // CHỈ kiểm tra moment của MÌNH
            if (moment.userId != userId) continue;

            // Khởi tạo set nếu chưa có
            _notifiedReactions[moment.id] ??= {};

            // Duyệt qua reactions
            for (var reaction in moment.reactions) {
              final reactorUserId = reaction['userId'] as String?;
              final emoji = reaction['emoji'] as String?;

              if (reactorUserId == null || emoji == null) continue;
              
              // Bỏ qua reaction của chính mình
              if (reactorUserId == userId) continue;

              // Tạo key unique cho reaction này
              final reactionKey = '$reactorUserId-$emoji-${reaction['reactedAt']?.seconds ?? 0}';

              // Nếu chưa thông báo → GỬI THÔNG BÁO
              if (!_notifiedReactions[moment.id]!.contains(reactionKey)) {
                _notifiedReactions[moment.id]!.add(reactionKey);

                // Lấy thông tin người react
                try {
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(reactorUserId)
                      .get();
                  
                  final reactorUsername = userDoc.data()?['username'] ?? 'Người dùng';

                  // GỬI THÔNG BÁO
                  await showMomentReactionNotification(
                    momentOwnerId: userId,
                    reactorUsername: reactorUsername,
                    reactorUserId: reactorUserId,
                    momentId: moment.id,
                    emoji: emoji,
                  );
                  
                  _logger.i('Sent reaction notification: $reactorUsername reacted $emoji to moment ${moment.id}');
                } catch (e) {
                  _logger.e('Error sending reaction notification: $e');
                }
              }
            }
          }

          _moments = newMoments;
          _isLoading = false;
          notifyListeners();
        }, onError: (e) {
          _logger.e('listenMoments error: $e');
          _isLoading = false;
          notifyListeners();
        });
  }

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
      // Stream sẽ tự cập nhật
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reactToMoment(String momentId, String userId, String emoji) async {
    try {
      await FirestoreService().addReactionToMoment(momentId, userId, emoji);
      // KHÔNG CẦN gọi notification ở đây nữa
      // Stream của chủ moment sẽ tự detect và gửi notification
      _logger.i('Reaction added to Firestore: $emoji on moment $momentId');
    } catch (e) {
      _logger.e('Error reacting to moment: $e');
      rethrow;
    }
  }

  Future<void> replyToMoment(String momentId, String userId, String text) async {
    try {
      await FirestoreService().addReplyToMoment(momentId, userId, text);
      final index = _moments.indexWhere((m) => m.id == momentId);
      if (index != -1) {
        _moments[index].replies.add({
          'userId': userId,
          'text': text,
          'repliedAt': Timestamp.now()
        });
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error replying to moment: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _momentsSub?.cancel();
    _notifiedReactions.clear();
    super.dispose();
  }
}
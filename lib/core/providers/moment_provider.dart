import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/moment_model.dart';
import '../services/firestore_service.dart';

final Logger _logger = Logger();

class MomentProvider with ChangeNotifier {
  List<MomentModel> _moments = [];
  bool _isLoading = false;

  List<MomentModel> get moments => _moments;
  bool get isLoading => _isLoading;

  /// FIX: Lấy danh sách userId của những người đã match (không phải matchId)
  Future<List<String>> getMatchedUserIds(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('matches')
        .where('userIds', arrayContains: userId)
        .where('status', isEqualTo: 'confirmed')
        .get();
    
    // Lấy tất cả userId từ mỗi match, loại bỏ userId hiện tại
    List<String> matchedUserIds = [];
    for (var doc in snap.docs) {
      final userIds = List<String>.from(doc.data()['userIds'] ?? []);
      // Thêm tất cả userId trừ chính mình
      matchedUserIds.addAll(userIds.where((id) => id != userId));
    }
    
    // Loại bỏ duplicate
    return matchedUserIds.toSet().toList();
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
      await fetchMoments(userId, matchIds);
    } catch (e) {
      rethrow;
    }
  }

  // Thả cảm xúc
  Future<void> reactToMoment(String momentId, String userId, String emoji) async {
    try {
      await FirestoreService().addReactionToMoment(momentId, userId, emoji);
      // Cập nhật local state ngay lập tức
      final index = _moments.indexWhere((m) => m.id == momentId);
      if (index != -1) {
        _moments[index].reactions.add({'userId': userId, 'emoji': emoji});
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error reacting to moment: $e');
      rethrow;
    }
  }

  // Trả lời moment
  Future<void> replyToMoment(String momentId, String userId, String text) async {
    try {
      await FirestoreService().addReplyToMoment(momentId, userId, text);
      // Cập nhật local state ngay lập tức
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
}
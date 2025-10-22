import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async'; // THÊM
import '../models/moment_model.dart';
import '../services/firestore_service.dart';

final Logger _logger = Logger();

class MomentProvider with ChangeNotifier {
  List<MomentModel> _moments = [];
  bool _isLoading = false;

  List<MomentModel> get moments => _moments;
  bool get isLoading => _isLoading;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _momentsSub; // THÊM

  /// FIX: Lấy danh sách userId của những người đã match (không phải matchId)
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

  // NGHE REALTIME
  Future<void> listenMoments(String userId) async {
    await _momentsSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _momentsSub = FirebaseFirestore.instance
        .collection('moments')
        .where('matchIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
          _moments = snap.docs
              .map((d) => MomentModel.fromMap(d.data(), d.id))
              .toList();
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
      // KHÔNG gọi fetch lại; stream listenMoments sẽ tự cập nhật
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reactToMoment(String momentId, String userId, String emoji) async {
    try {
      await FirestoreService().addReactionToMoment(momentId, userId, emoji);
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
    _momentsSub?.cancel(); // THÊM
    super.dispose();
  }
}
part of '../firestore_service.dart';

// ==================== SWIPE HISTORY OPERATIONS ====================
// Quản lý lịch sử swipe (like/dislike) giữa các users

extension SwipeServiceExtension on FirestoreService {
  // Lưu lịch sử swipe: ghi vào swipe_history (log) và swipe_latest (trạng thái mới nhất)
  Future<void> saveSwipeHistory({
    required String userId,
    required String targetUserId,
    required String action,
  }) async {
    try {
      final now = DateTime.now();

      // 1. Log vào swipe_history với TTL 60 ngày
      await _db.collection('swipe_history').add({
        'userId': userId,
        'targetUserId': targetUserId,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 60))),
      });

      // 2. Upsert vào swipe_latest để query nhanh
      final latestDocId = '${userId}_$targetUserId';
      await _db.collection('swipe_latest').doc(latestDocId).set({
        'userId': userId,
        'targetUserId': targetUserId,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
      });

      developer.log('Đã lưu swipe: $action', name: 'FirestoreService');
    } catch (e) {
      developer.log('Lỗi khi lưu swipe history: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  // Lấy danh sách userId đã swipe (để lọc khỏi recommendations)
  Future<List<String>> getSwipedUserIds(String userId) async {
    try {
      final snapshot = await _db
          .collection('swipe_history')
          .where('userId', isEqualTo: userId)
          .get();

      final swipedIds = snapshot.docs
          .map((doc) => doc.data()['targetUserId'] as String)
          .toSet()
          .toList();

      developer.log('User đã quẹt ${swipedIds.length} người', name: 'FirestoreService');
      return swipedIds;
    } catch (e) {
      developer.log('Lỗi khi lấy swipe history: $e', name: 'FirestoreService', error: e);
      return [];
    }
  }

  // Kiểm tra mutual like (target có like mình không)
  Future<bool> checkMutualLike({
    required String userId,
    required String targetUserId,
  }) async {
    try {
      final snapshot = await _db
          .collection('swipe_history')
          .where('userId', isEqualTo: targetUserId)
          .where('targetUserId', isEqualTo: userId)
          .where('action', isEqualTo: 'like')
          .limit(1)
          .get();

      final isMutual = snapshot.docs.isNotEmpty;
      developer.log('Mutual like với $targetUserId: $isMutual', name: 'FirestoreService');
      return isMutual;
    } catch (e) {
      developer.log('Lỗi khi check mutual like: $e', name: 'FirestoreService', error: e);
      return false;
    }
  }

  // Lấy lịch sử swipe 'dislike' của user
  Future<List<SwipeHistory>> getDislikeHistory(String userId, {int limit = 10}) async {
    try {
      final snapshot = await _db
          .collection('swipe_history')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: 'dislike')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SwipeHistory.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      developer.log('Lỗi khi lấy lịch sử dislike: $e', name: 'FirestoreService', error: e);
      return [];
    }
  }

  // Lấy lịch sử những người đã like mình
  Future<List<SwipeHistory>> getLikedMeHistory(String userId, {int limit = 20}) async {
    final snapshot = await _db
        .collection('swipe_history')
        .where('targetUserId', isEqualTo: userId)
        .where('action', isEqualTo: 'like')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => SwipeHistory.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
}

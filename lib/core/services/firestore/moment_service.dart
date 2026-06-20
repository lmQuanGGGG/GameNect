part of '../firestore_service.dart';

// ==================== MOMENT OPERATIONS ====================
// Quản lý Moments (stories): đăng, xem, react, reply

extension MomentServiceExtension on FirestoreService {
  // Kiểm tra user có đủ quota để đăng moment không (free: 20/tháng)
  Future<bool> canPostMoment(String userId, {required bool isVideo}) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final user = await getUser(userId);
    if (user?.isPremium ?? false) return true;

    try {
      final baseQuery = _db
          .collection('moments')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth);

      // Tổng moment/tháng: tối đa 20
      final totalAgg = await baseQuery.count().get();
      final total = totalAgg.count ?? 0;
      if (total >= 20) return false;

      // Nếu là video thì check thêm quota video/tháng: tối đa 2
      if (isVideo) {
        final videoAgg = await baseQuery
            .where('isVideo', isEqualTo: true)
            .count()
            .get();

        final videoTotal = videoAgg.count ?? 0;
        if (videoTotal >= 2) return false;
      }

      return true;
    } catch (e) {
      developer.log(
        'canPostMoment error: $e',
        name: 'FirestoreService',
        error: e,
      );
      return false;
    }
  }

  // Đăng moment mới (ảnh hoặc video)
  Future<void> postMoment({
    required String userId,
    required String mediaUrl,
    required bool isVideo,
    required List<String> matchIds,
    String? caption,
    String? thumbnailUrl,
  }) async {
    if (!await canPostMoment(userId, isVideo: isVideo)) {
      throw Exception(isVideo ? 'VIDEO_LIMIT_EXCEEDED' : 'LIMIT_EXCEEDED');
    }

    // Moment hiển thị cho chính user và tất cả matched users
    final visibleToUserIds = <String>{userId, ...matchIds};

    developer.log(
      'Posting moment visible to: $visibleToUserIds',
      name: 'FirestoreService',
    );

    try {
      await _db.collection('moments').add({
        'userId': userId,
        'mediaUrl': mediaUrl,
        'isVideo': isVideo,
        'thumbnailUrl': thumbnailUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'matchIds': visibleToUserIds.toList(),
        'reactions': [],
        'replies': [],
        'caption': caption,
      });

      developer.log(
        'Moment saved successfully with ${visibleToUserIds.length} visible users',
        name: 'FirestoreService',
      );
    } catch (e) {
      developer.log(
        'Error saving moment: $e',
        name: 'FirestoreService',
        error: e,
      );
      rethrow;
    }
  }

  // Lấy moments cho user (dùng arrayContains để tránh giới hạn 10 của whereIn)
  Future<List<MomentModel>> getMomentsForUser(
    String userId,
    List<String> matchIds,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('moments')
        .where('matchIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snap.docs
        .map((doc) => MomentModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Thêm reaction vào moment
  Future<void> addReactionToMoment(
    String momentId,
    String userId,
    String emoji,
  ) async {
    await FirebaseFirestore.instance.collection('moments').doc(momentId).update(
      {
        'reactions': FieldValue.arrayUnion([
          {'userId': userId, 'emoji': emoji},
        ]),
      },
    );
  }

  // Thêm reply vào moment
  Future<void> addReplyToMoment(
    String momentId,
    String userId,
    String text,
  ) async {
    await FirebaseFirestore.instance.collection('moments').doc(momentId).update(
      {
        'replies': FieldValue.arrayUnion([
          {'userId': userId, 'text': text, 'repliedAt': Timestamp.now()},
        ]),
      },
    );
  }
}

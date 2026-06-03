// lib/core/services/firestore/mentor_service.dart
// Part file của FirestoreService — chứa tất cả operations liên quan đến Mentor & Livestream.

part of '../firestore_service.dart';

// ─── CONSTANTS ────────────────────────────────────────────────────────────────
const _kMentorProfiles = 'mentor_profiles';
const _kMentorFollowers = 'mentor_followers';
const _kLivestreams = 'livestreams';
const _kCoinTransactions = 'coin_transactions';
const _kMentorMatchRequests = 'mentor_match_requests';

// ─── EXTENSION: Mentor Service Methods ────────────────────────────────────────
extension MentorService on FirestoreService {
  // ──────────────────────────────────────────────────────────────────────────
  // 4.1. MENTOR PROFILE CRUD
  // ──────────────────────────────────────────────────────────────────────────

  /// Tạo đơn đăng ký Mentor và cập nhật trạng thái user.
  Future<void> applyForMentor(String userId, MentorModel mentor) async {
    try {
      final batch = _db.batch();

      // Tạo/cập nhật mentor_profiles document
      batch.set(
        _db.collection(_kMentorProfiles).doc(userId),
        mentor.toMap(),
      );

      // Cập nhật user: mentorStatus = 'pending'
      batch.update(
        _db.collection('users').doc(userId),
        {
          'mentorStatus': 'pending',
          'isMentor': false,
        },
      );

      await batch.commit();
      developer.log('applyForMentor: userId=$userId', name: 'MentorService');
    } catch (e) {
      developer.log('applyForMentor error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Lấy mentor profile (one-time).
  Future<MentorModel?> getMentorProfile(String userId) async {
    try {
      final doc = await _db.collection(_kMentorProfiles).doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return MentorModel.fromMap(doc.data()!, userId);
    } catch (e) {
      developer.log('getMentorProfile error: $e', name: 'MentorService');
      return null;
    }
  }

  /// Stream mentor profile realtime.
  Stream<MentorModel?> getMentorProfileStream(String userId) {
    return _db
        .collection(_kMentorProfiles)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return MentorModel.fromMap(doc.data()!, userId);
    });
  }

  /// Admin: lấy tất cả đơn đang pending (realtime stream).
  Stream<List<MentorModel>> getPendingMentorApplications() {
    return _db
        .collection(_kMentorProfiles)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => MentorModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
      return list;
    });
  }

  /// Admin: duyệt mentor — cập nhật cả mentor_profiles và users collection.
  Future<void> approveMentor(String userId) async {
    try {
      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      batch.update(
        _db.collection(_kMentorProfiles).doc(userId),
        {
          'status': 'approved',
          'approvedAt': now,
          'rejectedAt': null,
          'rejectReason': null,
        },
      );

      batch.update(
        _db.collection('users').doc(userId),
        {
          'mentorStatus': 'approved',
          'isMentor': true,
        },
      );

      await batch.commit();
      developer.log('approveMentor: userId=$userId', name: 'MentorService');
    } catch (e) {
      developer.log('approveMentor error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Admin: từ chối mentor với lý do.
  Future<void> rejectMentor(String userId, String reason) async {
    try {
      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      batch.update(
        _db.collection(_kMentorProfiles).doc(userId),
        {
          'status': 'rejected',
          'rejectedAt': now,
          'rejectReason': reason,
        },
      );

      batch.update(
        _db.collection('users').doc(userId),
        {
          'mentorStatus': 'rejected',
          'isMentor': false,
        },
      );

      await batch.commit();
      developer.log('rejectMentor: userId=$userId reason=$reason', name: 'MentorService');
    } catch (e) {
      developer.log('rejectMentor error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Lấy danh sách mentor đã approved, có thể lọc theo game.
  Future<List<Map<String, dynamic>>> getApprovedMentors({String? gameFilter}) async {
    try {
      Query query = _db
          .collection(_kMentorProfiles)
          .where('status', isEqualTo: 'approved');

      if (gameFilter != null && gameFilter.isNotEmpty) {
        query = query.where('games', arrayContains: gameFilter);
      }

      final snapshot = await query.get();
      final mentorIds = snapshot.docs.map((d) => d.id).toList();

      if (mentorIds.isEmpty) return [];

      // Lấy thêm thông tin user (username, avatarUrl) để hiển thị
      final results = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        try {
          final userDoc = await _db.collection('users').doc(doc.id).get();
          final mentorData = doc.data() as Map<String, dynamic>;
          final userData = userDoc.data() ?? {};
          results.add({
            ...mentorData,
            'userId': doc.id,
            'username': userData['username'] ?? '',
            'avatarUrl': userData['avatarUrl'] ?? '',
          });
        } catch (_) {
          // Bỏ qua nếu không lấy được user data
        }
      }
      return results;
    } catch (e) {
      developer.log('getApprovedMentors error: $e', name: 'MentorService');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4.2. FOLLOW SYSTEM
  // ──────────────────────────────────────────────────────────────────────────

  /// Follow mentor — tạo document trong mentor_followers.
  Future<void> followMentor(String mentorId, String followerId) async {
    try {
      final docId = '${mentorId}_$followerId';
      final batch = _db.batch();

      batch.set(
        _db.collection(_kMentorFollowers).doc(docId),
        {
          'mentorId': mentorId,
          'followerId': followerId,
          'followedAt': FieldValue.serverTimestamp(),
        },
      );

      // Tăng followerCount trong mentor_profiles
      batch.update(
        _db.collection(_kMentorProfiles).doc(mentorId),
        {'followerCount': FieldValue.increment(1)},
      );

      await batch.commit();
      developer.log('followMentor: mentorId=$mentorId followerId=$followerId', name: 'MentorService');
    } catch (e) {
      developer.log('followMentor error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Unfollow mentor.
  Future<void> unfollowMentor(String mentorId, String followerId) async {
    try {
      final docId = '${mentorId}_$followerId';
      final batch = _db.batch();

      batch.delete(_db.collection(_kMentorFollowers).doc(docId));

      batch.update(
        _db.collection(_kMentorProfiles).doc(mentorId),
        {'followerCount': FieldValue.increment(-1)},
      );

      await batch.commit();
      developer.log('unfollowMentor: mentorId=$mentorId followerId=$followerId', name: 'MentorService');
    } catch (e) {
      developer.log('unfollowMentor error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Kiểm tra xem followerId có đang follow mentorId không.
  Future<bool> isFollowingMentor(String mentorId, String followerId) async {
    try {
      final docId = '${mentorId}_$followerId';
      final doc = await _db.collection(_kMentorFollowers).doc(docId).get();
      return doc.exists;
    } catch (e) {
      developer.log('isFollowingMentor error: $e', name: 'MentorService');
      return false;
    }
  }

  /// Lấy danh sách followerId của mentor (để gửi notification).
  Future<List<String>> getMentorFollowerIds(String mentorId) async {
    try {
      final snap = await _db
          .collection(_kMentorFollowers)
          .where('mentorId', isEqualTo: mentorId)
          .get();
      return snap.docs
          .map((d) => d.data()['followerId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      developer.log('getMentorFollowerIds error: $e', name: 'MentorService');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4.3. LIVESTREAM CRUD
  // ──────────────────────────────────────────────────────────────────────────

  /// Tạo stream mới — trả về streamId (dùng làm Agora channel).
  Future<String> createLivestream(LivestreamModel stream) async {
    try {
      final docRef = _db.collection(_kLivestreams).doc();
      final streamWithId = stream.copyWith(
        id: docRef.id,
        agoraChannel: docRef.id,
      );
      await docRef.set(streamWithId.toMap());

      // Tăng totalStreams trong mentor_profiles
      await _db.collection(_kMentorProfiles).doc(stream.mentorId).update({
        'totalStreams': FieldValue.increment(1),
      });

      developer.log('createLivestream: streamId=${docRef.id}', name: 'MentorService');
      return docRef.id;
    } catch (e) {
      developer.log('createLivestream error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Kết thúc stream — cập nhật status và endedAt.
  Future<void> endLivestream(String streamId) async {
    try {
      await _db.collection(_kLivestreams).doc(streamId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
      developer.log('endLivestream: streamId=$streamId', name: 'MentorService');
    } catch (e) {
      developer.log('endLivestream error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Stream realtime danh sách livestreams đang live.
  Stream<List<LivestreamModel>> getLivestreams({String? gameFilter}) {
    Query query = _db
        .collection(_kLivestreams)
        .where('status', isEqualTo: 'live');

    if (gameFilter != null && gameFilter.isNotEmpty) {
      query = query.where('game', isEqualTo: gameFilter);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) =>
              LivestreamModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Sắp xếp: Nhiều người xem nhất lên đầu, nếu bằng nhau thì stream mới nhất lên đầu
      list.sort((a, b) {
        final cmp = b.viewerCount.compareTo(a.viewerCount);
        if (cmp != 0) return cmp;
        return b.startedAt.compareTo(a.startedAt);
      });
      return list;
    });
  }

  /// Cập nhật số viewer của stream.
  Future<void> updateViewerCount(String streamId, int count) async {
    try {
      await _db.collection(_kLivestreams).doc(streamId).update({
        'viewerCount': count,
      });
    } catch (e) {
      developer.log('updateViewerCount error: $e', name: 'MentorService');
    }
  }

  /// Tăng/giảm số viewer của stream (sử dụng FieldValue.increment).
  Future<void> incrementViewerCount(String streamId, int amount) async {
    try {
      await _db.collection(_kLivestreams).doc(streamId).update({
        'viewerCount': FieldValue.increment(amount),
      });
    } catch (e) {
      developer.log('incrementViewerCount error: $e', name: 'MentorService');
    }
  }

  /// Gửi message vào stream.
  Future<void> sendStreamMessage(
    String streamId,
    Map<String, dynamic> message,
  ) async {
    try {
      await _db
          .collection(_kLivestreams)
          .doc(streamId)
          .collection('messages')
          .add({
        ...message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('sendStreamMessage error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Stream realtime messages trong livestream.
  Stream<List<Map<String, dynamic>>> getStreamMessages(String streamId) {
    return _db
        .collection(_kLivestreams)
        .doc(streamId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4.4. GIFT & COIN SYSTEM
  // ──────────────────────────────────────────────────────────────────────────

  /// Tặng gift — atomic batch: trừ coin user, cộng coin mentor, ghi log.
  Future<void> sendGift({
    required String fromUserId,
    required String toMentorId,
    required String streamId,
    required String giftType,
    required int coinValue,
    required String fromUsername,
    required String fromAvatarUrl,
  }) async {
    try {
      final batch = _db.batch();

      // Trừ coin từ user
      batch.update(
        _db.collection('users').doc(fromUserId),
        {'coins': FieldValue.increment(-coinValue)},
      );

      // Cộng coin cho mentor
      batch.update(
        _db.collection('users').doc(toMentorId),
        {
          'coins': FieldValue.increment(coinValue),
          'totalCoinsReceived': FieldValue.increment(coinValue),
        },
      );

      // Cập nhật totalGiftsReceived trong mentor_profiles
      batch.update(
        _db.collection(_kMentorProfiles).doc(toMentorId),
        {'totalGiftsReceived': FieldValue.increment(coinValue)},
      );

      // Ghi transaction log
      final txRef = _db.collection(_kCoinTransactions).doc();
      batch.set(txRef, {
        'fromUserId': fromUserId,
        'toMentorId': toMentorId,
        'giftType': giftType,
        'coinValue': coinValue,
        'streamId': streamId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Gửi gift message vào stream
      final msgRef = _db
          .collection(_kLivestreams)
          .doc(streamId)
          .collection('messages')
          .doc();
      batch.set(msgRef, {
        'userId': fromUserId,
        'username': fromUsername,
        'avatarUrl': fromAvatarUrl,
        'text': '',
        'type': 'gift',
        'giftType': giftType,
        'giftCoinValue': coinValue,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      developer.log('sendGift: $fromUserId → $toMentorId | $giftType ($coinValue coins)', name: 'MentorService');
    } catch (e) {
      developer.log('sendGift error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Lấy số coin hiện có của user.
  Future<int> getUserCoins(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return (doc.data()?['coins'] ?? 0).toInt();
    } catch (e) {
      developer.log('getUserCoins error: $e', name: 'MentorService');
      return 0;
    }
  }

  /// Admin cấp coin cho user (dùng để test).
  Future<void> grantCoins(String userId, int amount) async {
    try {
      await _db.collection('users').doc(userId).update({
        'coins': FieldValue.increment(amount),
      });
      developer.log('grantCoins: userId=$userId amount=$amount', name: 'MentorService');
    } catch (e) {
      developer.log('grantCoins error: $e', name: 'MentorService');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4.5. MENTOR MATCH REQUEST
  // ──────────────────────────────────────────────────────────────────────────

  /// Gửi match request tới mentor.
  Future<void> sendMentorMatchRequest(
    String fromUserId,
    String toMentorId,
    String? message,
  ) async {
    try {
      await _db.collection(_kMentorMatchRequests).add({
        'fromUserId': fromUserId,
        'toMentorId': toMentorId,
        'status': 'pending',
        'message': message ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });
      developer.log('sendMentorMatchRequest: from=$fromUserId to=$toMentorId', name: 'MentorService');
    } catch (e) {
      developer.log('sendMentorMatchRequest error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Mentor: stream danh sách match requests đang pending.
  Stream<List<MentorMatchRequestModel>> getMentorMatchRequests(String mentorId) {
    return _db
        .collection(_kMentorMatchRequests)
        .where('toMentorId', isEqualTo: mentorId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) =>
              MentorMatchRequestModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Mentor chấp nhận request → tạo match thật trong collection matches.
  Future<void> acceptMentorMatchRequest(
    String requestId,
    String fromUserId,
    String mentorId,
  ) async {
    try {
      final batch = _db.batch();

      // Update request status
      batch.update(
        _db.collection(_kMentorMatchRequests).doc(requestId),
        {
          'status': 'accepted',
          'respondedAt': FieldValue.serverTimestamp(),
        },
      );

      // Tạo match thật trong collection matches (dùng format hiện có)
      final matchRef = _db.collection('matches').doc();
      batch.set(matchRef, {
        'userIds': [fromUserId, mentorId],
        'status': 'confirmed',
        'matchedAt': FieldValue.serverTimestamp(),
        'isMentorMatch': true,
        'mentorId': mentorId,
      });

      await batch.commit();
      developer.log('acceptMentorMatchRequest: requestId=$requestId', name: 'MentorService');
    } catch (e) {
      developer.log('acceptMentorMatchRequest error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Mentor từ chối request.
  Future<void> rejectMentorMatchRequest(String requestId) async {
    try {
      await _db.collection(_kMentorMatchRequests).doc(requestId).update({
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });
      developer.log('rejectMentorMatchRequest: requestId=$requestId', name: 'MentorService');
    } catch (e) {
      developer.log('rejectMentorMatchRequest error: $e', name: 'MentorService');
      rethrow;
    }
  }

  /// Kiểm tra đã có match request từ user đến mentor chưa.
  /// Trả về requestId nếu đã tồn tại, null nếu chưa.
  Future<String?> checkExistingMatchRequest(
    String fromUserId,
    String toMentorId,
  ) async {
    try {
      final snap = await _db
          .collection(_kMentorMatchRequests)
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toMentorId', isEqualTo: toMentorId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    } catch (e) {
      developer.log('checkExistingMatchRequest error: $e', name: 'MentorService');
      return null;
    }
  }

  /// Đánh giá Mentor (sử dụng Firestore transaction để tính toán rating trung bình)
  Future<void> rateMentor({
    required String fromUserId,
    required String toMentorId,
    required double rating,
    required String comment,
  }) async {
    try {
      final ratingDocRef = _db.collection('mentor_ratings').doc('${fromUserId}_$toMentorId');
      final mentorRef = _db.collection('mentor_profiles').doc(toMentorId);

      await _db.runTransaction((transaction) async {
        final ratingSnapshot = await transaction.get(ratingDocRef);
        final mentorSnapshot = await transaction.get(mentorRef);

        if (!mentorSnapshot.exists) {
          throw Exception("Không tìm thấy hồ sơ Mentor");
        }

        final mentorData = mentorSnapshot.data()!;
        double currentRating = (mentorData['rating'] ?? 0.0).toDouble();
        int currentReviews = (mentorData['totalReviews'] ?? 0).toInt();

        double newRating;
        int newReviews;

        if (ratingSnapshot.exists) {
          double oldRating = (ratingSnapshot.data()!['rating'] ?? 0.0).toDouble();
          newReviews = currentReviews;
          newRating = currentReviews > 0
              ? ((currentRating * currentReviews) - oldRating + rating) / currentReviews
              : rating;
        } else {
          newReviews = currentReviews + 1;
          newRating = ((currentRating * currentReviews) + rating) / newReviews;
        }

        transaction.set(ratingDocRef, {
          'fromUserId': fromUserId,
          'toMentorId': toMentorId,
          'rating': rating,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(mentorRef, {
          'rating': newRating,
          'totalReviews': newReviews,
        });
      });
      developer.log('rateMentor success: from=$fromUserId to=$toMentorId rating=$rating', name: 'MentorService');
    } catch (e) {
      developer.log('rateMentor error: $e', name: 'MentorService');
      rethrow;
    }
  }
}

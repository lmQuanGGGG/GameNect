part of '../firestore_service.dart';

// ==================== MATCH OPERATIONS ====================
// Quản lý tạo, cập nhật và truy vấn matches giữa users

extension MatchServiceExtension on FirestoreService {
  // Tạo match đơn giản (dùng MatchModel trực tiếp)
  Future<void> createMatch(MatchModel match) {
    return matches.doc(match.id).set(match.toMap());
  }

  // Lấy danh sách matches đang active
  Future<List<MatchModel>> getActiveMatches() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => MatchModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Tạo match mới (auto-confirm cả hai user)
  Future<String> createNewMatch({
    required List<String> userIds,
    required String game,
    DateTime? expiresAt,
  }) async {
    try {
      final matchData = {
        'userIds': userIds,
        'game': game,
        'matchedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'confirmations': {for (var id in userIds) id: true},
        'status': MatchStatus.confirmed,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt?.toIso8601String(),
      };

      final docRef = await _db.collection('matches').add(matchData);
      developer.log('Đã tạo match mới: ${docRef.id}', name: 'FirestoreService');
      return docRef.id;
    } catch (e) {
      developer.log('Lỗi khi tạo match: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  // Kiểm tra đã có match giữa 2 user chưa
  Future<MatchModel?> getMatchBetweenUsers(String userId1, String userId2) async {
    try {
      final snapshot = await _db
          .collection('matches')
          .where('userIds', arrayContains: userId1)
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        final match = MatchModel.fromMap(doc.data(), doc.id);
        if (match.userIds.contains(userId2)) {
          developer.log('Tìm thấy match giữa $userId1 và $userId2', name: 'FirestoreService');
          return match;
        }
      }

      developer.log('Không có match giữa $userId1 và $userId2', name: 'FirestoreService');
      return null;
    } catch (e) {
      developer.log('Lỗi khi tìm match: $e', name: 'FirestoreService', error: e);
      return null;
    }
  }

  // Cập nhật confirmation của user trong match
  Future<void> updateMatchConfirmation({
    required String matchId,
    required String userId,
    required bool confirmed,
  }) async {
    try {
      await _db.collection('matches').doc(matchId).update({
        'confirmations.$userId': confirmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      developer.log('Đã cập nhật confirmation: $matchId', name: 'FirestoreService');
    } catch (e) {
      developer.log('Lỗi khi cập nhật confirmation: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  // Stream theo dõi matches của user real-time
  Stream<List<MatchModel>> getUserMatchesStream(String userId) {
    return _db
        .collection('matches')
        .where('userIds', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MatchModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Lấy danh sách userId đã match confirmed với user
  Future<List<String>> getMatchedUserIds(String currentUserId) async {
    final snapshot = await _db
        .collection('matches')
        .where('userIds', arrayContains: currentUserId)
        .where('status', isEqualTo: 'confirmed')
        .get();

    final matchedIds = <String>{};
    for (var doc in snapshot.docs) {
      final ids = List<String>.from(doc['userIds'] ?? []);
      matchedIds.addAll(ids.where((id) => id != currentUserId));
    }
    return matchedIds.toList();
  }

  // Lấy raw documents của matches (dùng khi cần flexibility)
  Future<List<QueryDocumentSnapshot>> getMatchDocsForUser(String userId) async {
    try {
      final snapshot = await _db
          .collection('matches')
          .where('userIds', arrayContains: userId)
          .where('status', isEqualTo: 'confirmed')
          .get();

      debugPrint('Found ${snapshot.docs.length} match documents for user');
      return snapshot.docs;
    } catch (e) {
      debugPrint('Error getting match docs: $e');
      return [];
    }
  }

  // Lấy hoặc tạo matchId giữa 2 user
  Future<String> getOrCreateMatchId(String userA, String userB) async {
    final snap = await FirebaseFirestore.instance
        .collection('matches')
        .where('userIds', arrayContains: userA)
        .get();

    for (var doc in snap.docs) {
      final userIds = List<String>.from(doc['userIds'] ?? []);
      if (userIds.contains(userB)) {
        return doc.id;
      }
    }

    // Chưa có → tạo mới
    final newDoc = await FirebaseFirestore.instance.collection('matches').add({
      'userIds': [userA, userB],
      'status': 'confirmed',
      'createdAt': DateTime.now(),
    });
    return newDoc.id;
  }

  // Hủy match: set cancelled + xóa cross-reference trong moments
  Future<void> unmatch(String matchId) async {
    try {
      final matchDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get();

      if (matchDoc.exists) {
        final userIds = List<String>.from(matchDoc.data()?['userIds'] ?? []);

        if (userIds.length == 2) {
          final userId1 = userIds[0];
          final userId2 = userIds[1];

          // Cập nhật match status
          await FirebaseFirestore.instance
              .collection('matches')
              .doc(matchId)
              .update({
                'status': 'cancelled',
                'cancelledAt': FieldValue.serverTimestamp(),
                'isActive': false,
              });

          // Xóa cross-reference trong moments (batch)
          final batch = FirebaseFirestore.instance.batch();

          final moments1 = await FirebaseFirestore.instance
              .collection('moments')
              .where('userId', isEqualTo: userId1)
              .where('matchIds', arrayContains: userId2)
              .get();

          for (var doc in moments1.docs) {
            batch.update(doc.reference, {
              'matchIds': FieldValue.arrayRemove([userId2]),
            });
          }

          final moments2 = await FirebaseFirestore.instance
              .collection('moments')
              .where('userId', isEqualTo: userId2)
              .where('matchIds', arrayContains: userId1)
              .get();

          for (var doc in moments2.docs) {
            batch.update(doc.reference, {
              'matchIds': FieldValue.arrayRemove([userId1]),
            });
          }

          await batch.commit();
          developer.log('Match cancelled and moments updated: $matchId', name: 'FirestoreService');
        }
      }
    } catch (e) {
      developer.log('Error unmatching: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }
}

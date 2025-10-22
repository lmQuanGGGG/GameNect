import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../models/match_model.dart';
import '../models/swipe_history_model.dart';
import '../models/moment_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CollectionReference users = FirebaseFirestore.instance.collection('users');
  final CollectionReference matches = FirebaseFirestore.instance.collection('matches');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  FirebaseFirestore get db => _db;

  Future<String?> uploadImage(File image, String userId, String path) async {
    try {
      final ref = _storage.ref().child('users/$userId/$path');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Không thể tải ảnh lên: $e');
    }
  }

  Future<void> addUser(UserModel user) {
    return users.doc(user.id).set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> createMatch(MatchModel match) {
    return matches.doc(match.id).set(match.toMap());
  }

  Future<UserModel?> getUser(String userId) async {
    DocumentSnapshot doc = await users.doc(userId).get();
    return doc.exists
        ? UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)
        : null;
  }

  Future<List<UserModel>> getAllUsers() async {
    QuerySnapshot snapshot = await users.get();
    return snapshot.docs
        .map(
          (doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<List<MatchModel>> getActiveMatches() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => MatchModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<UserModel?> getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await users.doc(user.uid).get();
    return doc.exists
        ? UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)
        : null;
  }

  // Cập nhật thông tin user
  Future<void> updateUser(UserModel user) async {
    try {
      await _db
          .collection('users')
          .doc(user.id)
          .update(user.toMap());
    } catch (e) {
      throw Exception('Không thể cập nhật thông tin người dùng: $e');
    }
  }

  /// Cập nhật location của user
  Future<void> updateUserLocation(
    String userId,
    Map<String, dynamic> locationData,
  ) async {
    try {
      await _db.collection('users').doc(userId).update(locationData);
      developer.log('Đã cập nhật location vào Firestore', name: 'FirestoreService');
    } catch (e) {
      developer.log('Lỗi khi cập nhật location: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  /// Cập nhật max distance cho matching
  Future<void> updateMaxDistance(String userId, double maxDistance) async {
    try {
      await _db.collection('users').doc(userId).update({
        'maxDistance': maxDistance,
      });
      developer.log('Đã cập nhật max distance: $maxDistance km', name: 'FirestoreService');
    } catch (e) {
      developer.log('Lỗi khi cập nhật max distance: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  /// Cập nhật location settings (maxDistance và showDistance) - METHOD MỚI
  Future<void> updateLocationSettings(
    String userId, {
    double? maxDistance,
    bool? showDistance,
    int? minAge,
    int? maxAge,
    String? interestedInGender,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      
      if (maxDistance != null) {
        updates['maxDistance'] = maxDistance;
      }
      
      if (showDistance != null) {
        updates['showDistance'] = showDistance;
      }
      
      if (minAge != null) {
        updates['minAge'] = minAge;
      }
      
      if (maxAge != null) {
        updates['maxAge'] = maxAge;
      }
      
      if (interestedInGender != null) {
        updates['interestedInGender'] = interestedInGender;
      }
      
      if (updates.isNotEmpty) {
        await _db.collection('users').doc(userId).update(updates);
        developer.log('Đã cập nhật location settings: $updates', name: 'FirestoreService');
      } else {
        developer.log('Không có settings nào để cập nhật', name: 'FirestoreService');
      }
    } catch (e) {
      developer.log('Lỗi khi cập nhật location settings: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  /// Lấy user theo ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
      }
      
      return null;
    } catch (e) {
      developer.log('Lỗi khi lấy user: $e', name: 'FirestoreService', error: e);
      return null;
    }
  }

  /// Lấy users trong bán kính
  Future<List<UserModel>> getUsersWithinRadius({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? excludeUserId,
    int limit = 50,
  }) async {
    try {
      developer.log('Đang tìm users trong bán kính $radiusKm km...', name: 'FirestoreService');
      
      // Tính bounds của bán kính
      final latDelta = radiusKm / 111.0;
      final lonDelta = radiusKm / (111.0 * cos(latitude * pi / 180));

      final minLat = latitude - latDelta;
      final maxLat = latitude + latDelta;
      final minLon = longitude - lonDelta;
      final maxLon = longitude + lonDelta;

      developer.log('Bounds: lat[$minLat, $maxLat], lon[$minLon, $maxLon]', name: 'FirestoreService');

      Query query = _db
          .collection('users')
          .where('latitude', isGreaterThanOrEqualTo: minLat)
          .where('latitude', isLessThanOrEqualTo: maxLat);
      
      if (excludeUserId != null) {
        query = query.where('id', isNotEqualTo: excludeUserId);
      }
      
      final snapshot = await query.limit(limit).get();

      developer.log('Tìm thấy ${snapshot.docs.length} users trong bounds', name: 'FirestoreService');

      final users = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return null;
            return UserModel.fromMap(data, doc.id);
          })
          .whereType<UserModel>()
          .where((user) {
            if (user.longitude == null || user.latitude == null) {
              return false;
            }
            
            if (user.longitude! < minLon || user.longitude! > maxLon) {
              return false;
            }
            
            return true;
          })
          .toList();

      developer.log('Còn lại ${users.length} users sau khi filter', name: 'FirestoreService');

      return users;
    } catch (e) {
      developer.log('Lỗi khi query users: $e', name: 'FirestoreService', error: e);
      return [];
    }
  }

  /// Stream theo dõi thay đổi user
  Stream<UserModel?> getUserStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return UserModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
          }
          return null;
        });
  }

  /// Cập nhật một field cụ thể
  Future<void> updateUserField(
    String userId,
    String field,
    dynamic value,
  ) async {
    try {
      await _db.collection('users').doc(userId).update({
        field: value,
      });
      developer.log('Đã cập nhật $field', name: 'FirestoreService');
    } catch (e) {
      developer.log('Lỗi khi cập nhật $field: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  /// Cập nhật nhiều fields cùng lúc
  Future<void> updateUserFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    try {
      if (fields.isEmpty) {
        developer.log('Không có field nào để cập nhật', name: 'FirestoreService');
        return;
      }

      await _db.collection('users').doc(userId).update(fields);
      developer.log('Đã cập nhật ${fields.length} fields', name: 'FirestoreService');
    } catch (e) {
      developer.log('Lỗi khi cập nhật fields: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  /// Kiểm tra user có tồn tại không
  Future<bool> userExists(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      developer.log('Lỗi khi kiểm tra user: $e', name: 'FirestoreService', error: e);
      return false;
    }
  }

  /// Xóa user
  Future<void> deleteUser(String userId) async {
    try {
      await _db.collection('users').doc(userId).delete();
      developer.log('Đã xóa user', name: 'FirestoreService');
    } catch (e) {
      developer.log('Lỗi khi xóa user: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  /// Lấy lịch sử match của user
  Future<List<MatchModel>> getUserMatchHistory(String userId, {int limit = 50}) async {
    try {
      final snap = await matches
          .where('userIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((d) => MatchModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    } catch (e) {
      developer.log('Lỗi lấy lịch sử match: $e', name: 'FirestoreService', error: e);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserMapById(String userId) async {
    final doc = await users.doc(userId).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  // ==================== SWIPE HISTORY ====================

/// Lưu lịch sử quẹt
Future<void> saveSwipeHistory({
  required String userId,
  required String targetUserId,
  required String action,
}) async {
  try {
    final now = DateTime.now();
    
    // 1. Log vào swipe_history (giữ 30 ngày, sau đó Firestore tự xóa)
    await _db.collection('swipe_history').add({
      'userId': userId,
      'targetUserId': targetUserId,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 60))), // TTL
    });
    
    // 2. Upsert vào swipe_latest (trạng thái mới nhất - query nhanh)
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

/// Lấy danh sách user đã quẹt (để lọc ra khỏi recommendations)
Future<List<String>> getSwipedUserIds(String userId) async {
  try {
    final snapshot = await _db
        .collection('swipe_history')
        .where('userId', isEqualTo: userId)
        .get();
    
    final swipedIds = snapshot.docs
        .map((doc) => doc.data()['targetUserId'] as String)
        .toSet() // Dùng Set để loại bỏ trùng lặp
        .toList();
    
    developer.log('User đã quẹt ${swipedIds.length} người', name: 'FirestoreService');
    return swipedIds;
  } catch (e) {
    developer.log('Lỗi khi lấy swipe history: $e', name: 'FirestoreService', error: e);
    return [];
  }
}

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

/// Kiểm tra xem target có like mình lại không (mutual like)
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

/// Lấy lịch sử swipe 'dislike' của user, có giới hạn số lượng
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

/// Lấy lịch sử swipe 'like' của user, có giới hạn số lượng
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

// ==================== MATCH MANAGEMENT ====================

/// Tạo match mới (overload method mới, giữ nguyên method cũ)
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
      // Cập nhật xác nhận cho cả hai user
      'confirmations': {
        for (var id in userIds) id: true,
      },
      'status': MatchStatus.confirmed, // Đổi thành confirmed
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

/// Lấy match giữa 2 user (kiểm tra đã match chưa)
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

/// Cập nhật confirmation của match
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

/// Lấy danh sách matches pending của user (chưa confirm)
Future<List<MatchModel>> getPendingMatches(String userId) async {
  try {
    final snapshot = await _db
        .collection('matches')
        .where('userIds', arrayContains: userId)
        .where('status', whereIn: [MatchStatus.pending, MatchStatus.partial])
        .where('isActive', isEqualTo: true)
        .get();
    
    final matches = snapshot.docs
        .map((doc) => MatchModel.fromMap(doc.data(), doc.id))
        .toList();
    
    developer.log('User có ${matches.length} match pending', name: 'FirestoreService');
    return matches;
  } catch (e) {
    developer.log('Lỗi khi lấy pending matches: $e', name: 'FirestoreService', error: e);
    return [];
  }
}

/// Stream theo dõi matches của user
Stream<List<MatchModel>> getUserMatchesStream(String userId) {
  return _db
      .collection('matches')
      .where('userIds', arrayContains: userId)
      .where('isActive', isEqualTo: true)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => MatchModel.fromMap(doc.data(), doc.id))
            .toList();
      });
}

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

Future<List<Map<String, dynamic>>> getMessages(String matchId) async {
  final snapshot = await _db.collection('chats').doc(matchId).collection('messages').orderBy('timestamp').get();
  return snapshot.docs.map((doc) => doc.data()).toList();
}

Future<void> sendMessage(String matchId, String text) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  
  // Lưu tin nhắn vào chats
  await FirebaseFirestore.instance
      .collection('chats')
      .doc(matchId)
      .collection('messages')
      .add({
        'senderId': userId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text', // ← THÊM FIELD NÀY
      });

  // Cập nhật lastMessage vào matches
  await FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': userId,
      });
}
Future<void> sendMessageWithMedia({
  required String matchId,
  required String text,
  String? mediaUrl,
  bool isVideo = false,
}) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  
  await FirebaseFirestore.instance
      .collection('chats')
      .doc(matchId)
      .collection('messages')
      .add({
        'senderId': userId,
        'text': text,
        'mediaUrl': mediaUrl,
        'isVideo': isVideo,
        'timestamp': FieldValue.serverTimestamp(), // DÙNG serverTimestamp
      });

  await FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(), // SỬA ĐÂY
        'lastMediaUrl': mediaUrl,
        'lastIsVideo': isVideo,
        'lastMessageSenderId': userId,
      });
}

Future<void> addCallMessage({
  required String matchId,
  String? senderId,
  required int duration,
  bool missed = false,
  bool declined = false,
  bool cancelled = false,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  final uid = senderId ?? user?.uid;
  if (uid == null) return;

  String callStatus;
  String text;
  
  if (cancelled) {
    callStatus = 'cancelled';
    text = 'Đã hủy';
  } else if (declined) {
    callStatus = 'declined';
    text = 'Cuộc gọi bị từ chối';
  } else if (missed) {
    callStatus = 'missed';
    text = 'Cuộc gọi nhỡ';
  } else {
    callStatus = 'ended';
    final minutes = duration ~/ 60;
    final secs = duration % 60;
    if (minutes > 0) {
      text = 'Đã gọi $minutes phút${secs > 0 ? ' $secs giây' : ''}';
    } else {
      text = 'Đã gọi $secs giây';
    }
  }

  await FirebaseFirestore.instance
      .collection('chats')
      .doc(matchId)
      .collection('messages')
      .add({
    'senderId': uid,
    'text': text,
    'timestamp': FieldValue.serverTimestamp(),
    'type': 'call',
    'callStatus': callStatus,
    'duration': duration,
  });
  
  // Cập nhật lastMessage trong match document
  await FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(), // SỬA ĐÂY
        'lastMessageSenderId': uid,
      });
}

Future<bool> canPostMoment(String userId) async {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  // Kiểm tra premium trước
  final user = await getUser(userId);
  final isPremium = user?.isPremium ?? false;
  if (isPremium) return true;

  // Đếm số moment trong tháng bằng count (nhanh, chính xác)
  try {
    final query = _db
        .collection('moments')
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: startOfMonth);

    final agg = await query.count().get();
    final total = agg.count ?? 0;

    return total < 20;
  } catch (e) {
    developer.log('canPostMoment error: $e', name: 'FirestoreService', error: e);
    return false;
  }
}

Future<void> postMoment({
  required String userId,
  required String mediaUrl,
  required bool isVideo,
  required List<String> matchIds,
  String? caption,
  String? thumbnailUrl,
}) async {
  // Kiểm tra giới hạn trước
  if (!await canPostMoment(userId)) {
    throw Exception('LIMIT_EXCEEDED'); // Throw mã lỗi đặc biệt
  }

  final visibleToUserIds = <String>{userId, ...matchIds};

  developer.log('Posting moment visible to: $visibleToUserIds', name: 'FirestoreService');

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
    developer.log('Moment saved successfully with ${visibleToUserIds.length} visible users', name: 'FirestoreService');
  } catch (e) {
    developer.log('Error saving moment: $e', name: 'FirestoreService', error: e);
    rethrow;
  }
}

// FIX: Dùng arrayContains thay vì whereIn để tránh giới hạn 10 phần tử
Future<List<MomentModel>> getMomentsForUser(String userId, List<String> matchIds) async {
  final snap = await FirebaseFirestore.instance
      .collection('moments')
      .where('matchIds', arrayContains: userId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .get();
  
  return snap.docs.map((doc) => MomentModel.fromMap(doc.data(), doc.id)).toList();
}

Future<void> addReactionToMoment(String momentId, String userId, String emoji) async {
  await FirebaseFirestore.instance.collection('moments').doc(momentId).update({
    'reactions': FieldValue.arrayUnion([
      {'userId': userId, 'emoji': emoji}
    ])
  });
}

Future<void> addReplyToMoment(String momentId, String userId, String text) async {
  await FirebaseFirestore.instance.collection('moments').doc(momentId).update({
    'replies': FieldValue.arrayUnion([
      {
        'userId': userId,
        'text': text,
        'repliedAt': Timestamp.now()
      }
    ])
  });
}

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
  // Nếu chưa có, tạo mới
  final newDoc = await FirebaseFirestore.instance.collection('matches').add({
    'userIds': [userA, userB],
    'status': 'confirmed',
    'createdAt': DateTime.now(),
  });
  return newDoc.id;
}

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
        
        // 1. Cập nhật match status
        await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'isActive': false,
        });
        
        // 2. Xóa userId khỏi matchIds của moments
        final batch = FirebaseFirestore.instance.batch();
        
        // Xóa userId2 khỏi moments của userId1
        final moments1 = await FirebaseFirestore.instance
            .collection('moments')
            .where('userId', isEqualTo: userId1)
            .where('matchIds', arrayContains: userId2)
            .get();
        
        for (var doc in moments1.docs) {
          batch.update(doc.reference, {
            'matchIds': FieldValue.arrayRemove([userId2])
          });
        }
        
        // Xóa userId1 khỏi moments của userId2
        final moments2 = await FirebaseFirestore.instance
            .collection('moments')
            .where('userId', isEqualTo: userId2)
            .where('matchIds', arrayContains: userId1)
            .get();
        
        for (var doc in moments2.docs) {
          batch.update(doc.reference, {
            'matchIds': FieldValue.arrayRemove([userId1])
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

Future<Map<String, dynamic>?> getLastMessage(String matchId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data();
    }
    return null;
  } catch (e) {
    debugPrint('Error getting last message: $e');
    return null;
  }
}

Stream<List<Map<String, dynamic>>> messagesStream(String matchId) {
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(matchId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // Thêm id để tracking
          return data;
        }).toList();
      });
}
}
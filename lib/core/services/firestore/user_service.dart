part of '../firestore_service.dart';

// ==================== USER OPERATIONS ====================
// Quản lý CRUD cho user, location, settings

extension UserServiceExtension on FirestoreService {
  // Upload ảnh lên Firebase Storage
  Future<String?> uploadImage(File image, String userId, String path) async {
    try {
      final ref = _storage.ref().child('users/$userId/$path');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Không thể tải ảnh lên: $e');
    }
  }

  // Thêm hoặc cập nhật thông tin user (merge để không ghi đè)
  Future<void> addUser(UserModel user) {
    return users.doc(user.id).set(user.toMap(), SetOptions(merge: true));
  }

  // Lấy thông tin user theo ID
  Future<UserModel?> getUser(String userId) async {
    final doc = await users.doc(userId).get();
    return doc.exists
        ? UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)
        : null;
  }

  // Lấy danh sách tất cả users
  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await users.get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // Lấy thông tin user đang đăng nhập
  Future<UserModel?> getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await users.doc(user.uid).get();
    return doc.exists
        ? UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)
        : null;
  }

  // Cập nhật toàn bộ thông tin user
  Future<void> updateUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      throw Exception('Không thể cập nhật thông tin người dùng: $e');
    }
  }

  // Cập nhật vị trí địa lý của user
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

  // Cập nhật bán kính tìm kiếm tối đa
  Future<void> updateMaxDistance(String userId, double maxDistance) async {
    try {
      await _db.collection('users').doc(userId).update({'maxDistance': maxDistance});
      developer.log('Đã cập nhật max distance: $maxDistance km', name: 'FirestoreService');
    } catch (e) {
      developer.log('Lỗi khi cập nhật max distance: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  // Cập nhật các cài đặt vị trí và filter
  Future<void> updateLocationSettings(
    String userId, {
    double? maxDistance,
    bool? showDistance,
    int? minAge,
    int? maxAge,
    String? interestedInGender,
    bool? filterCommonGame,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (maxDistance != null) updates['maxDistance'] = maxDistance;
      if (showDistance != null) updates['showDistance'] = showDistance;
      if (minAge != null) updates['minAge'] = minAge;
      if (maxAge != null) updates['maxAge'] = maxAge;
      if (interestedInGender != null) updates['interestedInGender'] = interestedInGender;
      if (filterCommonGame != null) updates['filterCommonGame'] = filterCommonGame;

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

  // Lấy user theo ID (alias của getUser)
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

  // Tìm users trong bán kính địa lý (dùng bounding box + filter)
  Future<List<UserModel>> getUsersWithinRadius({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? excludeUserId,
    int limit = 50,
  }) async {
    try {
      developer.log('Đang tìm users trong bán kính $radiusKm km...', name: 'FirestoreService');

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

      final result = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return null;
            return UserModel.fromMap(data, doc.id);
          })
          .whereType<UserModel>()
          .where((user) {
            if (user.longitude == null || user.latitude == null) return false;
            if (user.longitude! < minLon || user.longitude! > maxLon) return false;
            return true;
          })
          .toList();

      developer.log('Còn lại ${result.length} users sau khi filter', name: 'FirestoreService');
      return result;
    } catch (e) {
      developer.log('Lỗi khi query users: $e', name: 'FirestoreService', error: e);
      return [];
    }
  }

  // Stream theo dõi thay đổi real-time của user
  Stream<UserModel?> getUserStream(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  // Cập nhật một field cụ thể của user
  Future<void> updateUserField(String userId, String field, dynamic value) async {
    try {
      await _db.collection('users').doc(userId).update({field: value});
      developer.log('Đã cập nhật $field', name: 'FirestoreService');
    } catch (e) {
      developer.log('Lỗi khi cập nhật $field: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  // Cập nhật nhiều fields cùng lúc
  Future<void> updateUserFields(String userId, Map<String, dynamic> fields) async {
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

  // Kiểm tra user có tồn tại không
  Future<bool> userExists(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      developer.log('Lỗi khi kiểm tra user: $e', name: 'FirestoreService', error: e);
      return false;
    }
  }

  // Xóa user khỏi Firestore
  Future<void> deleteUser(String userId) async {
    try {
      await _db.collection('users').doc(userId).delete();
      developer.log('Đã xóa user', name: 'FirestoreService');
    } catch (e) {
      developer.log('Lỗi khi xóa user: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  // Lấy lịch sử match của user
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

  // Lấy dữ liệu user dưới dạng Map
  Future<Map<String, dynamic>?> getUserMapById(String userId) async {
    final doc = await users.doc(userId).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  // Toggle game yêu thích
  Future<bool> toggleFavoriteGame(String userId, GameDetailModel game) async {
    try {
      final docRef = _db
          .collection('users')
          .doc(userId)
          .collection('favoriteGames')
          .doc(game.id.toString());

      final doc = await docRef.get();

      if (doc.exists) {
        await docRef.delete();
        return false;
      } else {
        await docRef.set({
          'id': game.id,
          'name': game.name,
          'backgroundImage': game.backgroundImage,
          'rating': game.rating,
          'addedAt': FieldValue.serverTimestamp(),
          'genres': game.genres,
        });
        return true;
      }
    } catch (e) {
      developer.log('Error toggling favorite: $e', name: 'FirestoreService', error: e);
      rethrow;
    }
  }

  // Kiểm tra game đã được like chưa
  Future<bool> isGameFavorite(String userId, int gameId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('favoriteGames')
          .doc(gameId.toString())
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Stream danh sách game yêu thích
  Stream<List<Map<String, dynamic>>> getFavoriteGamesStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favoriteGames')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../models/match_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

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
      print('Đã cập nhật location vào Firestore');
    } catch (e) {
      print('Lỗi khi cập nhật location: $e');
      rethrow;
    }
  }

  /// Cập nhật max distance cho matching
  Future<void> updateMaxDistance(String userId, double maxDistance) async {
    try {
      await _db.collection('users').doc(userId).update({
        'maxDistance': maxDistance,
      });
      print('Đã cập nhật max distance: $maxDistance km');
    } catch (e) {
      print('Lỗi khi cập nhật max distance: $e');
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
        print('Đã cập nhật location settings: $updates');
      } else {
        print('Không có settings nào để cập nhật');
      }
    } catch (e) {
      print('Lỗi khi cập nhật location settings: $e');
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
      print('Lỗi khi lấy user: $e');
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
      print('Đang tìm users trong bán kính $radiusKm km...');
      
      // Tính bounds của bán kính
      // 1 độ latitude ≈ 111km
      // 1 độ longitude ≈ 111km * cos(latitude)
      final latDelta = radiusKm / 111.0;
      final lonDelta = radiusKm / (111.0 * cos(latitude * pi / 180));

      final minLat = latitude - latDelta;
      final maxLat = latitude + latDelta;
      final minLon = longitude - lonDelta;
      final maxLon = longitude + lonDelta;

      print('Bounds: lat[$minLat, $maxLat], lon[$minLon, $maxLon]');

      // Query Firestore với bounds
      Query query = _db
          .collection('users')
          .where('latitude', isGreaterThanOrEqualTo: minLat)
          .where('latitude', isLessThanOrEqualTo: maxLat);
      
      // Loại trừ user hiện tại nếu có
      if (excludeUserId != null) {
        query = query.where('id', isNotEqualTo: excludeUserId);
      }
      
      final snapshot = await query.limit(limit).get();

      print('Tìm thấy ${snapshot.docs.length} users trong bounds');

      // Cast doc.data() về Map<String, dynamic>
      final users = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return null;
            return UserModel.fromMap(data, doc.id);
          })
          .whereType<UserModel>() // Loại bỏ null values
          .where((user) {
            if (user.longitude == null || user.latitude == null) {
              return false;
            }
            
            // Check longitude bound
            if (user.longitude! < minLon || user.longitude! > maxLon) {
              return false;
            }
            
            return true;
          })
          .toList();

      print('Còn lại ${users.length} users sau khi filter');

      return users;
    } catch (e) {
      print('Lỗi khi query users: $e');
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
            // Cast về Map<String, dynamic>
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
      print('Đã cập nhật $field');
    } catch (e) {
      print('Lỗi khi cập nhật $field: $e');
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
        print('Không có field nào để cập nhật');
        return;
      }

      await _db.collection('users').doc(userId).update(fields);
      print('Đã cập nhật ${fields.length} fields');
    } catch (e) {
      print('Lỗi khi cập nhật fields: $e');
      rethrow;
    }
  }

  /// Kiểm tra user có tồn tại không
  Future<bool> userExists(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      print('Lỗi khi kiểm tra user: $e');
      return false;
    }
  }

  /// Xóa user
  Future<void> deleteUser(String userId) async {
    try {
      await _db.collection('users').doc(userId).delete();
      print('Đã xóa user');
    } catch (e) {
      print('Lỗi khi xóa user: $e');
      rethrow;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../models/match_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}
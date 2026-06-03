import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data'; // Uint8List cho uploadImageBytes (Web compatible)
import '../models/user_model.dart';
import '../models/match_model.dart';
import '../models/swipe_history_model.dart';
import '../models/moment_model.dart';
import '../models/mentor_model.dart';
import '../models/livestream_model.dart';
import '../models/mentor_match_request_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';

// Part files — mỗi file chứa một nhóm operations theo domain
part 'firestore/user_service.dart';
part 'firestore/swipe_service.dart';
part 'firestore/match_service.dart';
part 'firestore/chat_service.dart';
part 'firestore/moment_service.dart';
part 'firestore/mentor_service.dart';

/// FirestoreService — Service trung tâm quản lý tất cả thao tác với Firestore và Firebase Storage.
///
/// Được tổ chức theo domain (user, swipe, match, chat, moment) thông qua Dart `part` files.
/// Mọi code gọi `FirestoreService().method()` hoạt động bình thường, không cần thay đổi.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CollectionReference users = FirebaseFirestore.instance.collection('users');
  final CollectionReference matches = FirebaseFirestore.instance.collection('matches');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Truy cập Firestore instance từ bên ngoài nếu cần
  FirebaseFirestore get db => _db;
}

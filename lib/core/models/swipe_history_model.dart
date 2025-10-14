// core/models/swipe_history_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SwipeHistory {
  final String id;
  final String userId;
  final String targetUserId;
  final String action; // 'like' hoặc 'dislike'
  final DateTime timestamp;

  SwipeHistory({
    required this.id,
    required this.userId,
    required this.targetUserId,
    required this.action,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'targetUserId': targetUserId,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SwipeHistory.fromMap(Map<String, dynamic> map, String id) {
    return SwipeHistory(
      id: id,
      userId: map['userId'] ?? '',
      targetUserId: map['targetUserId'] ?? '',
      action: map['action'] ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
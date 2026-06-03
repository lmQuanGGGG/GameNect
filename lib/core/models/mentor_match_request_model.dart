import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho Match Request từ user tới Mentor.
/// Lưu trong collection `mentor_match_requests/{requestId}`.
class MentorMatchRequestModel {
  final String id;
  final String fromUserId;
  final String toMentorId;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const MentorMatchRequestModel({
    required this.id,
    required this.fromUserId,
    required this.toMentorId,
    this.status = 'pending',
    this.message,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toMentorId': toMentorId,
      'status': status,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }

  factory MentorMatchRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return MentorMatchRequestModel(
      id: id,
      fromUserId: map['fromUserId'] ?? '',
      toMentorId: map['toMentorId'] ?? '',
      status: map['status'] ?? 'pending',
      message: map['message'],
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      respondedAt: _parseTimestamp(map['respondedAt']),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  MentorMatchRequestModel copyWith({
    String? id,
    String? fromUserId,
    String? toMentorId,
    String? status,
    String? message,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return MentorMatchRequestModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toMentorId: toMentorId ?? this.toMentorId,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}

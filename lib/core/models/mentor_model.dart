import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho thông tin Mentor trong hệ thống.
/// Lưu trong collection `mentor_profiles/{userId}`.
class MentorModel {
  final String userId;
  final List<String> games;
  final String bio;
  final String achievements;
  final double rating;
  final int totalReviews;
  final int followerCount;
  final int totalStreams;
  final int totalGiftsReceived;
  final String status; // 'pending' | 'approved' | 'rejected' | 'none'
  final DateTime appliedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectReason;

  const MentorModel({
    required this.userId,
    required this.games,
    required this.bio,
    required this.achievements,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.followerCount = 0,
    this.totalStreams = 0,
    this.totalGiftsReceived = 0,
    required this.status,
    required this.appliedAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectReason,
  });

  /// Chuyển MentorModel thành Map để lưu vào Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'games': games,
      'bio': bio,
      'achievements': achievements,
      'rating': rating,
      'totalReviews': totalReviews,
      'followerCount': followerCount,
      'totalStreams': totalStreams,
      'totalGiftsReceived': totalGiftsReceived,
      'status': status,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'rejectReason': rejectReason,
    };
  }

  /// Tạo MentorModel từ Map lấy từ Firestore.
  factory MentorModel.fromMap(Map<String, dynamic> map, String userId) {
    return MentorModel(
      userId: userId,
      games: List<String>.from(map['games'] ?? []),
      bio: map['bio'] ?? '',
      achievements: map['achievements'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalReviews: (map['totalReviews'] ?? 0).toInt(),
      followerCount: (map['followerCount'] ?? 0).toInt(),
      totalStreams: (map['totalStreams'] ?? 0).toInt(),
      totalGiftsReceived: (map['totalGiftsReceived'] ?? 0).toInt(),
      status: map['status'] ?? 'none',
      appliedAt: _parseTimestamp(map['appliedAt']) ?? DateTime.now(),
      approvedAt: _parseTimestamp(map['approvedAt']),
      rejectedAt: _parseTimestamp(map['rejectedAt']),
      rejectReason: map['rejectReason'],
    );
  }

  /// Helper: chuyển Timestamp hoặc String sang DateTime
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Tạo bản sao với một số trường thay đổi.
  MentorModel copyWith({
    String? userId,
    List<String>? games,
    String? bio,
    String? achievements,
    double? rating,
    int? totalReviews,
    int? followerCount,
    int? totalStreams,
    int? totalGiftsReceived,
    String? status,
    DateTime? appliedAt,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? rejectReason,
  }) {
    return MentorModel(
      userId: userId ?? this.userId,
      games: games ?? this.games,
      bio: bio ?? this.bio,
      achievements: achievements ?? this.achievements,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      followerCount: followerCount ?? this.followerCount,
      totalStreams: totalStreams ?? this.totalStreams,
      totalGiftsReceived: totalGiftsReceived ?? this.totalGiftsReceived,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }
}

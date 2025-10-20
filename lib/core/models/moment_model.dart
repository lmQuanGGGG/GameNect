import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class MomentModel {
  final String id;
  final String userId;
  final String mediaUrl;
  final String? thumbnailUrl; 
  final bool isVideo;
  final DateTime createdAt;
  final List<String> matchIds;
  final List<Map<String, dynamic>> reactions;
  final List<Map<String, dynamic>> replies;
  final String? caption;

  MomentModel({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.isVideo,
    required this.createdAt,
    required this.matchIds,
    required this.reactions,
    required this.replies,
    this.caption,
  });

  // Chuyển DateTime thành base64 khi lưu
  static String dateTimeToBase64(DateTime dt) {
    final iso = dt.toIso8601String();
    return base64Encode(utf8.encode(iso));
  }

  // Chuyển base64 thành DateTime khi đọc
  static DateTime base64ToDateTime(String base64Str) {
    final iso = utf8.decode(base64Decode(base64Str));
    return DateTime.parse(iso);
  }

  factory MomentModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime createdAt;
    
    // Xử lý createdAt có thể là Timestamp hoặc String hoặc null
    if (map['createdAt'] == null) {
      createdAt = DateTime.now();
    } else if (map['createdAt'] is Timestamp) {
      createdAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      createdAt = base64ToDateTime(map['createdAt']);
    } else {
      createdAt = DateTime.now();
    }
    
    return MomentModel(
      id: id,
      userId: map['userId'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'], // Có thể null
      isVideo: map['isVideo'] ?? false,
      createdAt: createdAt,
      matchIds: List<String>.from(map['matchIds'] ?? []),
      reactions: List<Map<String, dynamic>>.from(map['reactions'] ?? []),
      replies: List<Map<String, dynamic>>.from(map['replies'] ?? []),
      caption: map['caption'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'isVideo': isVideo,
      'createdAt': Timestamp.fromDate(createdAt),
      'matchIds': matchIds,
      'reactions': reactions,
      'replies': replies,
      'caption': caption,
    };
  }
}
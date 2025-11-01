import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

// Lớp MomentModel lưu thông tin một khoảnh khắc (moment) mà user đăng lên hệ thống.
// Một moment có thể là ảnh hoặc video, kèm caption, danh sách match liên quan, danh sách reactions và replies.

class MomentModel {
  final String id;                           // Id của moment (document id trong Firestore)
  final String userId;                       // Id của user đã đăng moment
  final String mediaUrl;                     // Đường dẫn file media (ảnh hoặc video)
  final String? thumbnailUrl;                // Đường dẫn thumbnail (nếu là video)
  final bool isVideo;                        // Moment này là video hay không
  final DateTime createdAt;                  // Thời điểm tạo moment
  final List<String> matchIds;               // Danh sách id các match liên quan đến moment này
  final List<Map<String, dynamic>> reactions;// Danh sách các cảm xúc (reaction) của user khác
  final List<Map<String, dynamic>> replies;  // Danh sách các bình luận (reply) của user khác
  final String? caption;                     // Nội dung caption của moment

  // Hàm khởi tạo đối tượng MomentModel với các tham số truyền vào.
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

  // Hàm chuyển DateTime thành chuỗi base64 để lưu trữ (dùng khi cần encode thời gian).
  static String dateTimeToBase64(DateTime dt) {
    final iso = dt.toIso8601String();
    return base64Encode(utf8.encode(iso));
  }

  // Hàm chuyển chuỗi base64 thành DateTime (dùng khi cần decode thời gian).
  static DateTime base64ToDateTime(String base64Str) {
    final iso = utf8.decode(base64Decode(base64Str));
    return DateTime.parse(iso);
  }

  // Hàm tạo đối tượng MomentModel từ Map lấy từ Firestore.
  // Xử lý trường createdAt có thể là Timestamp, String hoặc null.
  factory MomentModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime createdAt;
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
      thumbnailUrl: map['thumbnailUrl'], // Có thể null nếu là ảnh
      isVideo: map['isVideo'] ?? false,
      createdAt: createdAt,
      matchIds: List<String>.from(map['matchIds'] ?? []),
      reactions: List<Map<String, dynamic>>.from(map['reactions'] ?? []),
      replies: List<Map<String, dynamic>>.from(map['replies'] ?? []),
      caption: map['caption'],
    );
  }

  // Hàm chuyển đối tượng MomentModel thành Map để lưu vào Firestore.
  // Trường createdAt được chuyển thành Timestamp để Firestore lưu đúng kiểu thời gian.
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
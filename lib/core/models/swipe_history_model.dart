import 'package:cloud_firestore/cloud_firestore.dart';

// Lớp SwipeHistory lưu lại lịch sử thao tác swipe (vuốt) của người dùng trên hệ thống.
// Mỗi lần vuốt sẽ lưu lại ai là người thực hiện, ai là đối tượng bị vuốt, hành động là like hay dislike, và thời điểm thực hiện.

class SwipeHistory {
  final String id;              
  final String userId;          
  final String targetUserId;     
  final String action;          
  final DateTime timestamp;      

  // Hàm khởi tạo đối tượng SwipeHistory với các tham số truyền vào.
  SwipeHistory({
    required this.id,
    required this.userId,
    required this.targetUserId,
    required this.action,
    required this.timestamp,
  });

  // Hàm chuyển đối tượng SwipeHistory thành Map để lưu vào Firestore.
  // Trường timestamp được chuyển thành chuỗi ISO8601 để lưu trữ.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'targetUserId': targetUserId,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Hàm tạo đối tượng SwipeHistory từ Map lấy từ Firestore.
  // Xử lý trường timestamp có thể là Timestamp hoặc String.
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
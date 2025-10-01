import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  String id;
  List<String> userIds; // ID của các game thủ
  String game;
  DateTime matchedAt;
  bool isActive;
  Map<String, bool> confirmations; // Trạng thái xác nhận của từng user

  MatchModel({
    required this.id,
    required this.userIds,
    required this.game,
    required this.matchedAt,
    this.isActive = true,
    this.confirmations = const {}, // Mặc định chưa có xác nhận
  });

  Map<String, dynamic> toMap() {
    return {
      'userIds': userIds,
      'game': game,
      'matchedAt': matchedAt,
      'isActive': isActive,
      'confirmations': confirmations,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map, String id) {
    return MatchModel(
      id: id,
      userIds: List<String>.from(map['userIds'] ?? []),
      game: map['game'] ?? '',
      matchedAt: (map['matchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      confirmations: Map<String, bool>.from(map['confirmations'] ?? {}),
    );
  }
}

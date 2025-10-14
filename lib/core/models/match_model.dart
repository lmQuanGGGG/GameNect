import 'package:cloud_firestore/cloud_firestore.dart';

class MatchStatus {
  static const String pending = 'pending';          // Vừa ghép, chờ xác nhận
  static const String partial = 'partial';          // Một bên xác nhận
  static const String confirmed = 'confirmed';      // Tất cả đã xác nhận
  static const String cancelled = 'cancelled';      // Bị hủy
  static const String expired = 'expired';          // Quá hạn chưa xác nhận đủ
}

class MatchModel {
  String id;
  List<String> userIds;
  String game;
  DateTime matchedAt;
  bool isActive;
  Map<String, bool> confirmations;

  // --- Trạng thái mới ---
  String status;                // pending / partial / confirmed / cancelled / expired
  String? cancelReason;         // Lý do hủy (nếu có)
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? confirmedAt;        // Khi đạt confirmed
  DateTime? cancelledAt;        // Khi bị hủy
  DateTime? expiresAt;          // Hạn xác nhận (optional)

  MatchModel({
    required this.id,
    required this.userIds,
    required this.game,
    required this.matchedAt,
    this.isActive = true,
    this.confirmations = const {},
    this.status = MatchStatus.pending,
    this.cancelReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.confirmedAt,
    this.cancelledAt,
    this.expiresAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Cập nhật status dựa trên confirmations
  void computeStatus() {
    if (status == MatchStatus.cancelled) return;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!) && status != MatchStatus.confirmed) {
      status = MatchStatus.expired;
      isActive = false;
      return;
    }
    if (confirmations.isEmpty) {
      status = MatchStatus.pending;
      return;
    }
    final total = userIds.length;
    final confirmedCount = confirmations.values.where((v) => v == true).length;
    if (confirmedCount == 0) {
      status = MatchStatus.pending;
    } else if (confirmedCount < total) {
      status = MatchStatus.partial;
    } else {
      status = MatchStatus.confirmed;
      confirmedAt = confirmedAt ?? DateTime.now();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userIds': userIds,
      'game': game,
      'matchedAt': matchedAt.toIso8601String(),
      'isActive': isActive,
      'confirmations': confirmations,
      'status': status,
      'cancelReason': cancelReason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'confirmedAt': confirmedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  static DateTime _parseTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  static DateTime? _parseNullable(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  factory MatchModel.fromMap(Map<String, dynamic> map, String id) {
    return MatchModel(
      id: id,
      userIds: List<String>.from(map['userIds'] ?? []),
      game: map['game'] ?? '',
      matchedAt: _parseTime(map['matchedAt']),
      isActive: map['isActive'] ?? true,
      confirmations: Map<String, bool>.from(map['confirmations'] ?? {}),
      status: map['status'] ?? MatchStatus.pending,
      cancelReason: map['cancelReason'],
      createdAt: _parseTime(map['createdAt']),
      updatedAt: _parseTime(map['updatedAt']),
      confirmedAt: _parseNullable(map['confirmedAt']),
      cancelledAt: _parseNullable(map['cancelledAt']),
      expiresAt: _parseNullable(map['expiresAt']),
    );
  }

  MatchModel copyWith({
    List<String>? userIds,
    String? game,
    DateTime? matchedAt,
    bool? isActive,
    Map<String, bool>? confirmations,
    String? status,
    String? cancelReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? confirmedAt,
    DateTime? cancelledAt,
    DateTime? expiresAt,
  }) {
    return MatchModel(
      id: id,
      userIds: userIds ?? this.userIds,
      game: game ?? this.game,
      matchedAt: matchedAt ?? this.matchedAt,
      isActive: isActive ?? this.isActive,
      confirmations: confirmations ?? this.confirmations,
      status: status ?? this.status,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

// Lớp MatchStatus định nghĩa các trạng thái của một lần ghép đôi (match).
// Các trạng thái gồm: pending (chờ xác nhận), partial (một bên xác nhận), confirmed (tất cả xác nhận), cancelled (bị hủy), expired (quá hạn chưa xác nhận đủ).
class MatchStatus {
  static const String pending = 'pending';         
  static const String partial = 'partial';         
  static const String confirmed = 'confirmed';     
  static const String cancelled = 'cancelled';      
  static const String expired = 'expired';         
}

// Lớp MatchModel lưu thông tin một lần ghép đôi giữa các user.
// Bao gồm danh sách user, tên game, thời điểm ghép, trạng thái xác nhận, trạng thái hoạt động, các mốc thời gian liên quan.
class MatchModel {
  String id;                           
  List<String> userIds;                
  String game;                         
  DateTime matchedAt;                  
  bool isActive;                       
  Map<String, bool> confirmations;     

  // Các trường trạng thái mới
  String status;                       
  String? cancelReason;               
  DateTime createdAt;                  
  DateTime updatedAt;                  
  DateTime? confirmedAt;               
  DateTime? cancelledAt;               
  DateTime? expiresAt;                 

  // Hàm khởi tạo đối tượng MatchModel với các tham số truyền vào.
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

  // Hàm tính toán lại trạng thái của lần ghép dựa trên xác nhận của các user.
  // Nếu bị hủy thì giữ nguyên trạng thái cancelled.
  // Nếu quá hạn xác nhận mà chưa đủ xác nhận thì chuyển sang expired và tắt hoạt động.
  // Nếu chưa ai xác nhận thì trạng thái là pending.
  // Nếu một phần xác nhận thì trạng thái là partial.
  // Nếu tất cả xác nhận thì trạng thái là confirmed và lưu thời điểm xác nhận.
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

  // Chuyển đối tượng MatchModel thành Map để lưu vào Firestore.
  // Các trường thời gian được chuyển sang dạng chuỗi ISO8601.
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

  // Hàm hỗ trợ chuyển đổi dữ liệu thời gian từ Firestore về kiểu DateTime.
  // Nếu là Timestamp thì chuyển sang DateTime, nếu là chuỗi thì parse, nếu null thì trả về thời điểm hiện tại.
  static DateTime _parseTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  // Hàm hỗ trợ chuyển đổi dữ liệu thời gian nullable từ Firestore về kiểu DateTime?.
  // Nếu là Timestamp thì chuyển sang DateTime, nếu là chuỗi thì parse, nếu null thì trả về null.
  static DateTime? _parseNullable(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  // Hàm tạo đối tượng MatchModel từ Map lấy từ Firestore.
  // Truyền vào map dữ liệu và id document.
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

  // Hàm copyWith cho phép tạo bản sao của MatchModel với một số trường thay đổi.
  // Các trường không truyền vào sẽ giữ nguyên giá trị cũ.
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

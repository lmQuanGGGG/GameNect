import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một phiên Livestream.
/// Lưu trong collection `livestreams/{streamId}`.
class LivestreamModel {
  final String id;
  final String mentorId;
  final String mentorUsername;
  final String mentorAvatarUrl;
  final String title;
  final String game;
  final String agoraChannel; // = id (streamId)
  final String status; // 'live' | 'ended'
  final int viewerCount;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? thumbnailUrl;

  const LivestreamModel({
    required this.id,
    required this.mentorId,
    required this.mentorUsername,
    required this.mentorAvatarUrl,
    required this.title,
    required this.game,
    required this.agoraChannel,
    this.status = 'live',
    this.viewerCount = 0,
    required this.startedAt,
    this.endedAt,
    this.thumbnailUrl,
  });

  bool get isLive => status == 'live';

  /// Chuyển LivestreamModel thành Map để lưu vào Firestore.
  Map<String, dynamic> toMap() {
    return {
      'mentorId': mentorId,
      'mentorUsername': mentorUsername,
      'mentorAvatarUrl': mentorAvatarUrl,
      'title': title,
      'game': game,
      'agoraChannel': agoraChannel,
      'status': status,
      'viewerCount': viewerCount,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  /// Tạo LivestreamModel từ Firestore document.
  factory LivestreamModel.fromMap(Map<String, dynamic> map, String id) {
    return LivestreamModel(
      id: id,
      mentorId: map['mentorId'] ?? '',
      mentorUsername: map['mentorUsername'] ?? '',
      mentorAvatarUrl: map['mentorAvatarUrl'] ?? '',
      title: map['title'] ?? '',
      game: map['game'] ?? '',
      agoraChannel: map['agoraChannel'] ?? id,
      status: map['status'] ?? 'live',
      viewerCount: (map['viewerCount'] ?? 0).toInt(),
      startedAt: _parseTimestamp(map['startedAt']) ?? DateTime.now(),
      endedAt: _parseTimestamp(map['endedAt']),
      thumbnailUrl: map['thumbnailUrl'],
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  LivestreamModel copyWith({
    String? id,
    String? mentorId,
    String? mentorUsername,
    String? mentorAvatarUrl,
    String? title,
    String? game,
    String? agoraChannel,
    String? status,
    int? viewerCount,
    DateTime? startedAt,
    DateTime? endedAt,
    String? thumbnailUrl,
  }) {
    return LivestreamModel(
      id: id ?? this.id,
      mentorId: mentorId ?? this.mentorId,
      mentorUsername: mentorUsername ?? this.mentorUsername,
      mentorAvatarUrl: mentorAvatarUrl ?? this.mentorAvatarUrl,
      title: title ?? this.title,
      game: game ?? this.game,
      agoraChannel: agoraChannel ?? this.agoraChannel,
      status: status ?? this.status,
      viewerCount: viewerCount ?? this.viewerCount,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}

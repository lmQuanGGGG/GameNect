import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../../../core/providers/chat_provider.dart';
import 'video_player_bubble.dart';
import 'voice_message_bubble.dart';

/// Bubble hiển thị tin nhắn (text, image, video, voice, call)
/// Chứa logic rendering, avatar cho bên nhận, và xử lý reactions (double tap/long press)
class MessageBubbleWidget extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String avatarUrl;
  final String timeString;
  final String matchId;

  const MessageBubbleWidget({
    required this.msg,
    required this.isMe,
    required this.avatarUrl,
    required this.timeString,
    required this.matchId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMe) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 2),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              backgroundColor: Colors.deepOrange.withValues(alpha: 0.18),
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 18)
                  : null,
            ),
          ),
          Flexible(child: _buildMessageBubbleContent(context)),
        ],
      );
    } else {
      return _buildMessageBubbleContent(context);
    }
  }

  Widget _buildMessageBubbleContent(BuildContext context) {
    final isCall = msg['type'] == 'call';
    final isVoice = msg['type'] == 'voice';

    // Xử lý cuộc gọi
    if (isCall) {
      final callStatus = msg['callStatus'] ?? '';
      String callText;
      IconData callIcon;
      Color callColor;

      switch (callStatus) {
        case 'missed':
          callText = 'Cuộc gọi nhỡ';
          callIcon = Icons.call_missed_rounded;
          callColor = const Color(0xFFFF453A);
          break;
        case 'declined':
          callText = 'Cuộc gọi bị từ chối';
          callIcon = Icons.phone_disabled_rounded;
          callColor = Colors.orange;
          break;
        case 'cancelled':
          callText = 'Đã hủy';
          callIcon = Icons.phone_missed_rounded;
          callColor = Colors.grey;
          break;
        case 'ended':
          callText = msg['text'] ?? 'Đã gọi';
          callIcon = Icons.call_rounded;
          callColor = Colors.green;
          break;
        default:
          callText = msg['text'] ?? 'Cuộc gọi';
          callIcon = Icons.call_rounded;
          callColor = Colors.white;
      }

      return Align(
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: (callStatus == 'missed' || callStatus == 'declined')
                      ? [
                          callColor.withValues(alpha: 0.3),
                          callColor.withValues(alpha: 0.2),
                        ]
                      : callStatus == 'cancelled'
                          ? [
                              Colors.grey.withValues(alpha: 0.3),
                              Colors.grey.withValues(alpha: 0.2),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.1),
                            ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(callIcon, color: callColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    callText,
                    style: TextStyle(
                        color: callColor, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Xử lý Voice Message
    if (isVoice) {
      final audioUrl = msg['audioUrl'] as String?;
      final duration = msg['duration'] as int? ?? 0;
      final reactions = (msg['reactions'] as List?) ?? [];

      return Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: !isMe ? () => _showReactionPicker(context) : null,
            onDoubleTap: !isMe
                ? () {
                    Provider.of<ChatProvider>(context, listen: false)
                        .reactToMessage(matchId, msg['id'], '❤️');
                  }
                : null,
            child: VoiceMessageBubble(
              audioUrl: audioUrl ?? '',
              duration: duration,
              isMe: isMe,
            ),
          ),
          if (reactions.isNotEmpty) _buildReactionsRow(reactions),
        ],
      );
    }

    // Tin nhắn thường (text, media)
    final mediaUrl = msg['mediaUrl'] as String?;
    final isVideo = msg['isVideo'] == true;
    final text = msg['text'] ?? '';
    final reactions = (msg['reactions'] as List?) ?? [];

    return GestureDetector(
      onLongPress: !isMe ? () => _showReactionPicker(context) : null,
      onDoubleTap: !isMe
          ? () {
              Provider.of<ChatProvider>(context, listen: false)
                  .reactToMessage(matchId, msg['id'], '❤️');
            }
          : null,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (mediaUrl != null && mediaUrl.isNotEmpty)
            Container(
              margin: EdgeInsets.only(
                bottom: 6,
                left: isMe ? 40 : 0,
                right: isMe ? 8 : 40,
              ),
              constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: isVideo
                    ? VideoPlayerBubble(videoUrl: mediaUrl)
                    : CachedNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFFFF453A)),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.error, color: Color(0xFFFF453A)),
                        ),
                      ),
              ),
            ),
          if (text.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  margin: EdgeInsets.only(
                    left: isMe ? 40 : 0,
                    right: isMe ? 8 : 40,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? LinearGradient(
                            colors: [
                              const Color(0xFFFF453A).withValues(alpha: 0.8),
                              const Color(0xFFFF6961).withValues(alpha: 0.8),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.15),
                            ],
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                    boxShadow: isMe
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF453A).withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          if (reactions.isNotEmpty) _buildReactionsRow(reactions),
        ],
      ),
    );
  }

  /// Trả về dãy reactions icons nhỏ bé phía dưới bubble
  Widget _buildReactionsRow(List reactions) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 40 : 0,
        right: isMe ? 8 : 40,
        top: 4,
      ),
      child: Wrap(
        spacing: 4,
        children: reactions.map<Widget>((r) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            child: Text(r['emoji'] ?? '', style: const TextStyle(fontSize: 16)),
          );
        }).toList(),
      ),
    );
  }

  /// Bottom sheet chọn emoji nhanh
  Future<void> _showReactionPicker(BuildContext context) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SizedBox(
        height: 80,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['👍', '❤️', '😂', '😮', '😢', '😡'].map((e) {
            return GestureDetector(
              onTap: () => Navigator.pop(context, e),
              child: Text(e, style: const TextStyle(fontSize: 28)),
            );
          }).toList(),
        ),
      ),
    );
    if (emoji != null && context.mounted) {
      Provider.of<ChatProvider>(context, listen: false)
          .reactToMessage(matchId, msg['id'], emoji);
    }
  }
}

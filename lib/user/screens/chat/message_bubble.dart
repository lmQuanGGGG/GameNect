import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../../../core/providers/chat_provider.dart';
import '../games/game_detail_screen.dart';
import 'video_player_bubble.dart';
import 'voice_message_bubble.dart';
import 'full_screen_media_viewer.dart';
import '../../../core/theme/theme_helper.dart';

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
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
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
    final isGame = msg['type'] == 'game';

    if (isGame) {
      return _buildGameMessageBubble(context);
    }

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
          callColor = const Color(0xFFFF6E40);
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
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(callIcon, color: callColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    callText,
                    style: TextStyle(
                      color: callColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
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
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: !isMe ? () => _showReactionPicker(context) : null,
            onDoubleTap: !isMe
                ? () {
                    Provider.of<ChatProvider>(
                      context,
                      listen: false,
                    ).reactToMessage(matchId, msg['id'], '❤️');
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
              Provider.of<ChatProvider>(
                context,
                listen: false,
              ).reactToMessage(matchId, msg['id'], '❤️');
            }
          : null,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (mediaUrl != null && mediaUrl.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenMediaViewer(
                      mediaUrl: mediaUrl,
                      isVideo: isVideo,
                    ),
                  ),
                );
              },
              child: Container(
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
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF6E40),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.error,
                            color: Color(0xFFFF6E40),
                          ),
                        ),
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFFF6E40),
                              Color(0xFFFF8A65),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              context.isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
                              context.isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
                            ],
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    border: Border.all(
                      color: isMe ? Colors.transparent : context.cardBorderColor,
                      width: 1,
                    ),
                    boxShadow: isMe
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFFF6E40,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : context.textColor,
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
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  r['emoji'] ?? '',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Bottom sheet chọn emoji nhanh
  Future<void> _showReactionPicker(BuildContext context) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
        decoration: BoxDecoration(
          color: context.dialogBgColor.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: context.cardBorderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6E40).withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '😡'].map((e) {
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, e),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: Text(e, style: const TextStyle(fontSize: 32)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
    if (emoji != null && context.mounted) {
      Provider.of<ChatProvider>(
        context,
        listen: false,
      ).reactToMessage(matchId, msg['id'], emoji);
    }
  }

  Widget _buildGameMessageBubble(BuildContext context) {
    final gameName = msg['gameName'] ?? 'Game';
    final gameImage = msg['gameImage'] ?? '';
    final gameRating = (msg['gameRating'] ?? 0.0).toDouble();
    final gameId = msg['gameId'];
    final reactions = (msg['reactions'] as List?) ?? [];

    return GestureDetector(
      onTap: () {
        if (gameId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GameDetailScreen(gameId: gameId)),
          );
        }
      },
      onLongPress: !isMe ? () => _showReactionPicker(context) : null,
      onDoubleTap: !isMe
          ? () {
              Provider.of<ChatProvider>(
                context,
                listen: false,
              ).reactToMessage(matchId, msg['id'], '❤️');
            }
          : null,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              bottom: 6,
              left: isMe ? 40 : 0,
              right: isMe ? 8 : 40,
            ),
            width: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.cardBorderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6E40).withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Game Image
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: gameImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: gameImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: context.cardBgColor),
                            errorWidget: (context, url, error) => Container(color: context.cardBgColor),
                          )
                        : Container(color: context.cardBgColor),
                  ),
                  
                  // Gradient Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Content
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                gameRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          gameName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Share Icon Badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.videogame_asset_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (reactions.isNotEmpty) _buildReactionsRow(reactions),
        ],
      ),
    );
  }
}

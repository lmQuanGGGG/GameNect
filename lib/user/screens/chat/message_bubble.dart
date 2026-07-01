import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/network_image.dart';
import 'dart:ui';
import '../../../core/providers/chat_provider.dart';
import '../games/game_detail_screen.dart';
import 'video_player_bubble.dart';
import 'voice_message_bubble.dart';
import 'full_screen_media_viewer.dart';
import '../../../core/theme/theme_helper.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'forward_message_dialog.dart';

/// Bubble hiển thị tin nhắn (text, image, video, voice, call)
/// Chứa logic rendering, avatar cho bên nhận, và xử lý reactions (double tap/long press)
class MessageBubbleWidget extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String avatarUrl;
  final String timeString;
  final String matchId;
  final VoidCallback? onReply;

  const MessageBubbleWidget({
    required this.msg,
    required this.isMe,
    required this.avatarUrl,
    required this.timeString,
    required this.matchId,
    this.onReply,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 800;
    Widget content;
    
    if (!isMe) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 2),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.18),
              ),
              child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? GamenectNetworkImage(
                        imageUrl: avatarUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ),
          Flexible(child: _buildMessageBubbleContent(context)),
          if (isLargeScreen && onReply != null)
            IconButton(
              icon: const Icon(Icons.reply, size: 20, color: Colors.black54),
              onPressed: onReply,
              tooltip: 'Trả lời',
            ),
        ],
      );
    } else {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLargeScreen && onReply != null)
            IconButton(
              icon: const Icon(Icons.reply, size: 20, color: Colors.black54),
              onPressed: onReply,
              tooltip: 'Trả lời',
            ),
          Flexible(child: _buildMessageBubbleContent(context)),
        ],
      );
    }

    return Dismissible(
      key: ValueKey('dismiss_${msg['id']}'),
      direction: isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        if (onReply != null) {
          onReply!();
        }
        return false;
      },
      background: Container(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.reply, color: Colors.black54),
      ),
      child: content,
    );
  }

  DateTime? _getDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) return DateTime.tryParse(timestamp);
    // Assumes it has a toDate() method (like Firestore Timestamp)
    try {
      return (timestamp as dynamic).toDate();
    } catch (_) {
      return null;
    }
  }

  String? _extractUrl(String text) {
    final urlRegExp = RegExp(
      r'(?:(?:https?):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+',
      caseSensitive: false,
    );
    final match = urlRegExp.firstMatch(text);
    if (match != null) {
      String url = text.substring(match.start, match.end);
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      return url;
    }
    return null;
  }

  Widget _buildMessageBubbleContent(BuildContext context) {
    final isRecalled = msg['isRecalled'] == true;

    if (isRecalled) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            bottom: 12,
            left: isMe ? 40 : 8,
            right: isMe ? 8 : 40,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.isDarkMode ? Colors.grey[850] : Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
              width: 1,
            ),
          ),
          child: Text(
            'Tin nhắn đã bị thu hồi',
            style: TextStyle(
              color: context.textSecondaryColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final isCall = msg['type'] == 'call';
    final isVoice = msg['type'] == 'voice';
    final isGame = msg['type'] == 'game';
    final isMentorPost = msg['type'] == 'mentor_post';

    if (isGame) {
      return _buildGameMessageBubble(context);
    }
    if (isMentorPost) {
      return _buildMentorPostMessageBubble(context);
    }

    final repliedToText = msg['repliedToText'];
    final repliedToSender = msg['repliedToSender'];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    Widget buildQuotedMessage() {
      if (repliedToText == null) return const SizedBox.shrink();
      final isReplyMe = repliedToSender == currentUserId;
      return Container(
        margin: EdgeInsets.only(
          bottom: 4,
          left: isMe ? 40 : 0,
          right: isMe ? 8 : 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.black.withValues(alpha: 0.6) : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: isMe ? Colors.white : Colors.black, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isReplyMe ? 'Bạn' : 'Đối phương',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isMe ? Colors.white70 : Colors.black87,
              ),
            ),
            Text(
              repliedToText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildForwardedLabel() {
      if (msg['isForwarded'] != true) return const SizedBox.shrink();
      return Container(
        margin: EdgeInsets.only(
          bottom: 4,
          left: isMe ? 40 : 0,
          right: isMe ? 8 : 40,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply, size: 14, color: Colors.grey[600], textDirection: TextDirection.rtl),
            const SizedBox(width: 4),
            Text(
              'Đã chuyển tiếp',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Xử lý long press chung
    void handleLongPress() {
      _showOptionsDialog(context);
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
          callColor = Colors.black;
          break;
        case 'declined':
          callText = 'Cuộc gọi bị từ chối';
          callIcon = Icons.phone_disabled_rounded;
          callColor = Colors.black;
          break;
        case 'cancelled':
          callText = 'Đã hủy';
          callIcon = Icons.phone_missed_rounded;
          callColor = Colors.grey;
          break;
        case 'ended':
          callText = msg['text'] ?? 'Đã gọi';
          callIcon = Icons.call_rounded;
          callColor = Colors.black;
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
          buildForwardedLabel(),
          buildQuotedMessage(),
          GestureDetector(
            onLongPress: handleLongPress,
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
      onLongPress: handleLongPress,
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
          buildForwardedLabel(),
          buildQuotedMessage(),
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
                    : GamenectNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.black,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.error,
                            color: Colors.black,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (text.isNotEmpty)
            Container(
                  margin: EdgeInsets.only(
                    left: isMe ? 40 : 0,
                    right: isMe ? 8 : 40,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    border: Border.all(
                      color: Colors.black,
                      width: 3,
                    ),
                    boxShadow: [
                      const BoxShadow(
                        color: Colors.black,
                        offset: Offset(4, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Linkify(
                        text: text,
                        onOpen: (link) async {
                          final Uri uri = Uri.parse(link.url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        linkStyle: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      if (_extractUrl(text) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: IgnorePointer(
                            ignoring: true, // Allow outer GestureDetector to catch long presses
                            child: Container(
                              decoration: BoxDecoration(
                                color: isMe ? Colors.grey[900]! : Colors.grey[200]!,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isMe ? Colors.white : Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AnyLinkPreview(
                                  link: _extractUrl(text)!,
                                  displayDirection: UIDirection.uiDirectionVertical,
                                  showMultimedia: true,
                                  bodyMaxLines: 2,
                                  bodyTextOverflow: TextOverflow.ellipsis,
                                  titleStyle: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  bodyStyle: TextStyle(
                                    color: isMe ? Colors.white70 : Colors.black54,
                                    fontSize: 12,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  borderRadius: 0,
                                  removeElevation: true,
                                  errorWidget: const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
      onLongPress: () {
        _showOptionsDialog(context);
      },
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
              border: Border.all(color: Colors.black, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
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
                        ? GamenectNetworkImage(
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

  Widget _buildMentorPostMessageBubble(BuildContext context) {
    final mentorName = msg['mentorName'] ?? 'Mentor';
    final previewUrl = msg['previewUrl'] ?? '';
    final isVideo = msg['isVideo'] == true;
    final postId = msg['postId'];
    final reactions = (msg['reactions'] as List?) ?? [];

    return GestureDetector(
      onTap: () {
        if (postId != null) {
          if (previewUrl.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenMediaViewer(
                  mediaUrl: previewUrl,
                  isVideo: isVideo,
                ),
              ),
            );
          }
        }
      },
      onLongPress: () {
        _showOptionsDialog(context);
      },
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
              border: Border.all(color: Colors.black, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Post Preview Image
                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: previewUrl.isNotEmpty
                        ? GamenectNetworkImage(
                            imageUrl: previewUrl,
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
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_mosaic_rounded, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              const Text(
                                'MENTOR POST',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          mentorName.toUpperCase(),
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
                  
                  if (isVideo)
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
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
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

  void _showOptionsDialog(BuildContext context) {
    final text = msg['text'] as String?;
    final hasText = text != null && text.isNotEmpty && msg['type'] == 'text';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.isDarkMode ? const Color(0xFF2C2A29) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '😡'].map((e) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Provider.of<ChatProvider>(context, listen: false).reactToMessage(matchId, msg['id'], e);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Divider(color: context.textColor.withValues(alpha: 0.1)),
              const SizedBox(height: 8),
            ],
            Text(
              'Tùy chọn tin nhắn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 20),
            if (hasText)
              ListTile(
                leading: Icon(Icons.copy, color: context.textColor),
                title: Text('Sao chép tin nhắn', style: TextStyle(color: context.textColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép vào bộ nhớ tạm')),
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.reply, color: context.textColor, textDirection: TextDirection.rtl),
              title: Text('Chuyển tiếp tin nhắn', style: TextStyle(color: context.textColor)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => ForwardMessageDialog(originalMsg: msg),
                );
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Thu hồi tin nhắn', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  final msgTime = _getDateTime(msg['timestamp']);
                  if (msgTime != null && DateTime.now().difference(msgTime).inHours < 24) {
                    Provider.of<ChatProvider>(context, listen: false).recallMessage(matchId, msg['id']);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chỉ có thể thu hồi tin nhắn trong vòng 24 giờ')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

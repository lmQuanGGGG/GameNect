import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../../../core/providers/moment_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../camera/camera_capture_screen.dart';
import 'video_player_widget.dart';

/// Widget hiển thị chi tiết một moment với video/ảnh fullscreen,
/// thông tin user, reactions và action buttons (react, camera reply, send message).
class MomentCard extends StatelessWidget {
  final dynamic moment;
  final String currentUserId;

  const MomentCard({
    super.key,
    required this.moment,
    required this.currentUserId,
  });

  static final Map<String, Map<String, dynamic>> _userCache = {};

  Future<Map<String, dynamic>?> _getUserInfo(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists) {
      _userCache[userId] = doc.data() as Map<String, dynamic>;
      return _userCache[userId];
    }
    return null;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  void _quickReact(BuildContext context, String momentId, String userId) {
    Provider.of<MomentProvider>(context, listen: false)
        .reactToMoment(momentId, userId, '❤️');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️', textAlign: TextAlign.center, style: TextStyle(fontSize: 24)),
        duration: Duration(milliseconds: 800),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showReactionPicker(BuildContext context, String momentId, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF101012).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6E40).withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Chọn cảm xúc',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16, runSpacing: 16,
                alignment: WrapAlignment.center,
                children: ['❤️', '😍', '😂', '😮', '😢', '👏', '🔥', '🎉'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Provider.of<MomentProvider>(context, listen: false)
                          .reactToMoment(momentId, userId, emoji);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 68, height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showReplyDialog(BuildContext context, String momentId, String userId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          contentPadding: EdgeInsets.zero,
          content: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF101012).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6E40).withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nhắn tin cho người đăng',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Theme(
                        data: ThemeData.dark().copyWith(
                          textSelectionTheme: const TextSelectionThemeData(
                            cursorColor: Color(0xFFFF6E40),
                            selectionColor: Color(0x55FF6E40),
                            selectionHandleColor: Color(0xFFFF6E40),
                          ),
                        ),
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          cursorColor: const Color(0xFFFF6E40),
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Nhập nội dung...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Hủy',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final text = controller.text.trim();
                            if (text.isNotEmpty) {
                              final momentOwnerId = moment.userId;
                              if (userId != momentOwnerId) {
                                final matchId = await FirestoreService()
                                    .getOrCreateMatchId(userId, momentOwnerId);
                                final peerUserDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(momentOwnerId)
                                    .get();
                                final peerUser = UserModel.fromMap(peerUserDoc.data()!, momentOwnerId);
                                await Provider.of<ChatProvider>(context, listen: false)
                                    .sendMessageWithMedia(matchId, text,
                                        mediaUrl: moment.mediaUrl, isVideo: moment.isVideo);
                                Navigator.pop(ctx);
                                Navigator.pushNamed(context, '/chat',
                                    arguments: {'matchId': matchId, 'peerUser': peerUser});
                              } else {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Không thể nhắn cho chính mình!'),
                                    backgroundColor: Colors.deepOrange,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: const Color(0xFFFF6E40).withValues(alpha: 0.5)),
                            ),
                            elevation: 0,
                          ).copyWith(
                            backgroundColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFFF6E40).withValues(alpha: 0.8)),
                          ),
                          child: const Text('Gửi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showReactionUsers(BuildContext context, List reactions) {
    // Group reactions by userId
    final Map<String, List<String>> byUser = {};
    for (final r in reactions) {
      final uid = r['userId'] as String? ?? '';
      byUser.putIfAbsent(uid, () => []).add(r['emoji'] as String? ?? '❤️');
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Cảm xúc',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              const Divider(color: Colors.white24, height: 1),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  children: byUser.entries.map<Widget>((entry) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(entry.key).get(),
                      builder: (context, snapshot) {
                        final user = snapshot.data?.data() as Map<String, dynamic>?;
                        final avatarUrl = user?['avatarUrl'];
                        final username = user?['username'] ?? entry.key;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null
                                    ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(username,
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                              ),
                              // All emojis from this user
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: entry.value.map((e) =>
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(e, style: const TextStyle(fontSize: 22)),
                                    )
                                ).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReplyWithMediaDialog(BuildContext context, String momentId, String userId, Map mediaResult) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tính năng reply bằng ảnh/video đang phát triển'),
        backgroundColor: Colors.deepOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserInfo(moment.userId),
      builder: (context, snapshot) {
        final userInfo = snapshot.data;
        final username = userInfo?['username'] ??
            (moment.userId == currentUserId ? 'Bạn' : 'Người bạn');
        final avatarUrl = userInfo?['avatarUrl'];

        return GestureDetector(
          onDoubleTap: () => _quickReact(context, moment.id, currentUserId),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media (ảnh hoặc video)
              moment.isVideo
                  ? VideoPlayerWidget(videoUrl: moment.mediaUrl)
                  : Container(
                      color: Colors.black,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: moment.mediaUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
                          errorWidget: (context, url, error) =>
                              const Center(child: Icon(Icons.error_outline, color: Colors.white, size: 50)),
                        ),
                      ),
                    ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
              ),

              // User info + caption
              Positioned(
                left: 20, right: 80,
                bottom: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + username + time
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2.5),
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null
                                ? Text(username.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18))
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(username,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 17,
                                      fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                              const SizedBox(height: 2),
                              Text(_formatTime(moment.createdAt),
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 13, fontWeight: FontWeight.w400)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Caption
                    if (moment.caption?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      Text(moment.caption!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w400, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ],

                    // Reactions grouped by user (like TikTok)
                    if (moment.reactions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => _showReactionUsers(context, moment.reactions),
                        child: Builder(builder: (context) {
                          // Group by user
                          final Map<String, List<String>> byUser = {};
                          for (final r in moment.reactions) {
                            final uid = r['userId'] as String? ?? '';
                            byUser.putIfAbsent(uid, () => []).add(r['emoji'] as String? ?? '❤️');
                          }
                          return Wrap(
                            spacing: 8, runSpacing: 8,
                            children: byUser.entries.take(4).map<Widget>((entry) {
                              return FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('users').doc(entry.key).get(),
                                builder: (context, snapshot) {
                                  final user = snapshot.data?.data() as Map<String, dynamic>?;
                                  final av = user?['avatarUrl'];
                                  final uname = user?['username'] ?? '';
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 11,
                                              backgroundColor: Colors.grey[700],
                                              backgroundImage: av != null ? NetworkImage(av) : null,
                                              child: av == null
                                                  ? Text(uname.isNotEmpty ? uname[0].toUpperCase() : '?',
                                                      style: const TextStyle(color: Colors.white, fontSize: 9,
                                                          fontWeight: FontWeight.w700))
                                                  : null,
                                            ),
                                            const SizedBox(width: 5),
                                            // All emojis inline
                                            ...entry.value.take(3).map((e) =>
                                              Text(e, style: const TextStyle(fontSize: 14))
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),

              // TikTok-style vertical emoji bar on the RIGHT (only for others' moments)
              if (moment.userId != currentUserId)
                Positioned(
                  right: 12,
                  bottom: 130,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...['❤️', '😂', '🔥', '😍'].map((emoji) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () {
                          Provider.of<MomentProvider>(context, listen: false)
                              .reactToMoment(moment.id, currentUserId, emoji);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(emoji,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 28)),
                              duration: const Duration(milliseconds: 600),
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
                              ),
                              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                            ),
                          ),
                        ),
                      ),
                    )),
                    // + button
                    GestureDetector(
                      onTap: () => _showReactionPicker(context, moment.id, currentUserId),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons bar (camera + send only)
              Positioned(
                left: 20, right: 20, bottom: 40,
                child: Row(
                  children: [

                    const SizedBox(width: 12),

                    // Camera button
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CameraCaptureScreen()),
                        );
                        if (result != null && result is Map) {
                          _showReplyWithMediaDialog(context, moment.id, currentUserId, result);
                        }
                      },
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.deepOrange, Colors.orange.shade600],
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.deepOrange.withValues(alpha: 0.5),
                                blurRadius: 20, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Send message button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showReplyDialog(context, moment.id, currentUserId),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 15, offset: const Offset(0, 5)),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text('Gửi',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 15,
                                            fontWeight: FontWeight.w600, letterSpacing: 0.3),
                                        maxLines: 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

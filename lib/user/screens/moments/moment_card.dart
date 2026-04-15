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

  Future<Map<String, dynamic>?> _getUserInfo(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.exists ? doc.data() : null;
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
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(24),
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
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
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
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                      ),
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Nhập nội dung...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
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
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
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
                  children: reactions.map<Widget>((reaction) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(reaction['userId'])
                          .get(),
                      builder: (context, snapshot) {
                        final user = snapshot.data?.data() as Map<String, dynamic>?;
                        final avatarUrl = user?['avatarUrl'];
                        final username = user?['username'] ?? reaction['userId'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null
                                    ? Text(
                                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                      )
                                    : null,
                              ),
                            ),
                            title: Text(username,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(reaction['emoji'] ?? '❤️',
                                  style: const TextStyle(fontSize: 24)),
                            ),
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

              // User info + caption + reactions
              Positioned(
                left: 20, right: 20,
                bottom: moment.reactions.isNotEmpty ? 140 : 120,
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

                    // Reactions chips
                    if (moment.reactions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: moment.reactions.take(5).map<Widget>((reaction) {
                          return GestureDetector(
                            onTap: () => _showReactionUsers(context, moment.reactions),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(reaction['userId'])
                                            .get(),
                                        builder: (context, snapshot) {
                                          final user = snapshot.data?.data() as Map<String, dynamic>?;
                                          final avatarUrl = user?['avatarUrl'];
                                          final uname = user?['username'] ?? '';
                                          return CircleAvatar(
                                            radius: 10,
                                            backgroundColor: Colors.grey[700],
                                            backgroundImage: avatarUrl != null
                                                ? NetworkImage(avatarUrl)
                                                : null,
                                            child: avatarUrl == null
                                                ? Text(
                                                    uname.isNotEmpty ? uname[0].toUpperCase() : '?',
                                                    style: const TextStyle(
                                                        color: Colors.white, fontSize: 10,
                                                        fontWeight: FontWeight.w600))
                                                : null,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 5),
                                      Text(reaction['emoji'] ?? '❤️',
                                          style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons bar
              Positioned(
                left: 20, right: 20, bottom: 40,
                child: Row(
                  children: [
                    // Reactions + emoji picker
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...['❤️', '😂'].map((emoji) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () {
                                        Provider.of<MomentProvider>(context, listen: false)
                                            .reactToMoment(moment.id, currentUserId, emoji);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(emoji,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontSize: 24)),
                                            duration: const Duration(milliseconds: 600),
                                            backgroundColor: Colors.transparent,
                                            elevation: 0,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 40, height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                            child: Text(emoji,
                                                style: const TextStyle(fontSize: 20))),
                                      ),
                                    ),
                                  )),
                                  GestureDetector(
                                    onTap: () => _showReactionPicker(context, moment.id, currentUserId),
                                    child: Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add_rounded,
                                          color: Colors.white, size: 22),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

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

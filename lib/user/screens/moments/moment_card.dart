import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/network_image.dart';
import 'dart:ui';
import '../../../core/providers/moment_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../camera/camera_capture_screen.dart';
import '../camera/web_rtc_camera_screen.dart';
import 'package:flutter/foundation.dart';
import 'video_player_widget.dart';
import '../matching/home_screen.dart';

/// Widget hiển thị chi tiết một moment với video/ảnh fullscreen,
/// thông tin user, reactions và action buttons (react, camera reply, send message).
class MomentCard extends StatefulWidget {
  final dynamic moment;
  final String currentUserId;

  const MomentCard({
    super.key,
    required this.moment,
    required this.currentUserId,
  });

  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final Map<String, Map<String, dynamic>> _userCache = {};
  Future<Map<String, dynamic>?>? _userInfoFuture;
  final Map<String, Future<DocumentSnapshot>> _reactionUserFutures = {};

  @override
  void initState() {
    super.initState();
    _userInfoFuture = _getUserInfo(widget.moment.userId);
  }

  Future<Map<String, dynamic>?> _getUserInfo(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (doc.exists) {
      _userCache[userId] = doc.data() as Map<String, dynamic>;
      return _userCache[userId];
    }
    return null;
  }

  dynamic get moment {
    try {
      final momentProvider = Provider.of<MomentProvider>(context);
      return momentProvider.moments.firstWhere(
        (m) => m.id == widget.moment.id,
        orElse: () => widget.moment,
      );
    } catch (_) {
      return widget.moment;
    }
  }

  String get currentUserId => widget.currentUserId;

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
    if (userId.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }
    Provider.of<MomentProvider>(
      context,
      listen: false,
    ).reactToMoment(momentId, userId, '❤️');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '❤️',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24),
        ),
        duration: Duration(milliseconds: 800),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showReactionPicker(
    BuildContext context,
    String momentId,
    String userId,
  ) {
    if (userId.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: const Offset(1.5, 1.5)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 6,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Text(
              'CHỌN CẢM XÚC',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: ['❤️', '😍', '😂', '😮', '😢', '👏', '🔥', '🎉'].map((
                emoji,
              ) {
                return GestureDetector(
                  onTap: () {
                    Provider.of<MomentProvider>(
                      context,
                      listen: false,
                    ).reactToMoment(momentId, userId, emoji);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white, // White
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: const Offset(1.5, 1.5)),
                      ],
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showReplyDialog(BuildContext context, String momentId, String userId) {
    if (userId.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: const Offset(1.5, 1.5)),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NHẮN TIN CHO NGƯỜI ĐĂNG',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: const Offset(1.5, 1.5)),
                        ],
                      ),
                      child: Theme(
                        data: ThemeData.light().copyWith(
                          textSelectionTheme: const TextSelectionThemeData(
                            cursorColor: Colors.black,
                            selectionColor: Colors.black26,
                            selectionHandleColor: Colors.black,
                          ),
                        ),
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          cursorColor: Colors.black,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Nhập nội dung...',
                            hintStyle: TextStyle(
                              color: Colors.black.withValues(alpha: 0.5),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
                          child: const Text(
                            'Hủy',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
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
                                final peerUserDoc = await FirebaseFirestore
                                    .instance
                                    .collection('users')
                                    .doc(momentOwnerId)
                                    .get();
                                final peerUser = UserModel.fromMap(
                                  peerUserDoc.data()!,
                                  momentOwnerId,
                                );
                                await Provider.of<ChatProvider>(
                                  context,
                                  listen: false,
                                ).sendMessageWithMedia(
                                  matchId,
                                  text,
                                  mediaUrl: moment.mediaUrl,
                                  isVideo: moment.isVideo,
                                );
                                Navigator.pop(ctx);
                                Navigator.pushNamed(
                                  context,
                                  '/chat',
                                  arguments: {
                                    'matchId': matchId,
                                    'peerUser': peerUser,
                                  },
                                );
                              } else {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Không thể nhắn cho chính mình!',
                                    ),
                                    backgroundColor: Colors.deepOrange,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          style:
                              ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: const Color(
                                      0xFFFF6E40,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                                elevation: 0,
                              ).copyWith(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) => const Color(
                                        0xFFFF6E40,
                                      ).withValues(alpha: 0.8),
                                    ),
                              ),
                          child: const Text(
                            'Gửi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4), // Light background
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: const Offset(1.5, 1.5)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 6,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'CẢM XÚC',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const Divider(color: Colors.black, height: 4, thickness: 3),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: byUser.entries.map<Widget>((entry) {
                  final future = _reactionUserFutures.putIfAbsent(
                    entry.key,
                    () => FirebaseFirestore.instance
                        .collection('users')
                        .doc(entry.key)
                        .get(),
                  );
                  return FutureBuilder<DocumentSnapshot>(
                    future: future,
                    builder: (context, snapshot) {
                      final user =
                          snapshot.data?.data() as Map<String, dynamic>?;
                      final avatarUrl = user?['avatarUrl'];
                      final username = user?['username'] ?? entry.key;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: const Offset(1.5, 1.5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF00E676),
                                child: avatarUrl != null
                                    ? ClipOval(
                                        child: GamenectNetworkImage(
                                          imageUrl: avatarUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Text(
                                        username.isNotEmpty
                                            ? username[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                username.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            // All emojis from this user
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: entry.value
                                  .map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        e,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  )
                                  .toList(),
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
    );
  }

  void _showReplyWithMediaDialog(
    BuildContext context,
    String momentId,
    String userId,
    Map mediaResult,
  ) {
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
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return FutureBuilder<Map<String, dynamic>?>(
      future: _userInfoFuture,
      builder: (context, snapshot) {
        final userInfo = snapshot.data;
        final username =
            userInfo?['username'] ??
            (moment.userId == currentUserId ? 'Bạn' : 'Người bạn');
        final avatarUrl = userInfo?['avatarUrl'];

        return GestureDetector(
          onDoubleTap: () => _quickReact(context, moment.id, currentUserId),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media (Khung viền tránh crop ảnh cho cả Web và Mobile App)
              Positioned(
                top: 16,
                bottom: 110,
                left: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: const Offset(1.5, 1.5)),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      moment.isVideo
                          ? (moment.isMirrored
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(3.141592653589793),
                                  child: VideoPlayerWidget(videoUrl: moment.mediaUrl),
                                )
                              : VideoPlayerWidget(videoUrl: moment.mediaUrl))
                          : GamenectNetworkImage(
                              imageUrl: moment.mediaUrl,
                              fit: BoxFit.contain,
                              errorWidget: (context, url, error) =>
                                  const Center(
                                    child: Icon(
                                      Icons.error_outline,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                            ),

                      // Gradient overlay bên trong frame để đảm bảo chữ đè lên ảnh đọc được
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 200,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // User info + caption (được căn chỉnh đẹp mắt bên trong frame trên Web, hoặc fullscreen trên App)
              Positioned(
                left: 28,
                right: 90,
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
                            border: Border.all(color: Colors.black, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: const Offset(1.5, 1.5),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[800],
                            child: avatarUrl != null
                                ? ClipOval(
                                    child: GamenectNetworkImage(
                                      imageUrl: avatarUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Text(
                                    username.isNotEmpty
                                        ? username.substring(0, 1).toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      offset: const Offset(1.5, 1.5),
                                    ),
                                  ],
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(moment.createdAt),
                                style: TextStyle(
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Caption
                    if (moment.caption?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      Text(
                        moment.caption!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          shadows: [
                            Shadow(color: Colors.black, offset: Offset(1, 1)),
                          ],
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Reactions grouped by user (like TikTok)
                    if (moment.reactions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () =>
                            _showReactionUsers(context, moment.reactions),
                        child: Builder(
                          builder: (context) {
                            // Group by user
                            final Map<String, List<String>> byUser = {};
                            for (final r in moment.reactions) {
                              final uid = r['userId'] as String? ?? '';
                              byUser
                                  .putIfAbsent(uid, () => [])
                                  .add(r['emoji'] as String? ?? '❤️');
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: byUser.entries.take(4).map<Widget>((
                                entry,
                              ) {
                                final future = _reactionUserFutures.putIfAbsent(
                                  entry.key,
                                  () => FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(entry.key)
                                      .get(),
                                );
                                return FutureBuilder<DocumentSnapshot>(
                                  future: future,
                                  builder: (context, snapshot) {
                                    final user =
                                        snapshot.data?.data()
                                            as Map<String, dynamic>?;
                                    final av = user?['avatarUrl'];
                                    final uname = user?['username'] ?? '';
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 10,
                                          sigmaY: 10,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircleAvatar(
                                                radius: 11,
                                                backgroundColor:
                                                    Colors.grey[700],
                                                child: av != null
                                                    ? ClipOval(
                                                        child:
                                                            GamenectNetworkImage(
                                                              imageUrl: av,
                                                              width: 22,
                                                              height: 22,
                                                              fit: BoxFit.cover,
                                                            ),
                                                      )
                                                    : Text(
                                                        uname.isNotEmpty
                                                            ? uname[0]
                                                                  .toUpperCase()
                                                            : '?',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 5),
                                              // All emojis inline
                                              ...entry.value
                                                  .take(3)
                                                  .map(
                                                    (e) => Text(
                                                      e,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
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
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // TikTok-style vertical emoji bar on the RIGHT (only for others' moments)
              if (moment.userId != currentUserId)
                Positioned(
                  right: 28,
                  bottom: 130,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...['❤️', '😂', '🔥', '😍'].map(
                        (emoji) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () {
                              Provider.of<MomentProvider>(
                                context,
                                listen: false,
                              ).reactToMoment(moment.id, currentUserId, emoji);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    emoji,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                  duration: const Duration(milliseconds: 600),
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white, // White
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: const Offset(1.5, 1.5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // + button
                      GestureDetector(
                        onTap: () => _showReactionPicker(
                          context,
                          moment.id,
                          currentUserId,
                        ),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF), // Cyan
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: const Offset(1.5, 1.5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.black,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action buttons bar (camera + send only)
              Positioned(
                left: 16,
                right: 16,
                bottom: 40,
                child: Row(
                  children: [
                    // Camera button
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WebRTCCameraScreen(),
                          ),
                        );
                        if (result != null && result is Map) {
                          _showReplyWithMediaDialog(
                            context,
                            moment.id,
                            currentUserId,
                            result,
                          );
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6E40), // Deep Orange
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: const Offset(1.5, 1.5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.black,
                          size: 28,
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Send message button
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _showReplyDialog(context, moment.id, currentUserId),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F4), // Light gray
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: const Offset(1.5, 1.5),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_rounded,
                                color: Colors.black,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'GỬI',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ],
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

  @override
  void dispose() {
    super.dispose();
  }
}

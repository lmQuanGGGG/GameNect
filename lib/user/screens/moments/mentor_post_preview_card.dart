import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/services/video_warmup_service.dart';
import '../../../core/widgets/network_image.dart';
import 'video_player_widget.dart';

class MentorPostPreviewCard extends StatefulWidget {
  final Widget fallback;
  final Future<void> Function() onTap;
  final double height;
  final double mediaAspectRatio;
  final bool autoplayVideo;
  final bool splitEvenly;

  const MentorPostPreviewCard({
    super.key,
    required this.fallback,
    required this.onTap,
    required this.height,
    this.mediaAspectRatio = 0.65,
    this.autoplayVideo = false,
    this.splitEvenly = false,
  });

  @override
  State<MentorPostPreviewCard> createState() => _MentorPostPreviewCardState();
}

class _MentorPostPreviewCardState extends State<MentorPostPreviewCard> {
  static final Map<String, Map<String, dynamic>> _mentorCache = {};

  Set<String> _seenPostIds = {};
  bool _seenPostIdsLoaded = false;

  String get _seenPostsKey {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'seen_mentor_post_ids_$userId';
  }

  @override
  void initState() {
    super.initState();
    _loadSeenPostIds();
  }

  Future<void> _loadSeenPostIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _seenPostIds = prefs.getStringList(_seenPostsKey)?.toSet() ?? {};
      _seenPostIdsLoaded = true;
    });
  }

  Future<void> _openPost(String postId) async {
    await _markPostSeen(postId);
    if (!mounted) return;

    await widget.onTap();
    await _loadSeenPostIds();
  }

  Future<void> _markPostSeen(String postId) async {
    final updatedIds = {..._seenPostIds, postId};
    setState(() => _seenPostIds = updatedIds);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenPostsKey, updatedIds.toList());
  }

  Future<Map<String, dynamic>?> _loadMentor(String mentorId) async {
    if (mentorId.isEmpty) return null;
    if (_mentorCache.containsKey(mentorId)) return _mentorCache[mentorId];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(mentorId)
        .get();

    final data = snapshot.data();
    if (data != null) _mentorCache[mentorId] = data;
    return data;
  }

  @override
  Widget build(BuildContext context) {
    if (!_seenPostIdsLoaded) return widget.fallback;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('mentor_media')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final validDocs = docs.where((doc) {
          final data = doc.data();
          final isVideo = data['type'] == 'video';
          final previewUrl = isVideo
              ? (data['thumbnailUrl'] as String? ?? '')
              : (data['url'] as String? ?? '');
          return previewUrl.isNotEmpty;
        }).toList();

        if (validDocs.isEmpty) return widget.fallback;

        final unseenDocs = validDocs
            .where((doc) => !_seenPostIds.contains(doc.id))
            .toList();

        final previewDoc = unseenDocs.isNotEmpty
            ? unseenDocs.first
            : validDocs.first;

        final stackCount = unseenDocs.isEmpty
            ? 1
            : unseenDocs.length.clamp(1, 3);

        final data = previewDoc.data();
        final isVideo = data['type'] == 'video';
        final previewUrl = isVideo
            ? data['thumbnailUrl'] as String
            : data['url'] as String;

        final videoUrl = data['url'] as String? ?? '';
        if (isVideo && videoUrl.isNotEmpty) {
          VideoWarmupService.warmUp(videoUrl);
        }

        final mentorId = data['mentorId'] as String? ?? '';
        final caption = data['caption'] as String? ?? '';
        final likes = List<String>.from(data['likes'] as List? ?? const []);
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

        return FutureBuilder<Map<String, dynamic>?>(
          future: _loadMentor(mentorId),
          builder: (context, mentorSnapshot) {
            final mentor = mentorSnapshot.data;
            final mentorName = mentor?['username'] as String? ?? 'Mentor';
            final avatarUrl = mentor?['avatarUrl'] as String? ?? '';

            return _buildPreview(
              context,
              postId: previewDoc.id,
              previewUrl: previewUrl,
              videoUrl: videoUrl,
              isVideo: isVideo,
              mentorName: mentorName,
              avatarUrl: avatarUrl,
              caption: caption,
              likeCount: likes.length,
              isLiked: likes.contains(currentUserId),
              stackCount: stackCount,
              unseenCount: unseenDocs.length,
              hasMoreUnseenPosts: unseenDocs.length > 1,
            );
          },
        );
      },
    );
  }

  Widget _buildPreview(
    BuildContext context, {
    required String postId,
    required String previewUrl,
    required String videoUrl,
    required bool isVideo,
    required String mentorName,
    required String avatarUrl,
    required String caption,
    required int likeCount,
    required bool isLiked,
    required int stackCount,
    required int unseenCount,
    required bool hasMoreUnseenPosts,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final advancePost = hasMoreUnseenPosts
        ? () => _markPostSeen(postId)
        : () => _openPost(postId);

    return SizedBox(
      height: widget.height + (stackCount > 1 ? 12 : 0),
      width: double.infinity,
      child: Stack(
        children: [
          if (stackCount >= 3)
            Positioned(
              top: 12,
              left: 12,
              right: 0,
              bottom: 0,
              child: _buildStackLayer(borderColor, cardColor),
            ),
          if (stackCount >= 2)
            Positioned(
              top: 6,
              left: 6,
              right: 6,
              bottom: 6,
              child: _buildStackLayer(borderColor, cardColor),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.height,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(-0.18, -0.05),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: _buildFrontCard(
                context,
                key: ValueKey(postId),
                previewUrl: previewUrl,
                videoUrl: videoUrl,
                isVideo: isVideo,
                mentorName: mentorName,
                avatarUrl: avatarUrl,
                caption: caption,
                likeCount: likeCount,
                isLiked: isLiked,
                postId: postId,
                borderColor: borderColor,
                cardColor: cardColor,
                textColor: textColor,
                unseenCount: unseenCount,
                hasUnseenPosts:
                    stackCount > 1 || !_seenPostIds.contains(postId),
                onImageTap: advancePost,
                onButtonTap: () => _openPost(postId),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackLayer(Color borderColor, Color cardColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 4),
      ),
    );
  }

  Widget _buildFrontCard(
    BuildContext context, {
    Key? key,
    required String previewUrl,
    required String videoUrl,
    required bool isVideo,
    required String mentorName,
    required String avatarUrl,
    required String caption,
    required int likeCount,
    required bool isLiked,
    required String postId,
    required Color borderColor,
    required Color cardColor,
    required Color textColor,
    required int unseenCount,
    required bool hasUnseenPosts,
    required VoidCallback onImageTap,
    required Future<void> Function() onButtonTap,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [BoxShadow(color: borderColor, offset: const Offset(6, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideLayout = constraints.maxWidth >= 700;
          final isLargeDesktop = constraints.maxWidth >= 1200;
          final barHeight = isWideLayout ? 58.0 : 46.0;
          final mediaHeight = constraints.maxHeight - barHeight;
          final gridRatioWidth = mediaHeight * widget.mediaAspectRatio;
          final maxMediaWidth =
              constraints.maxWidth * (isWideLayout ? 0.36 : 0.62);

          final mediaWidth = widget.splitEvenly && !isWideLayout
              ? (constraints.maxWidth - 4) / 2
              : gridRatioWidth.clamp(0.0, maxMediaWidth);

          final unseenLabel = unseenCount > 99 ? '99+' : '$unseenCount';

          return Stack(
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: isVideo && widget.autoplayVideo
                          ? null
                          : onImageTap,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: SizedBox(
                          width: mediaWidth,
                          height: constraints.maxHeight,
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (isVideo &&
                                        widget.autoplayVideo &&
                                        videoUrl.isNotEmpty)
                                      ColoredBox(
                                        color: Colors.black,
                                        child: VideoPlayerWidget(
                                          videoUrl: videoUrl,
                                          compactControls: true,
                                          webAutoplayFallback: true,
                                        ),
                                      )
                                    else
                                      GamenectNetworkImage(
                                        imageUrl: previewUrl,
                                        fit: BoxFit.cover,
                                        width: mediaWidth,
                                      ),
                                    if (isVideo && !widget.autoplayVideo)
                                      const Center(
                                        child: Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                          size: 44,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onImageTap,
                                child: Container(
                                  width: double.infinity,
                                  height: barHeight,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWideLayout ? 12 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    border: Border(
                                      top: BorderSide(
                                        color: borderColor,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: borderColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: avatarUrl.isNotEmpty
                                              ? GamenectNetworkImage(
                                                  imageUrl: avatarUrl,
                                                  width: isWideLayout ? 34 : 26,
                                                  height: isWideLayout
                                                      ? 34
                                                      : 26,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  width: isWideLayout ? 34 : 26,
                                                  height: isWideLayout
                                                      ? 34
                                                      : 26,
                                                  color: const Color(
                                                    0xFFFF6E40,
                                                  ),
                                                  child: Icon(
                                                    Icons.person,
                                                    color: textColor,
                                                    size: isWideLayout
                                                        ? 19
                                                        : 15,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      SizedBox(width: isWideLayout ? 9 : 6),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              mentorName.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: isWideLayout
                                                    ? 15
                                                    : 12,
                                                height: 1,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            if (caption.isNotEmpty)
                                              Text(
                                                caption,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: textColor.withValues(
                                                    alpha: 0.85,
                                                  ),
                                                  fontSize: isWideLayout
                                                      ? 12
                                                      : 10,
                                                  height: 1,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 4, color: borderColor),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, rightConstraints) {
                          final button = _buildOpenButton(
                            borderColor,
                            onButtonTap,
                            isWideLayout: isWideLayout,
                          );

                          final likeButton = _buildLikeButton(
                            postId: postId,
                            likeCount: likeCount,
                            isLiked: isLiked,
                            borderColor: borderColor,
                            cardColor: cardColor,
                            textColor: textColor,
                          );

                          final unseenBadge = _buildUnseenBadge(
                            unseenLabel: unseenLabel,
                            borderColor: borderColor,
                            onTap: onButtonTap,
                            isWideLayout: isWideLayout,
                          );

                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              isWideLayout ? 20 : 12,
                              isWideLayout ? 16 : 10,
                              isWideLayout ? 20 : 12,
                              isWideLayout ? 20 : 2, // Bỏ bottom padding trên mobile theo yêu cầu
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, // Căn trái toàn bộ cho gọn gàng
                              children: [
                                if (unseenCount > 0) ...[
                                  unseenBadge,
                                  SizedBox(height: isWideLayout ? 14 : 10),
                                ],

                                Text(
                                  isWideLayout
                                      ? 'MENTOR POSTS'
                                      : 'MENTOR\nPOSTS',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: isLargeDesktop
                                        ? 34
                                        : (isWideLayout ? 28 : 20),
                                    height: 1.15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),

                                SizedBox(height: isWideLayout ? 12 : 8),

                                if (hasUnseenPosts) ...[
                                  GestureDetector(
                                    onTap: onButtonTap,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isWideLayout ? 12 : 9,
                                        vertical: isWideLayout ? 8 : 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(
                                          20,
                                        ),
                                        border: Border.all(
                                          color: borderColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            unseenCount > 1
                                                ? 'Chạm ảnh để xem'
                                                : 'Bấm Xem vào Post',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: isWideLayout
                                                  ? 13
                                                  : 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Icon(
                                            Icons.touch_app_rounded,
                                            color: Colors.black,
                                            size: isWideLayout ? 18 : 15,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(height: isWideLayout ? 16 : 6),
                                const Spacer(),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: button,
                                    ),
                                    const SizedBox(height: 10),
                                    likeButton,
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnseenBadge({
    required String unseenLabel,
    required Color borderColor,
    required Future<void> Function() onTap,
    required bool isWideLayout,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(maxWidth: isWideLayout ? 150 : 112),
        padding: EdgeInsets.symmetric(
          horizontal: isWideLayout ? 14 : 10,
          vertical: isWideLayout ? 10 : 7,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFF2D55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(color: borderColor, offset: const Offset(4, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  unseenLabel,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isWideLayout ? 24 : 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SizedBox(width: isWideLayout ? 7 : 5),
            Text(
              'CHƯA XEM',
              style: TextStyle(
                color: Colors.white,
                fontSize: isWideLayout ? 11 : 8,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenButton(
    Color borderColor,
    Future<void> Function() onTap, {
    required bool isWideLayout,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: isWideLayout ? 14 : 10,
          horizontal: 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6E40),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(color: borderColor, offset: const Offset(3, 3)),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'XEM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isWideLayout ? 16 : 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: isWideLayout ? 22 : 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLikeButton({
    required String postId,
    required int likeCount,
    required bool isLiked,
    required Color borderColor,
    required Color cardColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: () {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (userId.isEmpty) {
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
        FirestoreService().toggleLikeMentorMedia(postId, userId);
      },
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: isLiked ? const Color(0xFFFF2D55) : cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(color: borderColor, offset: const Offset(3, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? Colors.white : textColor,
              size: 17,
            ),
            if (likeCount > 0) ...[
              const SizedBox(width: 3),
              Text(
                likeCount.toString(),
                style: TextStyle(
                  color: isLiked ? Colors.white : textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/services/video_warmup_service.dart';
import '../../../core/widgets/network_image.dart';
import 'video_player_widget.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/match_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../matching/home_screen.dart';
import '../mentor/all_mentor_media_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class MentorPostPreviewCard extends StatefulWidget {
  final Widget fallback;
  final Future<void> Function() onTap;
  final double height;
  final double mediaAspectRatio;
  final bool autoplayVideo;
  final bool splitEvenly;
  final bool hideDetails;

  const MentorPostPreviewCard({
    super.key,
    required this.fallback,
    required this.onTap,
    required this.height,
    this.mediaAspectRatio = 0.65,
    this.autoplayVideo = false,
    this.splitEvenly = false,
    this.hideDetails = false,
  });

  @override
  State<MentorPostPreviewCard> createState() => _MentorPostPreviewCardState();
}

class _MentorPostPreviewCardState extends State<MentorPostPreviewCard> {
  static final Map<String, Map<String, dynamic>> _mentorCache = {};

  Set<String> _seenPostIds = {};
  bool _seenPostIdsLoaded = false;
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isAudioInitialized = false;

  String get _seenPostsKey {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'seen_mentor_post_ids_$userId';
  }

  void _showShareBottomSheet(
    BuildContext context,
    String postId,
    String previewUrl,
    bool isVideo,
    String mentorName,
    String mentorId,
  ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: Provider.of<MatchProvider>(
                context,
                listen: false,
              ).fetchMatchedUsersWithMatchId(currentUserId),
              builder: (context, snapshot) {
                return Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: const Border(
                      top: BorderSide(color: Colors.black, width: 1.5),
                      left: BorderSide(color: Colors.black, width: 1.5),
                      right: BorderSide(color: Colors.black, width: 1.5),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(0, -4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 20),
                        width: 40,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const Text(
                        'CHIA SẺ BÀI VIẾT',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'GỬI POST CỦA "${mentorName.toUpperCase()}"',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: 'https://gamenect.vn/mentor/$mentorId/post/$postId'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'ĐÃ SAO CHÉP LIÊN KẾT',
                                    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                  backgroundColor: Colors.white,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Colors.black, width: 1.5),
                                  ),
                                ),
                              );
                              Navigator.pop(bottomSheetContext);
                            },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black, width: 1.5),
                                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5))],
                                  ),
                                  child: const Icon(Icons.link, color: Colors.black, size: 24),
                                ),
                                const SizedBox(height: 8),
                                const Text('Copy Link', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Share.share('Xem bài viết cực hay trên Gamenect ngay: https://gamenect.vn/mentor/$mentorId/post/$postId');
                              Navigator.pop(bottomSheetContext);
                            },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black, width: 1.5),
                                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5))],
                                  ),
                                  child: const Icon(Icons.share_outlined, color: Colors.black, size: 24),
                                ),
                                const SizedBox(height: 8),
                                const Text('Ứng dụng khác', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value.toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm bạn bè...',
                            hintStyle: const TextStyle(color: Colors.black54),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.black54,
                            ),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(
                        color: Colors.black,
                        height: 4,
                        thickness: 4,
                      ),
                      Expanded(
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF6E40),
                                ),
                              )
                            : snapshot.hasError ||
                                  !snapshot.hasData ||
                                  snapshot.data!.isEmpty
                            ? const Center(
                                child: Text(
                                  'BẠN CHƯA CÓ MATCH NÀO',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : Builder(
                                builder: (context) {
                                  final allMatches = snapshot.data!;
                                  final filteredMatches = searchQuery.isEmpty
                                      ? allMatches
                                      : allMatches.where((m) {
                                          final username =
                                              (m['user'].username ?? '')
                                                  .toLowerCase();
                                          return username.contains(searchQuery);
                                        }).toList();

                                  if (filteredMatches.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'KHÔNG TÌM THẤY BẠN BÈ',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    itemCount: filteredMatches.length,
                                    itemBuilder: (context, index) {
                                      final matchData = filteredMatches[index];
                                      final user = matchData['user'];
                                      final matchId = matchData['matchId'];

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 8,
                                            ),
                                        leading: ClipOval(
                                          child: SizedBox(
                                            width: 48,
                                            height: 48,
                                            child:
                                                user.avatarUrl != null &&
                                                    user.avatarUrl!.isNotEmpty
                                                ? GamenectNetworkImage(
                                                    imageUrl: user.avatarUrl!,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Container(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                            ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Container(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                              child: const Icon(
                                                                Icons.person,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                            ),
                                                  )
                                                : Container(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.1),
                                                    child: const Icon(
                                                      Icons.person,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        title: Text(
                                          user.username ?? 'User',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        trailing: GestureDetector(
                                          onTap: () {
                                            Navigator.pop(bottomSheetContext);

                                            Provider.of<ChatProvider>(
                                              context,
                                              listen: false,
                                            ).sendMentorPostMessage(
                                              matchId,
                                              postId,
                                              previewUrl,
                                              isVideo,
                                              mentorName,
                                              peerUser: user,
                                            );

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'ĐÃ GỬI BÀI VIẾT CHO ${user.username?.toUpperCase() ?? "BẠN BÈ"}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                backgroundColor: Colors.white,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: const BorderSide(
                                                    color: Colors.black,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                            child: const Text(
                                              'GỬI',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSeenPostIds();
    if (!_isAudioInitialized) {
      _audioPlayer.setAsset('assets/sound/sounddd.mp3');
      _audioPlayer.setSpeed(1.0);
      _isAudioInitialized = true;
    }
  }

  @override
  void dispose() {
    // _audioPlayer.dispose(); // Do not dispose static instance
    super.dispose();
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllMentorMediaScreen(initialPostId: postId),
      ),
    );
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
              mentorId: mentorId,
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
    required String mentorId,
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
        ? () {
            _audioPlayer.pause();
            _audioPlayer.seek(Duration.zero).then((_) => _audioPlayer.play());
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) _markPostSeen(postId);
            });
          }
        : () {
            _audioPlayer.pause();
            _audioPlayer.seek(Duration.zero).then((_) => _audioPlayer.play());
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) _openPost(postId);
            });
          };

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
                mentorId: mentorId,
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
                onAllButtonTap: () => widget.onTap(),
                isWideLayout: (MediaQuery.of(context).size.width >= 700),
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
        border: Border.all(color: borderColor, width: 1.5),
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
    required String mentorId,
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
    required Future<void> Function() onAllButtonTap,
    required bool isWideLayout,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [BoxShadow(color: borderColor, offset: const Offset(1.5, 1.5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideLayout = constraints.maxWidth >= 500;
          final isLargeDesktop = constraints.maxWidth >= 1200;
          final barHeight = isWideLayout ? 58.0 : 46.0;
          final mediaHeight = constraints.maxHeight - barHeight;
          final gridRatioWidth = mediaHeight * widget.mediaAspectRatio;
          final maxMediaWidth =
              constraints.maxWidth * (isWideLayout ? 0.45 : 0.62);

          final mediaWidth = widget.hideDetails
              ? constraints.maxWidth
              : (widget.splitEvenly
                    ? (constraints.maxWidth - 4) / 2
                    : gridRatioWidth.clamp(0.0, maxMediaWidth));

          final unseenLabel = unseenCount > 99 ? '99+' : '$unseenCount';

          return Stack(
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: widget.hideDetails ? 1 : 0,
                      child: GestureDetector(
                        onTap: isVideo && widget.autoplayVideo
                            ? null
                            : onImageTap,
                        child: ClipRRect(
                          borderRadius: widget.hideDetails
                              ? BorderRadius.circular(12)
                              : const BorderRadius.only(
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
                                          width: 1.5,
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
                                              width: 1.5,
                                            ),
                                          ),
                                          child: ClipOval(
                                            child: avatarUrl.isNotEmpty
                                                ? GamenectNetworkImage(
                                                    imageUrl: avatarUrl,
                                                    width: isWideLayout
                                                        ? 34
                                                        : 26,
                                                    height: isWideLayout
                                                        ? 34
                                                        : 26,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Container(
                                                    width: isWideLayout
                                                        ? 34
                                                        : 26,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                        if (widget.hideDetails)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  final userId =
                                                      FirebaseAuth
                                                          .instance
                                                          .currentUser
                                                          ?.uid ??
                                                      '';
                                                  if (userId.isEmpty) {
                                                    Navigator.pushReplacementNamed(
                                                      context,
                                                      '/login',
                                                    );
                                                    return;
                                                  }
                                                  FirestoreService()
                                                      .toggleLikeMentorMedia(
                                                        postId,
                                                        userId,
                                                      );
                                                },
                                                child: Container(
                                                  color: Colors.transparent,
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isLiked
                                                            ? Icons
                                                                  .favorite_rounded
                                                            : Icons
                                                                  .favorite_border_rounded,
                                                        size: 18,
                                                        color: isLiked
                                                            ? Colors.red
                                                            : textColor,
                                                      ),
                                                      if (likeCount > 0) ...[
                                                        const SizedBox(
                                                          width: 1.5,
                                                        ),
                                                        Text(
                                                          '$likeCount',
                                                          style: TextStyle(
                                                            color: textColor,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: () => _showShareBottomSheet(
                                                  context,
                                                  postId,
                                                  previewUrl,
                                                  isVideo,
                                                  mentorName,
                                                  mentorId,
                                                ),
                                                child: Container(
                                                  color: Colors.transparent,
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  child: Icon(
                                                    Icons.share_rounded,
                                                    size: 18,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: onButtonTap,
                                                child: Container(
                                                  color: Colors.transparent,
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Xem',
                                                        style: TextStyle(
                                                          color: textColor,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.remove_red_eye_rounded,
                                                        size: 18,
                                                        color: textColor,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 1.5),
                                            ],
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
                    ),
                    if (!widget.hideDetails) ...[
                      Container(width: 1.5, color: borderColor),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onImageTap,
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
                                isWideLayout: isWideLayout,
                              );

                              final unseenBadge = _buildUnseenBadge(
                                unseenLabel: unseenLabel,
                                borderColor: borderColor,
                                onTap: onButtonTap,
                                isWideLayout: isWideLayout,
                              );

                              final shareBtn = GestureDetector(
                                onTap: () {
                                  _showShareBottomSheet(
                                    context,
                                    postId,
                                    previewUrl,
                                    isVideo,
                                    mentorName,
                                    mentorId,
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.all(
                                    isWideLayout ? 11 : 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: borderColor,
                                        offset: const Offset(1.5, 1.5),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.share_rounded,
                                    color: Colors.black,
                                    size: isWideLayout ? 26 : 20,
                                  ),
                                ),
                              );

                              return Padding(
                                padding: EdgeInsets.fromLTRB(
                                  isWideLayout ? 20 : 12,
                                  isWideLayout ? 16 : 10,
                                  isWideLayout ? 20 : 12,
                                  isWideLayout ? 20 : 2,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: unseenCount > 0
                                              ? unseenBadge
                                              : const SizedBox.shrink(),
                                        ),
                                        const SizedBox(width: 1.5),
                                        GestureDetector(
                                          onTap: onAllButtonTap,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: borderColor,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Tất cả',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  size: 10,
                                                  color: Colors.black,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isWideLayout ? 14 : 10),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
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
                                        if (!isWideLayout) shareBtn,
                                      ],
                                    ),

                                    SizedBox(height: isWideLayout ? 12 : 8),

                                    if (hasUnseenPosts) ...[
                                      GestureDetector(
                                        onTap: unseenCount > 1 ? onImageTap : onButtonTap,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF3E0),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: borderColor,
                                              width: 1.5,
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
                                                      ? 11
                                                      : 10,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Icon(
                                                Icons.touch_app_rounded,
                                                color: Colors.black,
                                                size: isWideLayout ? 16 : 15,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: isWideLayout ? 16 : 6),
                                    const Spacer(),

                                    if (isWideLayout)
                                      Row(
                                        children: [
                                          Expanded(child: button),
                                          const SizedBox(width: 12),
                                          likeButton,
                                          const SizedBox(width: 12),
                                          shareBtn,
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(child: button),
                                          const SizedBox(width: 8),
                                          likeButton,
                                          // Chừa chỗ cho nút LIVE và CAMERA FAB
                                          const SizedBox(width: 44),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
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
        constraints: BoxConstraints(maxWidth: isWideLayout ? 130 : 112),
        padding: EdgeInsets.symmetric(
          horizontal: isWideLayout ? 12 : 10,
          vertical: isWideLayout ? 8 : 7,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFF2D55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(color: borderColor, offset: const Offset(1.5, 1.5)),
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
                    fontSize: isWideLayout ? 20 : 18,
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
                fontSize: isWideLayout ? 9 : 6.5,
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
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(color: borderColor, offset: const Offset(1.5, 1.5)),
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
                  fontSize: isWideLayout ? 16 : 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.remove_red_eye_rounded,
                color: Colors.white,
                size: isWideLayout ? 24 : 20,
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
    required bool isWideLayout,
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
        padding: EdgeInsets.symmetric(
          vertical: isWideLayout ? 11 : 7,
          horizontal: isWideLayout ? 11 : 9,
        ),
        decoration: BoxDecoration(
          color: isLiked ? const Color(0xFFFF2D55) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(color: borderColor, offset: const Offset(1.5, 1.5)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? Colors.white : Colors.black,
              size: isWideLayout ? 26 : 20,
            ),
            if (likeCount > 0) ...[
              SizedBox(width: isWideLayout ? 6 : 4),
              Text(
                likeCount.toString(),
                style: TextStyle(
                  color: isLiked ? Colors.white : Colors.black,
                  fontSize: isWideLayout ? 14 : 12,
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

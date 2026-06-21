import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/network_image.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import '../matching/home_screen.dart';
import '../chat/video_player_bubble.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/video_warmup_service.dart';
import 'mentor_profile_screen.dart';
import '../../../core/theme/theme_helper.dart';

class MentorMediaFeedScreen extends StatefulWidget {
  static final Map<String, Map<String, dynamic>> mentorCache = {};
  final List<DocumentSnapshot> docs;
  final int initialIndex;

  const MentorMediaFeedScreen({
    super.key,
    required this.docs,
    required this.initialIndex,
  });

  @override
  State<MentorMediaFeedScreen> createState() => _MentorMediaFeedScreenState();
}

class _MentorMediaFeedScreenState extends State<MentorMediaFeedScreen> {
  late PageController _pageController;
  bool isGridMode = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String get _seenPostsKey {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'seen_mentor_post_ids_$userId';
  }

  List<DocumentSnapshot> get filteredDocs {
    if (_searchQuery.trim().isEmpty) return widget.docs;
    final query = _searchQuery.toLowerCase().trim();
    return widget.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final caption = (data['caption'] as String? ?? '').toLowerCase();
      final mentorId = data['mentorId'] as String? ?? '';
      final mentorName =
          (MentorMediaFeedScreen.mentorCache[mentorId]?['username']
                      as String? ??
                  '')
              .toLowerCase();

      return caption.contains(query) || mentorName.contains(query);
    }).toList();
  }

  void _preloadNextMedia(int currentIndex, List<DocumentSnapshot> docs) {
    if (currentIndex >= docs.length - 1) return;

    final endIndex = (currentIndex + 2).clamp(0, docs.length - 1);

    for (var index = currentIndex + 1; index <= endIndex; index++) {
      final data = docs[index].data() as Map<String, dynamic>;
      final isVideo = data['type'] == 'video';
      final url = isVideo
          ? (data['thumbnailUrl'] as String? ?? '')
          : (data['url'] as String? ?? '');
      if (url.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(url), context);
      }
      final videoUrl = data['url'] as String? ?? '';
      if (isVideo && videoUrl.isNotEmpty) {
        VideoWarmupService.warmUp(videoUrl);
      }
    }
  }

  Future<void> _markPostSeen(int index, List<DocumentSnapshot> docs) async {
    if (index < 0 || index >= docs.length) return;

    final prefs = await SharedPreferences.getInstance();
    final seenIds = prefs.getStringList(_seenPostsKey)?.toSet() ?? {};
    if (seenIds.add(docs[index].id)) {
      await prefs.setStringList(_seenPostsKey, seenIds.toList());
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markPostSeen(widget.initialIndex, filteredDocs);
      _preloadNextMedia(widget.initialIndex, filteredDocs);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docsToDisplay = filteredDocs;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: context.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: context.appBarBgColor,
        elevation: 0,
        title: Text(
          'BÀI VIẾT MENTOR',
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        iconTheme: IconThemeData(color: context.textColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(color: context.textColor, height: 3),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isGridMode ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
              color: context.textColor,
            ),
            onPressed: () {
              setState(() {
                isGridMode = !isGridMode;
                if (!isGridMode) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_pageController.hasClients) {
                      // Do nothing, it stays at last index
                    }
                  });
                }
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Content
          isGridMode
              ? GridView.builder(
                  padding: EdgeInsets.only(
                    top:
                        MediaQuery.of(context).padding.top +
                        kToolbarHeight +
                        16,
                    left: 12,
                    right: 12,
                    bottom: 100,
                  ), // Extra bottom padding for search bar
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0, // Square grid
                  ),
                  itemCount: docsToDisplay.length,
                  itemBuilder: (context, i) {
                    final data =
                        docsToDisplay[i].data() as Map<String, dynamic>;
                    return MentorGridItem(
                      data: data,
                      onTap: () {
                        setState(() {
                          isGridMode = false;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(i);
                          }
                          _preloadNextMedia(i, docsToDisplay);
                        });
                      },
                    );
                  },
                )
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: docsToDisplay.length,
                  onPageChanged: (index) {
                    _markPostSeen(index, docsToDisplay);
                    _preloadNextMedia(index, docsToDisplay);
                  },
                  itemBuilder: (context, index) {
                    return MentorMediaFeedCard(doc: docsToDisplay[index]);
                  },
                ),

          // Transparent Neo-Brutalism Search Bar
          if (isGridMode)
            Positioned(
              bottom:
                  MediaQuery.of(context).padding.bottom +
                  20 +
                  MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.textColor, width: 3),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: 'TÌM KIẾM MENTOR...',
                        hintStyle: TextStyle(
                          color: context.textSecondaryColor,
                          fontWeight: FontWeight.w900,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: context.textColor,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: context.textColor,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MentorGridItem extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const MentorGridItem({super.key, required this.data, required this.onTap});

  @override
  State<MentorGridItem> createState() => _MentorGridItemState();
}

class _MentorGridItemState extends State<MentorGridItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? mentorData;

  @override
  void initState() {
    super.initState();
    _fetchMentorData();
  }

  Future<void> _fetchMentorData() async {
    final mentorId = widget.data['mentorId'] as String? ?? '';
    if (mentorId.isNotEmpty) {
      if (MentorMediaFeedScreen.mentorCache.containsKey(mentorId)) {
        if (mounted) {
          setState(
            () => mentorData = MentorMediaFeedScreen.mentorCache[mentorId],
          );
        }
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(mentorId)
          .get();
      if (doc.exists && mounted) {
        MentorMediaFeedScreen.mentorCache[mentorId] =
            doc.data() as Map<String, dynamic>;
        setState(
          () => mentorData = MentorMediaFeedScreen.mentorCache[mentorId],
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isVideo = widget.data['type'] == 'video';
    final url = widget.data['url'] as String? ?? '';
    final caption = widget.data['caption'] as String?;
    final avatarUrl = mentorData?['avatarUrl'] as String?;
    final username = mentorData?['username'] as String? ?? 'Mentor';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.textColor, width: 3),
          boxShadow: [
            BoxShadow(color: context.textColor, offset: const Offset(3, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url.isNotEmpty)
                (isVideo &&
                        (widget.data['thumbnailUrl'] == null ||
                            widget.data['thumbnailUrl'].toString().isEmpty))
                    ? Container(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                      )
                    : GamenectNetworkImage(
                        imageUrl: isVideo ? widget.data['thumbnailUrl']! : url,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.white10),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white10,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white38,
                          ),
                        ),
                      )
              else
                Container(
                  color: Colors.white10,
                  child: const Icon(Icons.image, color: Colors.white24),
                ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Play icon overlay for videos
              if (isVideo)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),

              // User info and caption at the bottom
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          caption!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6E40),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          clipBehavior: Clip.hardEdge,
                          child: avatarUrl != null
                              ? GamenectNetworkImage(
                                  imageUrl: avatarUrl,
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.cover,
                                )
                              : Text(
                                  username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 12,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MentorMediaFeedCard extends StatefulWidget {
  final DocumentSnapshot doc;
  const MentorMediaFeedCard({super.key, required this.doc});

  @override
  State<MentorMediaFeedCard> createState() => _MentorMediaFeedCardState();
}

class _MentorMediaFeedCardState extends State<MentorMediaFeedCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Map<String, dynamic>? mentorData;

  @override
  void initState() {
    super.initState();
    _fetchMentorData();
  }

  Future<void> _fetchMentorData() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final mentorId = data['mentorId'] as String? ?? '';
    if (mentorId.isNotEmpty) {
      if (MentorMediaFeedScreen.mentorCache.containsKey(mentorId)) {
        if (mounted) {
          setState(
            () => mentorData = MentorMediaFeedScreen.mentorCache[mentorId],
          );
        }
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(mentorId)
          .get();
      if (doc.exists && mounted) {
        MentorMediaFeedScreen.mentorCache[mentorId] =
            doc.data() as Map<String, dynamic>;
        setState(
          () => mentorData = MentorMediaFeedScreen.mentorCache[mentorId],
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = widget.doc.data() as Map<String, dynamic>;
    final isVideo = data['type'] == 'video';
    final url = data['url'] as String? ?? '';
    final caption = data['caption'] as String? ?? '';
    final List<dynamic> likes = data['likes'] ?? [];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isLiked = likes.contains(currentUserId);
    final likeCount = likes.length;

    final avatar = mentorData?['avatarUrl'] as String? ?? '';
    final username = mentorData?['username'] as String? ?? 'Mentor';

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Media Frame
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
            bottom: MediaQuery.of(context).padding.bottom + 80,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: context.textColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: context.textColor,
                    offset: const Offset(6, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url.isNotEmpty)
                    isVideo
                        ? RepaintBoundary(
                            child: Center(
                              child: VideoPlayerBubble(videoUrl: url),
                            ),
                          )
                        : RepaintBoundary(
                            child: GamenectNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.contain,
                              errorWidget: (context, url, error) =>
                                  Container(color: Colors.black),
                            ),
                          )
                  else
                    Container(color: Colors.black),

                  // Dark Gradient Overlay at Bottom (Inside the frame)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 250,
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
                ],
              ),
            ),
          ),

          // Bottom Left Info (Avatar, Name, Caption)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 50,
            left: 32,
            right: 96, // leave space for right action buttons
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mentor Info
                GestureDetector(
                  onTap: () {
                    final mentorId =
                        (widget.doc.data() as Map<String, dynamic>)['mentorId']
                            as String? ??
                        '';
                    if (mentorId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MentorProfileScreen(mentorId: mentorId),
                        ),
                      );
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6E40),
                          border: Border.all(
                            color: context.textColor,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.textColor,
                              offset: const Offset(4, 4),
                            ),
                          ],
                        ),
                        child: avatar.isNotEmpty
                            ? GamenectNetworkImage(
                                imageUrl: avatar,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2979FF,
                          ), // Changed from red to blue
                          border: Border.all(
                            color: context.textColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.textColor,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              username.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Caption
                if (caption.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A32),
                      border: Border.all(color: context.textColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: context.textColor,
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Right Actions (Like Button)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 50,
            right: 32,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    if (currentUserId.isEmpty) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                      return;
                    }
                    FirestoreService().toggleLikeMentorMedia(
                      widget.doc.id,
                      currentUserId,
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isLiked
                              ? const Color(0xFFFF2D55)
                              : const Color(0xFF2A2A32),
                          border: Border.all(
                            color: context.textColor,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.textColor,
                              offset: const Offset(4, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        likeCount > 0 ? likeCount.toString() : 'THÍCH',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 2,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

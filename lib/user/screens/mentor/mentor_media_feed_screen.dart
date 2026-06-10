import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../chat/video_player_bubble.dart';
import '../../../core/services/firestore_service.dart';
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

  List<DocumentSnapshot> get filteredDocs {
    if (_searchQuery.trim().isEmpty) return widget.docs;
    final query = _searchQuery.toLowerCase().trim();
    return widget.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final caption = (data['caption'] as String? ?? '').toLowerCase();
      final mentorId = data['mentorId'] as String? ?? '';
      final mentorName = (MentorMediaFeedScreen.mentorCache[mentorId]?['username'] as String? ?? '').toLowerCase();
      
      return caption.contains(query) || mentorName.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isGridMode ? context.scaffoldBackgroundColor : Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: isGridMode ? context.appBarBgColor : Colors.transparent,
        elevation: 0,
        title: isGridMode ? Text('Bài viết Mentor', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)) : null,
        iconTheme: IconThemeData(
          color: isGridMode ? context.textColor : Colors.white,
          shadows: isGridMode ? null : const [Shadow(color: Colors.black45, blurRadius: 10)],
        ),
        actions: [
          IconButton(
            icon: Icon(isGridMode ? Icons.view_agenda_rounded : Icons.grid_view_rounded, color: isGridMode ? context.textColor : Colors.white),
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
          )
        ],
      ),
      body: Stack(
        children: [
          // Main Content
          isGridMode
              ? GridView.builder(
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                      left: 12,
                      right: 12,
                      bottom: 100), // Extra bottom padding for search bar
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0, // Square grid
                  ),
                  itemCount: docsToDisplay.length,
                  itemBuilder: (context, i) {
                    final data = docsToDisplay[i].data() as Map<String, dynamic>;
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
                        });
                      },
                    );
                  },
                )
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: docsToDisplay.length,
                  itemBuilder: (context, index) {
                    return MentorMediaFeedCard(doc: docsToDisplay[index]);
                  },
                ),

          // Transparent Search Bar
          if (isGridMode)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20 + MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: context.cardBorderColor),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: context.textColor, fontSize: 14),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: 'Tìm kiếm Mentor, bài viết...',
                        hintStyle: TextStyle(color: context.textSecondaryColor),
                        prefixIcon: Icon(Icons.search, color: context.textSecondaryColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: context.textSecondaryColor, size: 18),
                                onPressed: () {
                                  _searchController.clear();
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

class _MentorGridItemState extends State<MentorGridItem> {
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
        if (mounted) setState(() => mentorData = MentorMediaFeedScreen.mentorCache[mentorId]);
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(mentorId).get();
      if (doc.exists && mounted) {
        MentorMediaFeedScreen.mentorCache[mentorId] = doc.data() as Map<String, dynamic>;
        setState(() => mentorData = MentorMediaFeedScreen.mentorCache[mentorId]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.data['type'] == 'video';
    final url = widget.data['url'] as String? ?? '';
    final caption = widget.data['caption'] as String?;
    final avatarUrl = mentorData?['avatarUrl'] as String?;
    final username = mentorData?['username'] as String? ?? 'Mentor';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: isVideo ? (widget.data['thumbnailUrl'] ?? url) : url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.white10),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.white10,
                    child: const Icon(Icons.broken_image, color: Colors.white38),
                  ),
                )
              else
                Container(color: Colors.white10, child: const Icon(Icons.image, color: Colors.white24)),
                
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
                  top: 8, right: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
                
              // User info and caption at the bottom
              Positioned(
                bottom: 10, left: 10, right: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(caption!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500, height: 1.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)]
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.verified, color: Colors.blue, size: 12),
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

class _MentorMediaFeedCardState extends State<MentorMediaFeedCard> {
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
        if (mounted) setState(() => mentorData = MentorMediaFeedScreen.mentorCache[mentorId]);
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(mentorId).get();
      if (doc.exists && mounted) {
        MentorMediaFeedScreen.mentorCache[mentorId] = doc.data() as Map<String, dynamic>;
        setState(() => mentorData = MentorMediaFeedScreen.mentorCache[mentorId]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Media
        if (url.isNotEmpty)
          isVideo
              ? Center(child: VideoPlayerBubble(videoUrl: url))
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Color(0xFFE040FB))),
                  errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                )
        else
          Container(color: Colors.grey[900]),

        // Dark Gradient Overlay at Bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
              ),
            ),
          ),
        ),

        // Bottom Left Info (Avatar, Name, Caption)
        Positioned(
          bottom: 100,
          left: 16,
          right: 80, // leave space for right action buttons
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mentor Info
              GestureDetector(
                onTap: () {
                  final mentorId = (widget.doc.data() as Map<String, dynamic>)['mentorId'] as String? ?? '';
                  if (mentorId.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MentorProfileScreen(mentorId: mentorId),
                      ),
                    );
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      backgroundColor: Colors.deepOrange.withValues(alpha: 0.2),
                      child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      username,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Colors.blue, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Caption
              if (caption.isNotEmpty)
                Text(
                  caption,
                  style: const TextStyle(color: Colors.white, fontSize: 15, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),

        // Bottom Right Actions (Like Button)
        Positioned(
          bottom: 100,
          right: 16,
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (currentUserId.isNotEmpty) {
                    FirestoreService().toggleLikeMentorMedia(widget.doc.id, currentUserId);
                  }
                },
                child: Column(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? Colors.red : Colors.white,
                      size: 38,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 10)],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      likeCount > 0 ? likeCount.toString() : 'Thích',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

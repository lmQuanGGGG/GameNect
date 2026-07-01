import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/network_image.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import '../matching/home_screen.dart';
import '../matching/match_list_screen.dart';
import '../chat/chat_screen.dart';
import '../../../core/models/user_model.dart';
import '../chat/video_player_bubble.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/video_warmup_service.dart';
import 'mentor_profile_screen.dart';
import '../../../core/theme/theme_helper.dart';
import 'package:flutter/gestures.dart';
import '../moments/suggested_mentors_sidebar.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/mentor_provider.dart';
import '../../../core/providers/match_provider.dart';
import '../../../core/providers/chat_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

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

  bool _isChatPopupOpen = false;
  UserModel? _selectedChatUser;
  String? _selectedMatchId;

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

  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final screenWidth = MediaQuery.of(context).size.width;
      final hasSidebar = screenWidth < 1100 && filteredDocs.isNotEmpty;
      final sidebarIndex = filteredDocs.length >= 2 ? 2 : 1;
      
      int initialPage = widget.initialIndex;
      if (hasSidebar && initialPage >= sidebarIndex) {
        initialPage++;
      }
      
      _pageController = PageController(initialPage: initialPage);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markPostSeen(widget.initialIndex, filteredDocs);
        _preloadNextMedia(widget.initialIndex, filteredDocs);
      });
      _isInit = true;
    }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 900 ? (screenWidth - 800) / 2 : 12.0;

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
                    left: horizontalPadding,
                    right: horizontalPadding,
                    bottom: 100,
                  ), // Extra bottom padding for search bar
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: docsToDisplay.length,
                  itemBuilder: (context, i) {
                    final data =
                        docsToDisplay[i].data() as Map<String, dynamic>;
                    return MentorGridItem(
                      data: data,
                      docId: docsToDisplay[i].id,
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isLargeScreen = constraints.maxWidth >= 1000;
                    
                    final hasSidebar = screenWidth < 1100 && docsToDisplay.isNotEmpty;
                    final sidebarIndex = docsToDisplay.length >= 2 ? 2 : 1;
                    final itemCount = docsToDisplay.length + (hasSidebar ? 1 : 0);

                    final pageView = PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      pageSnapping: screenWidth < 900,
                      physics: screenWidth >= 900 ? const BouncingScrollPhysics() : null,
                      itemCount: itemCount,
                      onPageChanged: (index) {
                        if (hasSidebar && index == sidebarIndex) return;
                        
                        int docIndex = index;
                        if (hasSidebar && index > sidebarIndex) docIndex--;
                        
                        _markPostSeen(docIndex, docsToDisplay);
                        _preloadNextMedia(docIndex, docsToDisplay);
                      },
                      itemBuilder: (context, index) {
                        if (hasSidebar && index == sidebarIndex) {
                          return Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: SafeArea(
                              child: Center(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 60, bottom: 24, left: 16, right: 16),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 500),
                                      child: const SuggestedMentorsSidebar(
                                        isHorizontal: false,
                                        showFooter: false,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        
                        int docIndex = index;
                        if (hasSidebar && index > sidebarIndex) docIndex--;
                        
                        return MentorMediaFeedCard(doc: docsToDisplay[docIndex]);
                      },
                    );

                    if (isLargeScreen) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 700),
                            child: pageView,
                          ),
                          if (constraints.maxWidth >= 1100) ...[
                            const SizedBox(width: 40),
                            SizedBox(
                              width: 320,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: MediaQuery.of(context).padding.top +
                                      kToolbarHeight +
                                      16,
                                ),
                                child: const SuggestedMentorsSidebar(),
                              ),
                            ),
                          ],
                        ],
                      );
                    }
                    return pageView;
                  },
                ),

          // Transparent Neo-Brutalism Search Bar
          if (isGridMode)
            Positioned(
              bottom:
                  MediaQuery.of(context).padding.bottom +
                  20 +
                  MediaQuery.of(context).viewInsets.bottom,
              left: screenWidth > 900 ? horizontalPadding : 20,
              right: screenWidth > 900 ? horizontalPadding : 20,
              child: Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 12),
                  _buildMessageFab(),
                ],
              ),
            ),
          if (!isGridMode)
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + 10
                  : MediaQuery.of(context).padding.bottom + 20,
              right: screenWidth > 900 ? horizontalPadding : 20,
              child: _buildMessageFab(),
            ),
          if (_isChatPopupOpen)
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + 60
                  : MediaQuery.of(context).padding.bottom + 80,
              right: screenWidth > 900 ? horizontalPadding : 20,
              width: screenWidth > 600 ? 380 : screenWidth - (screenWidth > 900 ? horizontalPadding * 2 : 40),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.textColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.textColor,
                      offset: const Offset(1.5, 1.5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Column(
                    children: [
                      // Popup Header
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          border: Border(
                            bottom: BorderSide(
                              color: context.textColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tin nhắn',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: context.textColor,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: context.textColor,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _isChatPopupOpen = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      // Popup Content
                      Expanded(
                        child: _selectedChatUser != null && _selectedMatchId != null
                            ? ChatScreen(
                                matchId: _selectedMatchId!,
                                peerUser: _selectedChatUser!,
                                showBackButton: true,
                                isPopup: true,
                                onBack: () {
                                  setState(() {
                                    _selectedChatUser = null;
                                    _selectedMatchId = null;
                                  });
                                },
                              )
                            : MatchListScreen(
                                hideAppBar: true,
                                isSidebarMode: true,
                                onChatSelected: (user, matchId) {
                                  setState(() {
                                    _selectedChatUser = user;
                                    _selectedMatchId = matchId;
                                  });
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageFab() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isChatPopupOpen = !_isChatPopupOpen;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: context.textColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: context.textColor,
              offset: const Offset(1.5, 1.5),
            ),
          ],
        ),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Provider.of<MatchProvider>(context, listen: false)
              .matchedUsersStream(FirebaseAuth.instance.currentUser?.uid ?? ''),
          builder: (context, snapshot) {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
            int unreadCount = 0;
            List<String?> avatarUrls = [];

            if (snapshot.hasData && snapshot.data != null) {
              final matches = snapshot.data!;
              final unreadMatches = matches.where((m) => 
                m['lastMessageRead'] == false && 
                m['lastMessageSenderId'] != currentUserId && 
                m['lastMessageSenderId'] != ''
              ).toList();
              unreadCount = unreadMatches.length;

              if (unreadCount > 0) {
                for (int i = 0; i < unreadMatches.length && i < 3; i++) {
                  final unread = unreadMatches[i];
                  if (unread['user'] != null && unread['user'] is UserModel) {
                    avatarUrls.add((unread['user'] as UserModel).avatarUrl);
                  }
                }
              }
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isChatPopupOpen)
                  Icon(
                    Icons.close_rounded,
                    color: context.textColor,
                    size: 24,
                  )
                else if (unreadCount > 0)
                  SizedBox(
                    width: 24.0 + (avatarUrls.length > 1 ? (avatarUrls.length - 1) * 14.0 : 0),
                    height: 24,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (int i = avatarUrls.length - 1; i >= 0; i--)
                          Positioned(
                            left: i * 14.0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                              ),
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                backgroundImage: avatarUrls[i] != null ? NetworkImage(avatarUrls[i]!) : null,
                                child: avatarUrls[i] == null 
                                    ? Icon(Icons.person, size: 14, color: context.textColor)
                                    : null,
                              ),
                            ),
                          ),
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6E40),
                              shape: BoxShape.circle,
                              border: Border.all(color: context.textColor, width: 1.5),
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Icon(
                    Icons.send_rounded,
                    color: context.textColor,
                    size: 24,
                  ),
                const SizedBox(width: 8),
                Text(
                  _isChatPopupOpen ? 'Đóng' : 'Tin nhắn',
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MentorGridItem extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final String docId;

  const MentorGridItem({super.key, required this.data, required this.docId, required this.onTap});

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
                                                  offset: Offset(1.5, 1.5),
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
  Widget build(BuildContext context) {
    super.build(context);
    final isVideo = widget.data['type'] == 'video';
    final url = widget.data['url'] as String? ?? '';
    final avatarUrl = mentorData?['avatarUrl'] as String?;
    final username = mentorData?['username'] as String? ?? 'Mentor';
    final likes = List<String>.from(widget.data['likes'] as List? ?? const []);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isLiked = likes.contains(currentUserId);
    final thumbnailUrl = widget.data['thumbnailUrl'] as String? ?? '';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background
              ColoredBox(
                color: isVideo ? Colors.black : const Color(0xFFF4F4F4),
                child: (url.isNotEmpty)
                    ? ((isVideo && thumbnailUrl.isEmpty)
                        ? Container(
                            color: Colors.black12,
                            child: const Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 36,
                            ),
                          )
                        : GamenectNetworkImage(
                            imageUrl: isVideo ? thumbnailUrl : url,
                            fit: BoxFit.cover,
                          ))
                    : Container(
                        color: Colors.black12,
                        child: const Icon(Icons.photo, color: Colors.black26),
                      ),
              ),

              // Bottom solid bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.black, width: 1.5),
                    ),
                  ),
                ),
              ),

              // Bottom bar content (Avatar + name + share button)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF00E676),
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? ClipOval(
                                child: GamenectNetworkImage(
                                  imageUrl: avatarUrl,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                username.isNotEmpty ? username[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Share button
                    GestureDetector(
                      onTap: () {
                        _showShareBottomSheet(
                          context,
                          widget.docId,
                          isVideo && thumbnailUrl.isNotEmpty ? thumbnailUrl : url,
                          isVideo,
                          username,
                          widget.data['mentorId'] as String? ?? '',
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.share_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Heart/Likes badge at top right
              if (likes.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      if (currentUserId.isEmpty) return;
                      FirestoreService().toggleLikeMentorMedia(widget.docId, currentUserId);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isLiked ? Colors.red : Colors.black,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${likes.length}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else 
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      if (currentUserId.isEmpty) return;
                      FirestoreService().toggleLikeMentorMedia(widget.docId, currentUserId);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                        ],
                      ),
                      child: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? Colors.red : Colors.black,
                        size: 14,
                      ),
                    ),
                  ),
                ),

              // Video duration (if video) at top left
              if (isVideo && widget.data['duration'] != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55),
                      border: Border.all(color: Colors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.data['duration']}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
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
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final data = widget.doc.data() as Map<String, dynamic>;
    final mentorId = data['mentorId'] as String? ?? '';
    
    if (currentUserId == null || mentorId.isEmpty) return;

    try {
      final mentorProvider = context.read<MentorProvider>();
      final isFollowing = await mentorProvider.checkIsFollowing(mentorId, currentUserId);
      if (mounted) {
        setState(() => _isFollowing = isFollowing);
      }
    } catch (e) {
      // Ignored
    }
  }

  bool _isFollowing = false;
  bool _isLoadingFollow = false;

  Future<void> _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    
    final data = widget.doc.data() as Map<String, dynamic>;
    final mentorId = data['mentorId'] as String? ?? '';
    if (mentorId == currentUserId || mentorId.isEmpty) return;

    if (_isLoadingFollow) return;
    setState(() => _isLoadingFollow = true);

    try {
      final mentorProvider = context.read<MentorProvider>();
      final newFollowState = !_isFollowing;
      setState(() => _isFollowing = newFollowState);

      if (newFollowState) {
        await mentorProvider.followMentor(mentorId, currentUserId);
      } else {
        await mentorProvider.unfollowMentor(mentorId, currentUserId);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollow = false);
      }
    }
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
                                                  offset: Offset(1.5, 1.5),
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

    final mentorId = data['mentorId'] as String? ?? '';

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
        left: 16,
        right: 16,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Info (Avatar, Name, Follow)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
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
                      child: Container(
                        width: 46,
                        height: 46,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6E40),
                          border: Border.all(
                            color: context.textColor,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.textColor,
                              offset: const Offset(1.5, 1.5),
                            ),
                          ],
                        ),
                        child: avatar.isNotEmpty
                            ? GamenectNetworkImage(
                                imageUrl: avatar,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
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
                        child: Text(
                          username.toUpperCase(),
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (mentorId.isNotEmpty && mentorId != currentUserId)
                      GestureDetector(
                        onTap: _toggleFollow,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isFollowing ? context.scaffoldBackgroundColor : const Color(0xFF2979FF),
                            border: Border.all(
                              color: context.textColor,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.textColor,
                                offset: const Offset(1.5, 1.5),
                              ),
                            ],
                          ),
                          child: _isLoadingFollow 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(
                                _isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                                style: TextStyle(
                                  color: _isFollowing ? context.textColor : Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Background Media Frame
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: context.textColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: context.textColor,
                        offset: const Offset(1.5, 1.5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: url.isNotEmpty
                      ? (isVideo
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
                            ))
                      : Container(color: Colors.black),
                ),
              ),
            ),
            
            // Bottom Actions & Caption
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action Buttons (Like, Share)
                    Row(
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
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isLiked
                                  ? const Color(0xFFFF2D55)
                                  : (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white),
                              border: Border.all(
                                color: context.textColor,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.textColor,
                                  offset: const Offset(1.5, 1.5),
                                ),
                              ],
                            ),
                            child: Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isLiked ? Colors.white : context.textColor,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final data = widget.doc.data() as Map<String, dynamic>;
                            final isVideo = data['type'] == 'video';
                            final url = data['url'] as String? ?? '';
                            final thumbnailUrl = data['thumbnailUrl'] as String? ?? '';
                            final previewUrl = isVideo && thumbnailUrl.isNotEmpty ? thumbnailUrl : url;
                            final username = mentorData?['username'] as String? ?? 'Mentor';
                            
                            _showShareBottomSheet(
                              context,
                              widget.doc.id,
                              previewUrl,
                              isVideo,
                              username,
                              data['mentorId'] as String? ?? '',
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                              border: Border.all(
                                color: context.textColor,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.textColor,
                                  offset: const Offset(1.5, 1.5),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.share_outlined,
                              color: context.textColor,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (likeCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '$likeCount lượt thích',
                          style: TextStyle(
                            color: context.textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$username ',
                              style: TextStyle(
                                color: context.textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            TextSpan(
                              text: caption,
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

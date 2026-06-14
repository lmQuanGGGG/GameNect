// lib/user/screens/live_discover_screen.dart

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/providers/livestream_provider.dart';
import '../../../core/providers/mentor_provider.dart';
import '../../../core/models/livestream_model.dart';
import '../../../core/widgets/network_image.dart';
import 'live_swipe_feed_screen.dart';

const Color _kLiveRed = Color(0xFFFF2D55);
const Color _kAccent = Color(0xFFFF6E40);
const Color _kDarkBg = Color(0xFF121214);
const Color _kLightBg = Color(0xFFF4F4F0);
const Color _kDarkCard = Color(0xFF2A2A32);
const Color _kLightCard = Colors.white;

const List<String> _kGames = ['Tất cả', 'Valorant', 'LMHT', 'PUBG', 'CS:GO', 'TFT'];

class LiveDiscoverScreen extends StatefulWidget {
  final bool embedMode;
  const LiveDiscoverScreen({super.key, this.embedMode = false});

  @override
  State<LiveDiscoverScreen> createState() => _LiveDiscoverScreenState();
}

class _LiveDiscoverScreenState extends State<LiveDiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedGame = 'Tất cả';
  int _selectedSortIndex = 0; // 0: Top Mentor, 1: Mới nhất
  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final game = _selectedGame == 'Tất cả' ? null : _selectedGame;
    context.read<LivestreamProvider>().listenToLiveStreams(gameFilter: game);
    context.read<MentorProvider>().loadApprovedMentors(gameFilter: game);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Header Khám Phá ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor, width: 3),
                    boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(3, 3))],
                  ),
                  child: Icon(Icons.close_rounded, color: textColor, size: 22),
                ),
              ),
              Text(
                'KHÁM PHÁ',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _showSearch ? textColor : _kLiveRed,
                    border: Border.all(color: borderColor, width: 3),
                    boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(3, 3))],
                  ),
                  child: Icon(
                    CupertinoIcons.search,
                    color: _showSearch ? (isDark ? Colors.black : Colors.white) : Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          if (_showSearch) ...[  
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border.all(color: borderColor, width: 3),
                      boxShadow: const [BoxShadow(color: _kAccent, offset: Offset(4, 4))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm stream, mentor...',
                        hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontWeight: FontWeight.w600),
                        prefixIcon: const Icon(CupertinoIcons.search, color: _kAccent, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cardColor,
                        border: Border.all(color: borderColor, width: 3),
                        boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(3, 3))],
                      ),
                      child: Icon(Icons.close_rounded, color: textColor, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Main Tab Switch ─────────────────────────────────────────────────────────
  Widget _buildMainTabSwitch() {
    final isLiveActive = _tabController.index == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final inactiveTextColor = isDark ? Colors.white : Colors.black;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _tabController.animateTo(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isLiveActive ? _kLiveRed : cardColor,
                  border: Border.all(color: borderColor, width: 3),
                  boxShadow: isLiveActive ? [BoxShadow(color: shadowColor, offset: const Offset(4, 4))] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLiveActive) ...[
                      const _BlinkingDot(size: 8, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      'ĐANG LIVE',
                      style: TextStyle(
                        color: isLiveActive ? Colors.white : inactiveTextColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => _tabController.animateTo(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isLiveActive ? _kAccent : cardColor,
                  border: Border.all(color: borderColor, width: 3),
                  boxShadow: !isLiveActive ? [BoxShadow(color: shadowColor, offset: const Offset(4, 4))] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '★ MENTOR',
                      style: TextStyle(
                        color: !isLiveActive ? Colors.black : inactiveTextColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
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

  // ── Game filter chips ───────────────────────────────────────────────────────
  Widget _buildGameFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kGames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final game = _kGames[i];
          final selected = _selectedGame == game;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedGame = game);
              _loadData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _kAccent : cardColor,
                border: Border.all(color: borderColor, width: selected ? 3 : 2),
                boxShadow: selected ? [BoxShadow(color: shadowColor, offset: const Offset(3, 3))] : [BoxShadow(color: shadowColor, offset: const Offset(2, 2))],
              ),
              child: Text(
                game.toUpperCase(),
                style: TextStyle(
                  color: selected ? Colors.black : textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tab: Live ──────────────────────────────────────────────────────────────
  Widget _buildLiveTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<LivestreamProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: _kAccent));
        }
        
        final filteredStreams = _searchQuery.isEmpty
            ? provider.liveStreams
            : provider.liveStreams.where((s) =>
                s.title.toLowerCase().contains(_searchQuery) ||
                s.mentorUsername.toLowerCase().contains(_searchQuery) ||
                s.game.toLowerCase().contains(_searchQuery)).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: const Text(
                  'ĐANG PHÁT SÓNG',
                  style: TextStyle(
                    color: _kLiveRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            if (filteredStreams.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.live_tv_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 60),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Không có stream nào đang live'
                            : 'Không tìm thấy stream nào',
                        style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildStreamCard(filteredStreams[i]),
                    childCount: filteredStreams.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStreamCard(LivestreamModel stream) {
    final allStreams = context.read<LivestreamProvider>().liveStreams;
    final index = allStreams.indexWhere((s) => s.id == stream.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final borderColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;
    final infoBgColor = isDark ? const Color(0xFF121214) : _kLightBg;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LiveSwipeFeedScreen(
            streams: allStreams.toList(),
            initialIndex: index < 0 ? 0 : index,
          ),
          transitionsBuilder: (_, animation, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 380),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor, width: 3),
          boxShadow: const [BoxShadow(color: _kLiveRed, offset: Offset(4, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor, width: 3)),
                      color: Colors.black,
                    ),
                    child: stream.mentorAvatarUrl.isNotEmpty
                        ? GamenectNetworkImage(
                            imageUrl: stream.mentorAvatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.videocam_rounded, color: Colors.white24, size: 40),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.videocam_rounded, color: Colors.white24, size: 40),
                          ),
                  ),
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kLiveRed,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                      ),
                      child: Text(
                        '👁 ${stream.viewerCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info section
            Container(
              padding: const EdgeInsets.all(12),
              color: infoBgColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.title.toUpperCase(),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${stream.mentorUsername}'.toUpperCase(),
                    style: const TextStyle(
                      color: _kAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [BoxShadow(color: _kAccent, offset: Offset(2, 2))],
                    ),
                    child: Text(
                      stream.game.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Mentor ──────────────────────────────────────────────────────────────
  Widget _buildMentorTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<MentorProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: _kAccent));
        }
        
        final liveStreams = context.watch<LivestreamProvider>().liveStreams;
        final liveMentorIds = liveStreams.map((s) => s.mentorId).toSet();
        final sorted = [...provider.approvedMentors];
        sorted.sort((a, b) {
          final aLive = liveMentorIds.contains(a['userId']) ? 0 : 1;
          final bLive = liveMentorIds.contains(b['userId']) ? 0 : 1;
          if (aLive != bLive) return aLive.compareTo(bLive);

          if (_selectedSortIndex == 0) {
            final aRating = (a['rating'] as num? ?? 0.0).toDouble();
            final bRating = (b['rating'] as num? ?? 0.0).toDouble();
            if (bRating != aRating) return bRating.compareTo(aRating);
            
            final aF = a['followerCount'] as int? ?? 0;
            final bF = b['followerCount'] as int? ?? 0;
            if (bF != aF) return bF.compareTo(aF);

            final aTs = a['approvedAt'] as Timestamp? ?? a['appliedAt'] as Timestamp?;
            final bTs = b['approvedAt'] as Timestamp? ?? b['appliedAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          } else {
            final aTs = a['approvedAt'] as Timestamp? ?? a['appliedAt'] as Timestamp?;
            final bTs = b['approvedAt'] as Timestamp? ?? b['appliedAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          }
        });

        final filteredMentors = _searchQuery.isEmpty
            ? sorted
            : sorted.where((m) {
                final name = (m['displayName'] as String? ?? '').toLowerCase();
                final username = (m['username'] as String? ?? '').toLowerCase();
                final games = ((m['games'] as List?)?.join(' ') ?? '').toLowerCase();
                return name.contains(_searchQuery) ||
                    username.contains(_searchQuery) ||
                    games.contains(_searchQuery);
              }).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: isDark ? Colors.white : Colors.black, width: 4))
                      ),
                      padding: const EdgeInsets.only(bottom: 4),
                      child: const Text(
                        'TOP MENTOR',
                        style: TextStyle(
                          color: _kAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    DropdownButton<int>(
                      value: _selectedSortIndex,
                      dropdownColor: isDark ? _kDarkBg : _kLightBg,
                      icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white54 : Colors.black54),
                      underline: const SizedBox(),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('TOP MENTOR')),
                        DropdownMenuItem(value: 1, child: Text('MỚI NHẤT')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSortIndex = val);
                      },
                    )
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _DiscoverMentorCard(mentor: filteredMentors[i], rank: i + 1),
                  ),
                  childCount: filteredMentors.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _kDarkBg : _kLightBg,
      floatingActionButton: Consumer<MentorProvider>(
        builder: (context, mentorProvider, _) {
          if (mentorProvider.isMentor) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FloatingActionButton(
                onPressed: () => Navigator.pushNamed(context, '/go-live'),
                backgroundColor: _kLiveRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: isDark ? Colors.white : Colors.black, width: 3),
                ),
                child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 28),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildMainTabSwitch(),
          const SizedBox(height: 24),
          _buildGameFilter(),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildLiveTab(), _buildMentorTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final double size;
  final Color color;
  const _BlinkingDot({this.size = 8, this.color = const Color(0xFFFF3B30)});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _controller.value,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _DiscoverMentorCard extends StatefulWidget {
  final Map<String, dynamic> mentor;
  final int rank;
  const _DiscoverMentorCard({required this.mentor, required this.rank});

  @override
  State<_DiscoverMentorCard> createState() => _DiscoverMentorCardState();
}

class _DiscoverMentorCardState extends State<_DiscoverMentorCard> {
  bool _isFollowing = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkFollow();
  }

  Future<void> _checkFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId == widget.mentor['userId']) {
      if (mounted) setState(() => _isChecking = false);
      return;
    }
    final isFollowing = await context.read<MentorProvider>().checkIsFollowing(
          widget.mentor['userId'] ?? '',
          currentUserId,
        );
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final borderColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    final mentor = widget.mentor;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = mentor['userId'] == currentUserId;
    final bio = mentor['bio']?.toString() ?? '';
    final rating = (mentor['rating'] as num? ?? 0.0).toDouble();
    final followerCount = mentor['followerCount'] as int? ?? 0;
    final liveStreams = context.watch<LivestreamProvider>().liveStreams;
    final activeStream = liveStreams
        .where((s) => s.mentorId == mentor['userId'])
        .firstOrNull;
    final isLive = activeStream != null;
    final liveStreamId = activeStream?.id;
    final rank = widget.rank;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/mentor-profile',
        arguments: {'mentorId': mentor['userId'] ?? ''},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, top: 12, left: 12, right: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor, width: 3),
          boxShadow: const [BoxShadow(color: _kAccent, offset: Offset(4, 4), blurRadius: 0)],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // #1 Badge
            Positioned(
              top: -28, 
              left: -28,
              child: Container(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: _kAccent,
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar Area
                GestureDetector(
                  onTap: isLive && liveStreamId != null
                      ? () {
                          final allStreams = context.read<LivestreamProvider>().liveStreams;
                          final index = allStreams.indexWhere((s) => s.id == liveStreamId);
                          if (index >= 0) {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => LiveSwipeFeedScreen(
                                  streams: allStreams.toList(),
                                  initialIndex: index,
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          border: Border.all(color: borderColor, width: 3),
                          boxShadow: [BoxShadow(color: isDark ? Colors.white : Colors.black, offset: const Offset(4, 4))],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: (mentor['avatarUrl'] as String?)?.isNotEmpty == true
                            ? GamenectNetworkImage(
                                imageUrl: mentor['avatarUrl']!,
                                fit: BoxFit.cover,
                              )
                            : Icon(Icons.person, color: isDark ? Colors.white54 : Colors.black54, size: 32),
                      ),
                      if (isLive)
                        Positioned(
                          bottom: -8,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kLiveRed,
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (mentor['username'] ?? 'Mentor').toString().toUpperCase(),
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 16, height: 1.1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.blue, size: 16),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '★ ${rating.toStringAsFixed(1)} • $followerCount FAN',
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '"$bio"',
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 10, fontStyle: FontStyle.italic, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Action Button (Follow)
                if (!isSelf)
                  GestureDetector(
                    onTap: () async {
                      if (_isChecking || currentUserId == null) return;
                      final mentorProvider = context.read<MentorProvider>();
                      setState(() => _isFollowing = !_isFollowing);
                      if (_isFollowing) {
                        await mentorProvider.followMentor(mentor['userId'], currentUserId);
                      } else {
                        await mentorProvider.unfollowMentor(mentor['userId'], currentUserId);
                      }
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isFollowing ? cardColor : textColor,
                        border: Border.all(color: _isFollowing ? borderColor : _kAccent, width: 3),
                        boxShadow: const [BoxShadow(color: _kAccent, offset: Offset(3, 3))],
                      ),
                      alignment: Alignment.center,
                      child: _isChecking
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2))
                          : Icon(
                              _isFollowing ? Icons.check : Icons.person_add,
                              color: _isFollowing ? textColor : cardColor,
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
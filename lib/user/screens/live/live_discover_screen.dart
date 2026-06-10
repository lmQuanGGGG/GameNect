// lib/user/screens/live_discover_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/livestream_provider.dart';
import '../../../core/providers/mentor_provider.dart';
import '../../../core/models/livestream_model.dart';
import '../../../core/theme/theme_helper.dart';
import 'live_swipe_feed_screen.dart';

const _kAccent = Color(0xFFFF6E40);
const _kLiveRed = Color(0xFFFF2D55);

final _kGames = [
  'Tất cả',
  'LMHT',
  'Valorant',
  'PUBG',
  'CS:GO',
  'Free Fire',
  'Mobile Legends',
];

// ─────────────────────────────────────────────────────────────────────────────
/// Blinking dot widget for LIVE indicator
// ─────────────────────────────────────────────────────────────────────────────
class _BlinkingDot extends StatefulWidget {
  final double size;
  final Color color;
  const _BlinkingDot({this.size = 7, this.color = _kLiveRed});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _anim.value * 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Pulsing ring around live avatar
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingLiveRing extends StatefulWidget {
  final Widget child;
  const _PulsingLiveRing({required this.child});

  @override
  State<_PulsingLiveRing> createState() => _PulsingLiveRingState();
}

class _PulsingLiveRingState extends State<_PulsingLiveRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _kLiveRed.withValues(alpha: _opacity.value),
                  width: 2.5,
                ),
              ),
            ),
          ),
          child!,
        ],
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
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
    super.dispose();
  }

  // ── Sliding tab switch ──────────────────────────────────────────────────────
  Widget _buildMainTabSwitch() {
    final isDark = context.isDarkMode;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / 2;
          return Stack(
            children: [
              // Sliding pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                left: _tabController.index * width,
                top: 0, bottom: 0, width: width,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6E40), Color(0xFFFF2D55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6E40).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels
              Row(
                children: [
                  // Tab 0 – Live
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(0),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _BlinkingDot(),
                            const SizedBox(width: 7),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: TextStyle(
                                color: _tabController.index == 0
                                    ? Colors.white
                                    : (isDark ? Colors.white54 : Colors.black45),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              child: const Text('Đang Live'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Tab 1 – Mentor
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(1),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: _tabController.index == 1
                                  ? Colors.white
                                  : (isDark ? Colors.white54 : Colors.black45),
                            ),
                            const SizedBox(width: 5),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: TextStyle(
                                color: _tabController.index == 1
                                    ? Colors.white
                                    : (isDark ? Colors.white54 : Colors.black45),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              child: const Text('Mentor'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Mini sliding switch (sort) ───────────────────────────────────────────────
  Widget _buildSlidingSwitch({
    required int selectedIndex,
    required List<String> options,
    required ValueChanged<int> onChange,
  }) {
    final isDark = context.isDarkMode;
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                left: selectedIndex * width,
                top: 0, bottom: 0, width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: _kAccent,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(options.length, (index) {
                  final isSelected = selectedIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChange(index),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white54 : Colors.black54),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          child: Text(options[index]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Game filter chips ────────────────────────────────────────────────────────
  Widget _buildGameFilter() {
    final isDark = context.isDarkMode;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kGames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final game = _kGames[i];
          final selected = _selectedGame == game;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedGame = game);
              _loadData();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6E40), Color(0xFFFF8A65)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: selected
                    ? null
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08)),
                  width: 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _kAccent.withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                game,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tab: Live ────────────────────────────────────────────────────────────────
  Widget _buildLiveTab() {
    final isDark = context.isDarkMode;
    return Consumer<LivestreamProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: _kAccent));
        }
        if (provider.liveStreams.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.live_tv_rounded,
                  size: 72,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 14),
                Text(
                  'Không có stream nào đang live',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: provider.liveStreams.length,
          itemBuilder: (context, i) =>
              _buildStreamCard(provider.liveStreams[i]),
        );
      },
    );
  }

  Widget _buildStreamCard(LivestreamModel stream) {
    final isDark = context.isDarkMode;
    final allStreams = context.read<LivestreamProvider>().liveStreams;
    final index = allStreams.indexWhere((s) => s.id == stream.id);

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
          borderRadius: BorderRadius.circular(18),
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: isDark
                ? _kLiveRed.withValues(alpha: 0.25)
                : _kLiveRed.withValues(alpha: 0.20),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? _kLiveRed.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail area
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image or gradient placeholder
                    stream.mentorAvatarUrl.isNotEmpty
                        ? Image.network(
                            stream.mentorAvatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _streamPlaceholder(),
                          )
                        : _streamPlaceholder(),
                    // Bottom gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // LIVE badge top-left
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kLiveRed,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: _kLiveRed.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BlinkingDot(size: 5, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Viewer count top-right
                    Positioned(
                      top: 8, right: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: BackdropFilter(
                          filter:
                              ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            color: Colors.black.withValues(alpha: 0.45),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.remove_red_eye_rounded,
                                  color: Colors.white70,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${stream.viewerCount}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Info section
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stream.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stream.mentorUsername,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : Colors.black54,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _kAccent.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        stream.game,
                        style: const TextStyle(
                          color: _kAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _streamPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B2E), Color(0xFF2D1B2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.videocam_rounded, color: Colors.white24, size: 40),
      ),
    );
  }

  // ── Tab: Mentor ──────────────────────────────────────────────────────────────
  Widget _buildMentorTab() {
    final isDark = context.isDarkMode;
    return Consumer<MentorProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: _kAccent));
        }
        if (provider.approvedMentors.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 72,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 14),
                Text(
                  'Chưa có Mentor nào',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        // Realtime Livestreams for sorting
        final liveStreams = context.watch<LivestreamProvider>().liveStreams;
        final liveMentorIds = liveStreams.map((s) => s.mentorId).toSet();

        // Sort: live first, then by selected index
        final sorted = [...provider.approvedMentors];
        sorted.sort((a, b) {
          // Live mentors always float to top using realtime data
          final aLive = liveMentorIds.contains(a['userId']) ? 0 : 1;
          final bLive = liveMentorIds.contains(b['userId']) ? 0 : 1;
          if (aLive != bLive) return aLive.compareTo(bLive);

          if (_selectedSortIndex == 0) {
            // Top Mentor: rating desc → followers desc → approvedAt desc
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
            // Mới nhất: approvedAt desc
            final aTs = a['approvedAt'] as Timestamp? ?? a['appliedAt'] as Timestamp?;
            final bTs = b['approvedAt'] as Timestamp? ?? b['appliedAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          }
        });

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: _buildSlidingSwitch(
                selectedIndex: _selectedSortIndex,
                options: const ['🏆  Top Mentor', '🆕  Mới nhất'],
                onChange: (val) => setState(() => _selectedSortIndex = val),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: sorted.length,
                itemBuilder: (context, i) =>
                    _DiscoverMentorCard(mentor: sorted[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bgColor = context.scaffoldBackgroundColor;

    if (widget.embedMode) {
      final topPadding = MediaQuery.of(context).padding.top + 120;
      return Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: _buildMainTabSwitch(),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildGameFilter(),
            ),
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

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient glow orbs (theme-aware opacity)
          Positioned(
            top: -80, left: -60,
            child: _GlowOrb(
              color: _kAccent.withValues(
                  alpha: isDark ? 0.12 : 0.07),
              size: 280,
            ),
          ),
          Positioned(
            top: 200, right: -80,
            child: _GlowOrb(
              color: _kLiveRed.withValues(
                  alpha: isDark ? 0.10 : 0.06),
              size: 220,
            ),
          ),
          // Main content
          NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                title: Text(
                  'Khám phá',
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(62),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _buildMainTabSwitch(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: _buildGameFilter(),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [_buildLiveTab(), _buildMentorTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Ambient glow orb
// ─────────────────────────────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: size)],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Mentor card in discover list
// ─────────────────────────────────────────────────────────────────────────────
class _DiscoverMentorCard extends StatefulWidget {
  final Map<String, dynamic> mentor;
  const _DiscoverMentorCard({required this.mentor});

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
    if (currentUserId == null ||
        currentUserId == widget.mentor['userId']) {
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
    final mentor = widget.mentor;
    final isDark = context.isDarkMode;
    final games = List<String>.from(mentor['games'] ?? []);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = mentor['userId'] == currentUserId;
    final bio = mentor['bio']?.toString() ?? '';
    final rating = (mentor['rating'] as num? ?? 0.0).toDouble();
    final followerCount = mentor['followerCount'] as int? ?? 0;
    // ── Realtime Livestream Check ──
    final liveStreams = context.watch<LivestreamProvider>().liveStreams;
    final activeStream = liveStreams.where((s) => s.mentorId == mentor['userId']).firstOrNull;
    final isLive = activeStream != null;
    final liveStreamId = activeStream?.id;
    final isTopRated = rating >= 4.8;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/mentor-profile',
        arguments: {'mentorId': mentor['userId'] ?? ''},
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isDark
                ? (isLive
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.04))
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLive
                  ? _kLiveRed.withValues(alpha: isDark ? 0.45 : 0.35)
                  : (isTopRated
                      ? Colors.amber.withValues(alpha: 0.35)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.09)
                          : Colors.black.withValues(alpha: 0.07))),
              width: isLive ? 1.5 : 1.0,
            ),
            boxShadow: isLive
                ? [
                    BoxShadow(
                      color: _kLiveRed.withValues(
                          alpha: isDark ? 0.12 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with live ring
                GestureDetector(
                  onTap: isLive && liveStreamId != null
                      ? () => Navigator.pushNamed(
                            context,
                            '/live-stream',
                            arguments: {
                              'streamId': liveStreamId,
                              'isMentor': false,
                            },
                          )
                      : null,
                  child: isLive
                      ? _PulsingLiveRing(child: _buildAvatar(mentor, isLive, isTopRated))
                      : _buildAvatar(mentor, isLive, isTopRated),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username + badge row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              mentor['username'] ?? 'Mentor',
                              style: TextStyle(
                                color: context.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kLiveRed,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kLiveRed.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _BlinkingDot(size: 5, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isTopRated)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.35)),
                              ),
                              child: const Text(
                                '⭐ Top',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: _kAccent.withValues(alpha: 0.25)),
                              ),
                              child: const Text(
                                'Mentor',
                                style: TextStyle(
                                  color: _kAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          '"$bio"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textTertiaryColor,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (games.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: games.take(2).map((g) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _kAccent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _kAccent.withValues(alpha: 0.22),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                g,
                                style: const TextStyle(
                                  color: _kAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Stats row
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 15),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.people_alt_rounded,
                              color: context.textTertiaryColor, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            _formatCount(followerCount),
                            style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Follow button
                if (!isSelf)
                  Align(
                    alignment: Alignment.center,
                    child: _isChecking
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: _kAccent,
                              strokeWidth: 1.5,
                              backgroundColor: Colors.transparent,
                            ),
                          )
                        : _buildFollowButton(context, mentor, currentUserId),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
      Map<String, dynamic> mentor, bool isLive, bool isTopRated) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isLive
                  ? _kLiveRed
                  : (isTopRated
                      ? Colors.amber
                      : _kAccent.withValues(alpha: 0.55)),
              width: 2.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: (mentor['avatarUrl'] as String?)?.isNotEmpty == true
                  ? Image.network(
                      mentor['avatarUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1E1B2E),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white38,
                          size: 28,
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF1E1B2E),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white38,
                        size: 28,
                      ),
                    ),
            ),
          ),
        ),
        // Live / top-rated indicator at bottom
        if (isLive)
          Positioned(
            bottom: -3,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: _kLiveRed,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: context.scaffoldBackgroundColor,
                    width: 1,
                  ),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          )
        else if (isTopRated)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Colors.black,
                size: 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFollowButton(
      BuildContext context, Map<String, dynamic> mentor, String? currentUserId) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing
              ? Colors.transparent
              : _kAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: _isFollowing
              ? BorderSide(
                  color: context.isDarkMode
                      ? Colors.white24
                      : Colors.black26,
                )
              : null,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () async {
          if (currentUserId == null) return;
          final mentorProvider = context.read<MentorProvider>();
          setState(() => _isFollowing = !_isFollowing);
          if (_isFollowing) {
            await mentorProvider.followMentor(
                mentor['userId'], currentUserId);
          } else {
            await mentorProvider.unfollowMentor(
                mentor['userId'], currentUserId);
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _isFollowing
              ? [
                  const Icon(Icons.check_rounded,
                      color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Đã theo dõi',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.isDarkMode
                          ? Colors.white60
                          : Colors.black54,
                    ),
                  ),
                ]
              : const [
                  Icon(Icons.add_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 3),
                  Text(
                    'Theo dõi',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return '$count';
  }
}

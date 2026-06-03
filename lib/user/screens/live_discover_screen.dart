// lib/user/screens/live_discover_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/livestream_provider.dart';
import '../../core/providers/mentor_provider.dart';
import '../../core/models/livestream_model.dart';

const _kBg = Color(0xFF101012);
const _kAccent = Color(0xFFFF6E40);
const _kLiveBadge = Color(0xFFFF3B30);
const _kGlassBg = Color(0x14FFFFFF);
const _kGlassBorder = Color(0x1FFFFFFF);

final _kGames = ['Tất cả', 'LMHT', 'Valorant', 'PUBG', 'CS:GO', 'Free Fire', 'Mobile Legends'];

/// Màn hình Discover — tab Live & Mentor — Task 6.1
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  Widget _buildGlassContainer({required Widget child, double radius = 20}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _kGlassBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _kGlassBorder, width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGameFilter() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kGames.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
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
                color: selected ? _kAccent : _kGlassBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _kAccent : _kGlassBorder,
                  width: 1.2,
                ),
              ),
              child: Text(
                game,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tab Live ──────────────────────────────────────────────────────────────
  Widget _buildLiveTab() {
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
                Icon(Icons.live_tv_rounded, size: 72, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text(
                  'Không có stream nào đang live',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15),
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
          itemBuilder: (context, i) => _buildStreamCard(provider.liveStreams[i]),
        );
      },
    );
  }

  Widget _buildStreamCard(LivestreamModel stream) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context, '/live-stream',
        arguments: {'streamId': stream.id, 'isMentor': false},
      ),
      child: _buildGlassContainer(
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        colors: [
                          _kAccent.withValues(alpha: 0.3),
                          const Color(0xFF1A1A1E),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: stream.mentorAvatarUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.network(
                              stream.mentorAvatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => const Icon(Icons.videocam, color: Colors.white30, size: 40),
                            ),
                          )
                        : const Center(child: Icon(Icons.videocam, color: Colors.white30, size: 40)),
                  ),
                  // LIVE badge
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kLiveBadge,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 6),
                          SizedBox(width: 4),
                          Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  // Viewer count
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye, color: Colors.white70, size: 11),
                          const SizedBox(width: 3),
                          Text('${stream.viewerCount}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stream.mentorUsername,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(stream.game, style: const TextStyle(color: _kAccent, fontSize: 10)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Mentor ─────────────────────────────────────────────────────────────
  Widget _buildMentorTab() {
    return Consumer<MentorProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: _kAccent));
        }
        if (provider.approvedMentors.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_rounded, size: 72, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text(
                  'Chưa có Mentor nào',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: provider.approvedMentors.length,
          itemBuilder: (context, i) => _buildMentorCard(provider.approvedMentors[i]),
        );
      },
    );
  }

  Widget _buildMentorCard(Map<String, dynamic> mentor) {
    final games = List<String>.from(mentor['games'] ?? []);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context, '/mentor-profile',
        arguments: {'mentorId': mentor['userId'] ?? ''},
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildGlassContainer(
          radius: 16,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kAccent.withValues(alpha: 0.5), width: 2),
                    image: (mentor['avatarUrl'] as String?)?.isNotEmpty == true
                        ? DecorationImage(
                            image: NetworkImage(mentor['avatarUrl']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (mentor['avatarUrl'] as String?)?.isNotEmpty != true
                      ? const Icon(Icons.person, color: Colors.white38, size: 28)
                      : null,
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            mentor['username'] ?? 'Mentor',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('⭐ Mentor', style: TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (games.isNotEmpty)
                        Text(
                          games.take(3).join(' • '),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            (mentor['rating'] as num? ?? 0).toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.people_rounded, color: Colors.white.withValues(alpha: 0.4), size: 14),
                          const SizedBox(width: 3),
                          Text(
                            '${mentor['followerCount'] ?? 0}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedMode) {
      final topPadding = MediaQuery.of(context).padding.top + 120;
      return Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: _buildGameFilter(),
            ),
            TabBar(
              controller: _tabController,
              labelColor: _kAccent,
              unselectedLabelColor: Colors.white54,
              indicatorColor: _kAccent,
              indicatorWeight: 2.5,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: _kLiveBadge, size: 8),
                      SizedBox(width: 6),
                      Text('Đang Live', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 16),
                      SizedBox(width: 4),
                      Text('Mentor', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLiveTab(),
                  _buildMentorTab(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            title: const Text(
              'Khám phá',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TabBar(
                controller: _tabController,
                labelColor: _kAccent,
                unselectedLabelColor: Colors.white54,
                indicatorColor: _kAccent,
                indicatorWeight: 2.5,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: _kLiveBadge, size: 8),
                        SizedBox(width: 6),
                        Text('Đang Live', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 16),
                        SizedBox(width: 4),
                        Text('Mentor', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: _buildGameFilter(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildLiveTab(),
            _buildMentorTab(),
          ],
        ),
      ),
    );
  }
}

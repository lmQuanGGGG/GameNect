import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:developer' as developer;
import '../../../core/providers/moment_provider.dart';
import '../../../core/services/moment_notification_navigation.dart';
import '../../../core/services/video_warmup_service.dart';
import 'moment_card.dart';
import 'moment_grid_item.dart';
import 'trending_games_page.dart';
import 'discover_hub_page.dart';
import 'mentor_post_preview_card.dart';
import '../camera/camera_capture_screen.dart';
import '../../../core/theme/theme_helper.dart';
import '../mentor/all_mentor_media_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Tab "Khám phá" — hiển thị moments của tất cả bạn bè trong 2 chế độ:
/// - PageView (vertical scroll, fullscreen mỗi moment)
/// - GridView (2 cột, thumbnail)
class MomentFeedTab extends StatefulWidget {
  const MomentFeedTab({super.key});

  @override
  State<MomentFeedTab> createState() => _MomentFeedTabState();
}

class _MomentFeedTabState extends State<MomentFeedTab> {
  final PageController _pageController = PageController();
  bool isGridMode = false;
  bool _isTabVisible = false;

  void _preloadNextMoments(int currentIndex, MomentProvider provider) {
    final moments = provider.moments;
    if (currentIndex >= moments.length - 1) return;

    final endIndex = (currentIndex + 2).clamp(0, moments.length - 1);

    for (var index = currentIndex + 1; index <= endIndex; index++) {
      final moment = moments[index];
      final url = moment.isVideo
          ? (moment.thumbnailUrl ?? '')
          : moment.mediaUrl;
      if (url.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(url), context);
      }
      if (moment.isVideo && moment.mediaUrl.isNotEmpty) {
        VideoWarmupService.warmUp(moment.mediaUrl);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    pendingMomentIdToOpen.addListener(_handlePendingMomentNavigation);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _tryOpenPendingMoment();
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'lastSeenMoments': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          developer.log('Updated lastSeenMoments', name: 'MomentFeedTab');
        } catch (e) {
          developer.log(
            'Error updating lastSeenMoments: $e',
            name: 'MomentFeedTab',
            error: e,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    pendingMomentIdToOpen.removeListener(_handlePendingMomentNavigation);
    _pageController.dispose();
    super.dispose();
  }

  void _handlePendingMomentNavigation() {
    if (!mounted || pendingMomentIdToOpen.value == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _tryOpenPendingMoment(),
    );
  }

  void _tryOpenPendingMoment([MomentProvider? provider]) {
    if (!mounted) return;
    final momentId = pendingMomentIdToOpen.value;
    if (momentId == null || momentId.isEmpty) return;

    final momentProvider =
        provider ?? Provider.of<MomentProvider>(context, listen: false);
    final momentIndex = momentProvider.moments.indexWhere(
      (moment) => moment.id == momentId,
    );
    if (momentIndex < 0) {
      developer.log(
        'Pending moment not loaded yet: $momentId',
        name: 'MomentFeedTab',
      );
      return;
    }

    void openTargetPage() {
      if (!mounted || !_pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) => openTargetPage());
        return;
      }

      final targetPage = momentIndex + 1; // page 0 là DiscoverHubPage
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      _preloadNextMoments(momentIndex, momentProvider);
      pendingMomentIdToOpen.value = null;
      developer.log(
        'Opened moment from notification: $momentId at page $targetPage',
        name: 'MomentFeedTab',
      );
    }

    if (isGridMode) {
      setState(() => isGridMode = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => openTargetPage());
    } else {
      openTargetPage();
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.deepOrange.withValues(alpha: 0.2),
                  Colors.orange.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Icon(
              Icons.photo_camera_rounded,
              size: 80,
              color: context.textColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Chưa có khoảnh khắc nào',
            style: TextStyle(
              color: context.textColor,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              'Chia sẻ khoảnh khắc đầu tiên với bạn bè!',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondaryColor, fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text(
              'Đăng khoảnh khắc',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final topPadding = MediaQuery.of(context).padding.top + 92;

    return VisibilityDetector(
      key: const Key('moment-feed-tab'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0.6;

        if (_isTabVisible != visible) {
          setState(() {
            _isTabVisible = visible;
          });
        }
      },
      child: Stack(
        children: [
          Consumer<MomentProvider>(
            builder: (context, provider, _) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _tryOpenPendingMoment(provider),
              );

              if (provider.isLoading) {
                return Padding(
                  padding: EdgeInsets.only(top: topPadding),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepOrange,
                      strokeWidth: 3,
                    ),
                  ),
                );
              }

              final hasMoments = provider.moments.isNotEmpty;

              Widget content;
              if (isGridMode) {
                final screenWidth = MediaQuery.sizeOf(context).width;
                final mentorMediaSize = (screenWidth * 0.24).clamp(
                  360.0,
                  620.0,
                );
                content = CustomScrollView(
                  cacheExtent: 2500,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8, topPadding + 12, 8, 8),
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(right: 68),
                              child: TrendingGamesButton(),
                            ),
                            const SizedBox(height: 12),
                            // Optional: we can add a button for mentor posts in grid mode, but the page handles itself nicely
                            // Actually let's make it a button as well
                            MentorPostPreviewCard(
                              height: screenWidth >= 900
                                  ? mentorMediaSize + 58
                                  : 265,
                              mediaAspectRatio: 1,
                              splitEvenly: true,
                              autoplayVideo: _isTabVisible && isGridMode,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AllMentorMediaScreen(),
                                  ),
                                );
                              },
                              fallback: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AllMentorMediaScreen(),
                                  ),
                                ),
                                child: _buildMentorButtonContent(
                                  context,
                                  isWeb: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasMoments)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 120),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 250,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.65,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => MomentGridItem(
                              moment: provider.moments[index],
                              currentUserId: userId,
                            ),
                            childCount: provider.moments.length,
                          ),
                        ),
                      )
                    else
                      SliverFillRemaining(child: _buildEmptyState(context)),
                  ],
                );
              } else {
                content = Padding(
                  padding: EdgeInsets.only(top: topPadding),
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: hasMoments ? provider.moments.length + 1 : 2,
                    onPageChanged: (pageIndex) {
                      if (hasMoments && pageIndex > 0) {
                        _preloadNextMoments(pageIndex - 1, provider);
                      }
                    },
                    itemBuilder: (context, index) {
                      if (index == 0) return const DiscoverHubPage();
                      if (!hasMoments && index == 1) {
                        return _buildEmptyState(context);
                      }
                      return MomentCard(
                        key: ValueKey(provider.moments[index - 1].id),
                        moment: provider.moments[index - 1],
                        currentUserId: userId,
                      );
                    },
                  ),
                );
              }

              return RefreshIndicator(
                color: Colors.deepOrange,
                backgroundColor: context.cardBgColor,
                displacement: 20,
                onRefresh: () async {
                  final currentUid = FirebaseAuth.instance.currentUser?.uid;
                  if (currentUid != null) {
                    await provider.listenMoments(currentUid);
                  }
                },
                child: content,
              );
            },
          ),

          // Grid/Page mode toggle button
          Positioned(
            top: topPadding + 55,
            right: 16,
            child: GestureDetector(
              onTap: () => setState(() => isGridMode = !isGridMode),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white, // White
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                  ],
                ),
                child: Icon(
                  isGridMode
                      ? Icons.view_agenda_rounded
                      : Icons.grid_view_rounded,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentorButtonContent(
    BuildContext context, {
    required bool isWeb,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // White
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Icon(
              Icons.auto_awesome_mosaic_rounded,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MENTOR POSTS',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ảnh, video độc quyền từ Mentor',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

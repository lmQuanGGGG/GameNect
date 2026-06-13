import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'dart:developer' as developer;
import '../../../core/providers/moment_provider.dart';
import 'moment_card.dart';
import 'moment_grid_item.dart';
import 'trending_games_page.dart';
import 'discover_hub_page.dart';
import '../camera/camera_capture_screen.dart';
import '../../../core/theme/theme_helper.dart';
import '../mentor/all_mentor_media_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

    return Stack(
      children: [
        Consumer<MomentProvider>(
          builder: (context, provider, _) {
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
              content = CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 8),
                      child: Column(
                        children: [
                          const TrendingGamesButton(),
                          const SizedBox(height: 12),
                          // Optional: we can add a button for mentor posts in grid mode, but the page handles itself nicely
                          // Actually let's make it a button as well
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AllMentorMediaScreen(),
                              ),
                            ),
                            child: _buildMentorButtonContent(context, isWeb: false),
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
                  itemBuilder: (context, index) {
                    if (index == 0) return const DiscoverHubPage();
                    if (!hasMoments && index == 1)
                      return _buildEmptyState(context);
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
          top: topPadding + 12,
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
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(4, 4),
                  ),
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
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
          ),
        ],
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

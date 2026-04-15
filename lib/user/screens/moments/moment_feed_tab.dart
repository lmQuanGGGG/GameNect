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
import '../camera/camera_capture_screen.dart';

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
          await FirebaseFirestore.instance.collection('users').doc(userId).set(
            {'lastSeenMoments': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
          developer.log('Updated lastSeenMoments', name: 'MomentFeedTab');
        } catch (e) {
          developer.log('Error updating lastSeenMoments: $e', name: 'MomentFeedTab', error: e);
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
            child: const Icon(Icons.photo_camera_rounded, size: 80, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          const Text('Chưa có khoảnh khắc nào',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 50),
            child: Text('Chia sẻ khoảnh khắc đầu tiên với bạn bè!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 16)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Đăng khoảnh khắc',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
    final topPadding = MediaQuery.of(context).padding.top + 120;

    return Stack(
      children: [
        Consumer<MomentProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.deepOrange, strokeWidth: 3),
                ),
              );
            }

            final hasMoments = provider.moments.isNotEmpty;

            if (isGridMode) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 8),
                      child: const TrendingGamesButton(),
                    ),
                  ),
                  if (hasMoments)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.75,
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
              return Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: hasMoments ? provider.moments.length + 1 : 2,
                  itemBuilder: (context, index) {
                    if (index == 0) return const TrendingGamesPage();
                    if (!hasMoments && index == 1) return _buildEmptyState(context);
                    return MomentCard(
                      moment: provider.moments[index - 1],
                      currentUserId: userId,
                    );
                  },
                ),
              );
            }
          },
        ),

        // Grid/Page mode toggle button
        Positioned(
          top: topPadding + 12,
          right: 16,
          child: GestureDetector(
            onTap: () => setState(() => isGridMode = !isGridMode),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Icon(
                    isGridMode ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                    color: Colors.white, size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

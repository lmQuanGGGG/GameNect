import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../../../core/providers/moment_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/mentor_provider.dart';
import '../premium/subscription_screen.dart';
import '../../../core/theme/theme_helper.dart';

// Sub-widgets (tách ra theo từng file để dễ bảo trì)
import 'moment_feed_tab.dart';
import 'my_moments_tab.dart';
import '../../widgets/tab_bar_visibility.dart';
export 'moment_card.dart';
export 'video_player_widget.dart';

/// Màn hình Moments — entry point với TabBarView 3 tab:
/// - "Khám phá": Feed tất cả moments của bạn bè
/// - "Live": Khám phá livestream & mentor
/// - "Của tôi": Moments do user hiện tại đăng
///
/// Header glassmorphism với TabBar và badge Premium.
class MomentScreen extends StatefulWidget {
  const MomentScreen({super.key});

  @override
  State<MomentScreen> createState() => _MomentScreenState();
}

class _MomentScreenState extends State<MomentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadMoments();
  }

  void _handleTabSelection() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadMoments() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final provider = Provider.of<MomentProvider>(context, listen: false);
      await provider.listenMoments(userId);
      if (mounted) {
        Provider.of<MentorProvider>(
          context,
          listen: false,
        ).loadMyMentorProfile(userId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Content — 3 tabs
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              TabBarVisibility.of(context).update(notification);
              return false;
            },
            child: TabBarView(
              controller: _tabController,
              children: const [MomentFeedTab(), MyMomentsTab()],
            ),
          ),

          // Neo-Brutalism header (logo + tab bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: context.appBarBgColor,
                border: Border(
                  bottom: BorderSide(color: context.textColor, width: 3),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Logo row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        0,
                      ), // Giảm khoảng cách dưới để nâng TabBar lên
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 12.0),
                            child: Icon(
                              Icons.sports_esports,
                              color: Color(0xFFFF6E40),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'gamenect',
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              shadows: [
                                Shadow(
                                  color: const Color(
                                    0xFFFF6E40,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Premium badge hoặc nút nâng cấp
                          Consumer<ProfileProvider>(
                            builder: (context, provider, _) {
                              final isPremium =
                                  provider.userData?.isPremium == true;
                              if (isPremium) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.textColor,
                                        borderRadius: BorderRadius.circular(12),
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
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.workspace_premium_rounded,
                                            color: Color(0xFFFF6E40),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Premium',
                                            style: TextStyle(
                                              color: context
                                                  .scaffoldBackgroundColor,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                return TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SubscriptionScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.workspace_premium_rounded,
                                    color: Color(0xFFFF6E40),
                                    size: 20,
                                  ),
                                  label: Text(
                                    'Nâng cấp',
                                    style: TextStyle(
                                      color: context.textColor,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFFFF6E40),
                      indicatorWeight: 2, // Làm thanh chọn mảnh hơn một chút
                      dividerColor:
                          Colors.transparent, // Bỏ đường gạch chân mặc định
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                      labelColor: context.textColor,
                      unselectedLabelColor: context.textSecondaryColor,
                      labelStyle: const TextStyle(
                        fontSize: 14, // Giảm font size cho nhỏ gọn
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14, // Giảm font size cho nhỏ gọn
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Khám phá'),
                        Tab(text: 'Của tôi'),
                      ],
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

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }
}

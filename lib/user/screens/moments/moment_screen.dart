import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../../../core/providers/moment_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../premium/subscription_screen.dart';

// Sub-widgets (tách ra theo từng file để dễ bảo trì)
import 'moment_feed_tab.dart';
import 'my_moments_tab.dart';
export 'moment_card.dart';
export 'video_player_widget.dart';

/// Màn hình Moments — entry point với TabBarView 2 tab:
/// - "Khám phá": Feed tất cả moments của bạn bè
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
    _loadMoments();
  }

  Future<void> _loadMoments() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final provider = Provider.of<MomentProvider>(context, listen: false);
      await provider.listenMoments(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Content — 2 tabs
          TabBarView(
            controller: _tabController,
            children: const [MomentFeedTab(), MyMomentsTab()],
          ),

          // Glassmorphism header (logo + tab bar)
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.deepOrange.withValues(alpha: 0.8),
                        const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.6),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // Logo row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 12.0),
                                child: Icon(Icons.sports_esports,
                                    color: Colors.deepOrange, size: 26),
                              ),
                              const SizedBox(width: 8),
                              const Text('gamenect',
                                  style: TextStyle(
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                              const Spacer(),
                              // Premium badge hoặc nút nâng cấp
                              Consumer<ProfileProvider>(
                                builder: (context, provider, _) {
                                  final isPremium = provider.userData?.isPremium == true;
                                  if (isPremium) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                              colors: [Colors.amber, Colors.orange.shade600]),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.workspace_premium_rounded,
                                                color: Colors.white, size: 18),
                                            SizedBox(width: 4),
                                            Text('Premium',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    return TextButton.icon(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => const SubscriptionScreen()),
                                      ),
                                      icon: const Icon(Icons.workspace_premium_rounded,
                                          color: Colors.deepOrange, size: 20),
                                      label: const Text('Nâng cấp',
                                          style: TextStyle(
                                              color: Colors.deepOrange, fontWeight: FontWeight.w600)),
                                      style: TextButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(horizontal: 12)),
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
                          indicatorColor: Colors.deepOrange,
                          indicatorWeight: 3,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white60,
                          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          tabs: const [Tab(text: 'Khám phá'), Tab(text: 'Của tôi')],
                        ),
                      ],
                    ),
                  ),
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
    _tabController.dispose();
    super.dispose();
  }
}

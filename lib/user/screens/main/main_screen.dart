import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:developer' as developer;

import '../profile/profile_screen.dart';
import '../matching/match_screen.dart';
import '../matching/liked_me_screen.dart';
import '../matching/match_list_screen.dart';
import '../moments/moment_screen.dart';
import '../camera/camera_capture_screen.dart';
import '../camera/web_rtc_camera_screen.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/camera_preload_service.dart';

// Tách TabBar ra file riêng để code gọn gàng hơn
import '../../widgets/liquid_glass_tab_bar.dart';
import '../../widgets/tab_bar_visibility.dart';
import '../../../core/theme/theme_helper.dart';
import '../../../core/providers/match_provider.dart';
import '../../../core/models/user_model.dart';

final ValueNotifier<int> mainScreenTabIndex = ValueNotifier<int>(0);

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final _tabBarVisibility = TabBarVisibilityController();
  late int _currentIndex;
  late final List<AnimationController> _itemControllers;
  late final List<Animation<double>> _itemScales;
  late final List<Animation<double>> _itemGlows;
  late final Stream<Map<String, int>> _badgeStream;

  final List<Widget> _screens = [
    MatchScreen(),
    const MomentScreen(),
    LikedMeScreen(),
    MatchListScreen(),
    const ProfilePage(),
  ];

  static const _tabs = [
    TabItemData(icon: Icons.sports_esports_rounded, label: 'Khám phá'),
    TabItemData(icon: CupertinoIcons.photo_fill_on_rectangle_fill, label: 'Feed'),
    TabItemData(icon: CupertinoIcons.heart_fill, label: 'Lượt thích'),
    TabItemData(icon: CupertinoIcons.chat_bubble_2_fill, label: 'Tin nhắn'),
    TabItemData(icon: CupertinoIcons.person_fill, label: 'Hồ sơ'),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    mainScreenTabIndex.value = _currentIndex;
    mainScreenTabIndex.addListener(_onGlobalTabChanged);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _badgeStream = _getBadgeCountsStream(currentUserId);

    _itemControllers = List.generate(
      _tabs.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      ),
    );

    _itemScales = _itemControllers
        .map(
          (c) => Tween<double>(begin: 1.0, end: 1.25).animate(
            CurvedAnimation(parent: c, curve: Curves.elasticOut),
          ),
        )
        .toList();

    _itemGlows = _itemControllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: c, curve: Curves.easeOut),
          ),
        )
        .toList();

    _itemControllers[0].forward();
  }

  @override
  void dispose() {
    mainScreenTabIndex.removeListener(_onGlobalTabChanged);
    for (final c in _itemControllers) {
      c.dispose();
    }
    _tabBarVisibility.dispose();
    super.dispose();
  }

  void _onGlobalTabChanged() {
    if (mounted && _currentIndex != mainScreenTabIndex.value) {
      _onTabTap(mainScreenTabIndex.value);
    }
  }

  void _onTabTap(int index) {
    if (_currentIndex == index) return;
    _itemControllers[_currentIndex].reverse();
    setState(() => _currentIndex = index);
    _itemControllers[index].forward();
  }

  @override
  Widget build(BuildContext context) {
    return TabBarVisibility(
      controller: _tabBarVisibility,
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            // ── Nội dung chính ──
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),

            // ── Tab Bar auto-hide khi vuốt ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ListenableBuilder(
                listenable: _tabBarVisibility,
                builder: (context, _) {
                  return AnimatedSlide(
                    offset: _tabBarVisibility.visible
                        ? Offset.zero
                        : const Offset(0, 1.5),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    child: AnimatedOpacity(
                      opacity: _tabBarVisibility.visible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: StreamBuilder<Map<String, int>>(
                        stream: _badgeStream,
                        builder: (context, snapshot) {
                          final badges = snapshot.data ??
                              {'likes': 0, 'messages': 0, 'moments': 0};
                          return LiquidGlassTabBar(
                            currentIndex: _currentIndex,
                            badges: badges,
                            tabs: _tabs,
                            itemControllers: _itemControllers,
                            itemScales: _itemScales,
                            itemGlows: _itemGlows,
                            onTap: (i) {
                              _onTabTap(i);
                              // Luôn hiện TabBar khi chuyển tab
                              _tabBarVisibility.setVisible(true);
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: ListenableBuilder(
          listenable: _tabBarVisibility,
          builder: (context, _) {
            return AnimatedSlide(
              offset: _tabBarVisibility.visible ? Offset.zero : const Offset(0, 1.5),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: _tabBarVisibility.visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 84), // Nằm ngay trên TabBar
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Camera shortcut button
                      GestureDetector(
                        onTap: () {
                          if (FirebaseAuth.instance.currentUser == null) {
                            Navigator.pushReplacementNamed(context, '/login');
                          } else {
                            // Không gọi preload để tránh kẹt chấm xanh
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WebRTCCameraScreen()),
                            );
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6E40), // Cam Neo-Brutalism
                            border: Border.all(color: context.textColor, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: context.textColor, offset: const Offset(1.5, 1.5))
                            ],
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Live button
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/live-discover'),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55),
                            border: Border.all(color: context.textColor, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: context.textColor, offset: const Offset(1.5, 1.5))
                            ],
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            CupertinoIcons.radiowaves_right,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Badge Stream Logic (Tối ưu hóa tránh Connection Storm & Async Map) ─────────────────────────────────────────
  Stream<Map<String, int>> _getBadgeCountsStream(String currentUserId) {
    if (currentUserId.isEmpty) {
      return Stream.value({'likes': 0, 'messages': 0, 'moments': 0});
    }

    final matchesStream = FirebaseFirestore.instance
        .collection('matches')
        .where('userIds', arrayContains: currentUserId)
        .where('status', isEqualTo: 'confirmed')
        .snapshots();

    final momentsStream = FirebaseFirestore.instance
        .collection('moments')
        .where('matchIds', arrayContains: currentUserId)
        .snapshots();

    // Stream liked me của người dùng (tải từ MatchProvider)
    final mProvider = Provider.of<MatchProvider>(context, listen: false);
    final likedMeStream = mProvider.streamLikedMeUsers(currentUserId);

    // Stream thay đổi của chính user để lấy lastSeenMoments realtime
    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .snapshots();

    return Rx.combineLatest4(
      matchesStream,
      momentsStream,
      likedMeStream,
      userStream,
      (QuerySnapshot matchesSnapshot, QuerySnapshot momentsSnapshot, List<UserModel> likedUsers, DocumentSnapshot userSnapshot) {
        
        // 1. Số lượt thích (likes) = Số user thích mình chưa phản hồi
        final newLikesCount = likedUsers.length;

        // 2. Số tin nhắn chưa đọc
        int unreadMessagesCount = 0;
        for (var matchDoc in matchesSnapshot.docs) {
          final matchData = matchDoc.data() as Map<String, dynamic>? ?? {};
          final lastMessageTime = matchData['lastMessageTime'];
          final lastMessageSenderId = matchData['lastMessageSenderId'];
          final lastSeen = matchData['lastSeen_$currentUserId'];

          if (lastMessageTime != null &&
              lastMessageSenderId != null &&
              lastMessageSenderId != currentUserId) {
            DateTime? lastMsgTime;
            if (lastMessageTime is Timestamp) {
              lastMsgTime = lastMessageTime.toDate();
            } else if (lastMessageTime is String) {
              lastMsgTime = DateTime.tryParse(lastMessageTime);
            }

            DateTime? lastSeenTime;
            if (lastSeen is Timestamp) {
              lastSeenTime = lastSeen.toDate();
            } else if (lastSeen is String) {
              lastSeenTime = DateTime.tryParse(lastSeen);
            }

            if (lastMsgTime != null) {
              if (lastSeenTime == null || lastMsgTime.isAfter(lastSeenTime)) {
                unreadMessagesCount++;
              }
            }
          }
        }

        // 3. Số khoảnh khắc chưa đọc
        int newMomentsCount = 0;
        try {
          DateTime? lastSeenMoments;
          if (userSnapshot.exists) {
            final userData = userSnapshot.data() as Map<String, dynamic>?;
            final lastSeen = userData?['lastSeenMoments'];
            if (lastSeen is Timestamp) {
              lastSeenMoments = lastSeen.toDate();
            } else if (lastSeen is String) {
              lastSeenMoments = DateTime.tryParse(lastSeen);
            }
          }

          if (lastSeenMoments != null) {
            newMomentsCount = momentsSnapshot.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final userId = data['userId'];
              final createdAt = data['createdAt'];
              if (userId == currentUserId) return false;
              if (createdAt is Timestamp) {
                return createdAt.toDate().isAfter(lastSeenMoments!);
              }
              return false;
            }).length;
          } else {
            newMomentsCount = momentsSnapshot.docs
                .where((doc) => (doc.data() as Map<String, dynamic>?)?['userId'] != currentUserId)
                .length;
          }
        } catch (e) {
          developer.log(
            'Error counting moments: $e',
            name: 'MainScreen.Badge',
            error: e,
          );
          newMomentsCount = 0;
        }

        return {
          'likes': newLikesCount,
          'messages': unreadMessagesCount,
          'moments': newMomentsCount,
        };
      },
    );
  }
}
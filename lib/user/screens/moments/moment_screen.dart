import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../../../core/providers/moment_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/mentor_provider.dart';
import '../../../core/providers/match_provider.dart';
import '../premium/subscription_screen.dart';
import '../../../core/theme/theme_helper.dart';

// Sub-widgets (tách ra theo từng file để dễ bảo trì)
import 'moment_feed_tab.dart';
import 'my_moments_tab.dart';
import '../matching/match_list_screen.dart';
import '../chat/chat_screen.dart';
import '../main/main_screen.dart';
import '../../../core/models/user_model.dart';
import '../../widgets/tab_bar_visibility.dart';
import 'suggested_mentors_sidebar.dart';
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
  UserModel? _selectedChatUser;
  String? _selectedMatchId;
  bool _isChatPopupOpen = false;

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
      extendBodyBehindAppBar: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Neo-Brutalism header (logo + tab bar)
            Container(
              decoration: BoxDecoration(
                color: context.appBarBgColor,
                border: Border(
                  bottom: BorderSide(color: context.textColor, width: 1.5),
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
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.textColor,
                                            offset: const Offset(1.5, 1.5),
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
                                          const SizedBox(width: 1.5),
                                          Text(
                                            'Pre',
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
            
            // Content — 3 tabs
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  TabBarVisibility.of(context).update(notification);
                  return false;
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isLargeScreen = constraints.maxWidth >= 1000;
                    
                    Widget feedContent = TabBarView(
                      controller: _tabController,
                      children: const [MomentFeedTab(), MyMomentsTab()],
                    );

                    if (isLargeScreen) {
                      // Instagram style: Centered feed, specific max width
                      feedContent = Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 700),
                            child: feedContent,
                          ),
                          if (constraints.maxWidth >= 1100) ...[
                            const SizedBox(width: 40),
                            const SizedBox(
                              width: 320,
                              child: SuggestedMentorsSidebar(),
                            ),
                          ],
                        ],
                      );

                      return Stack(
                        children: [
                          feedContent,
                          
                          // Floating Chat Popup & Button
                          Positioned(
                            bottom: 104,
                            right: 88,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Chat Popup Window
                                if (_isChatPopupOpen)
                                  Container(
                                    width: 380,
                                    height: 550,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: context.scaffoldBackgroundColor,
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
                                              color: context.scaffoldBackgroundColor,
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
                                                    Icons.open_in_full_rounded,
                                                    size: 20,
                                                    color: context.textColor,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () {
                                                    // Chuyển sang tab Tin nhắn
                                                    mainScreenTabIndex.value = 3;
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

                                // Floating Action Button (Tin nhắn)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isChatPopupOpen = !_isChatPopupOpen;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: context.scaffoldBackgroundColor,
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
                                                            border: Border.all(color: context.scaffoldBackgroundColor, width: 1.5),
                                                          ),
                                                          child: CircleAvatar(
                                                            radius: 11, // Slightly smaller to account for border
                                                            backgroundColor: context.scaffoldBackgroundColor,
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
                                                          color: const Color(0xFFFF6E40), // Bright red/orange
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
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    
                    return feedContent;
                  },
                ),
              ),
            ),
          ],
        ),
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

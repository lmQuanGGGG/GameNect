import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/match_provider.dart';
import '../chat/chat_screen.dart';
import 'dart:ui';
import '../premium/subscription_screen.dart';
import '../../../core/providers/profile_provider.dart';
import 'dart:developer' as developer;
import '../../widgets/tab_bar_visibility.dart';
import '../../../core/theme/theme_helper.dart';
import 'dart:async';
import '../../../core/services/firestore_service.dart';
import '../shared/peer_profile_screen.dart';

// Màn hình danh sách match và tin nhắn
// Hiển thị dãy avatar ngang của các match và danh sách chat dọc
class MatchListScreen extends StatefulWidget {
  const MatchListScreen({super.key});

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  String searchText = '';
  Stream<List<Map<String, dynamic>>>? _matchStream;
  String? _currentUserId;

  String? _activeMatchId;
  UserModel? _activePeerUser;

  Timer? _debounce;
  List<UserModel> _globalSearchResults = [];
  bool _isSearchingGlobal = false;

  void _onSearchChanged(String value) {
    setState(() {
      searchText = value;
      _isSearchingGlobal = true;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      if (searchText.trim().isNotEmpty) {
        final results = await FirestoreService().searchUsersByUsername(
          searchText.trim(),
        );
        if (mounted) {
          setState(() {
            _globalSearchResults = results;
            // Xoá mình ra khỏi kết quả
            _globalSearchResults.removeWhere((u) => u.id == _currentUserId);
            _isSearchingGlobal = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _globalSearchResults = [];
            _isSearchingGlobal = false;
          });
        }
      }
    });
  }

  void _handleChatTap(BuildContext context, String matchId, UserModel peerUser, bool isLargeScreen) {
    if (isLargeScreen) {
      setState(() {
        _activeMatchId = matchId;
        _activePeerUser = peerUser;
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            matchId: matchId,
            peerUser: peerUser,
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (_currentUserId!.isNotEmpty) {
      // Khởi tạo stream để lắng nghe realtime danh sách match
      _matchStream = Provider.of<MatchProvider>(
        context,
        listen: false,
      ).matchedUsersStream(_currentUserId!);

      developer.log(
        'Stream initialized for user: $_currentUserId',
        name: 'MatchListScreen',
      );

      // Load profile sau khi frame đầu tiên được build để tránh lỗi
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
          if (profileProvider.userData == null) {
            profileProvider.loadUserProfile();
          }
        }
      });
    }
  }

  Widget _buildMobileOrLeftPane(BuildContext context, bool isLargeScreen) {
    final shadowColors = [
      const Color(0xFFFF6E40), // Orange
      const Color(0xFFC293FF), // Purple
      const Color(0xFFB9FF66), // Lime
      const Color(0xFF4EEAF6), // Cyan
    ];

    // Kiểm tra user đã đăng nhập chưa
    if (_matchStream == null ||
        _currentUserId == null ||
        _currentUserId!.isEmpty) {
      return const Scaffold(body: Center(child: Text('Vui lòng đăng nhập')));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.isDarkMode
          ? Colors.black
          : const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: context.scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: context.isDarkMode ? Colors.white24 : Colors.black12,
                width: 1,
              ),
            ),
          ),
        ),
        title: Row(
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
                    color: const Color(0xFFFF6E40).withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Hiển thị badge Premium hoặc nút Nâng cấp
          Consumer<ProfileProvider>(
            builder: (context, provider, _) {
              final isPremium = provider.userData?.isPremium == true;
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
                        border: Border.all(color: context.textColor, width: 3),
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
                              color: context.scaffoldBackgroundColor,
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
                        builder: (_) => const SubscriptionScreen(),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Content
          SafeArea(
            child: Column(
              children: [
                // Thanh tìm kiếm luôn hiển thị
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.isDarkMode ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.isDarkMode ? Colors.white : Colors.black,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.isDarkMode
                              ? const Color.fromARGB(255, 255, 255, 255)
                              : Colors.black,
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      style: TextStyle(color: context.textColor),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm tên...',
                        hintStyle: TextStyle(color: context.textTertiaryColor),
                        prefixIcon: Icon(
                          Icons.search,
                          color: context.textSecondaryColor,
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _matchStream,
                    builder: (context, snapshot) {
                      // Xử lý các trạng thái loading, error, no data
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        developer.log(
                          'Stream waiting...',
                          name: 'MatchListScreen',
                        );
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        developer.log(
                          'Stream error: ${snapshot.error}',
                          name: 'MatchListScreen',
                          error: snapshot.error,
                        );
                        return Center(child: Text('Lỗi: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData) {
                        developer.log(
                          'Stream has no data',
                          name: 'MatchListScreen',
                        );
                        return const Center(child: CircularProgressIndicator());
                      }

                      final matchedData = snapshot.data!;
                      developer.log(
                        'Stream data received: ${matchedData.length} matches',
                        name: 'MatchListScreen',
                      );

                      // if (matchedData.isEmpty) {
                      //  return Center(child: Text('Bạn chưa có match nào!', style: TextStyle(color: context.textSecondaryColor)));
                      // }

                      // Lọc theo từ khóa tìm kiếm
                      final filteredData = searchText.isEmpty
                          ? matchedData
                          : matchedData.where((m) {
                              final user = m['user'] as UserModel;
                              return user.username.toLowerCase().contains(
                                searchText.toLowerCase(),
                              );
                            }).toList();

                      // Sắp xếp theo thời gian match để hiển thị avatar ngang
                      final sortedByMatchTime = [...filteredData];
                      sortedByMatchTime.sort((a, b) {
                        final aTime =
                            a['matchedAt'] ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        final bTime =
                            b['matchedAt'] ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        return bTime.compareTo(aTime);
                      });

                      // Sắp xếp theo thời gian tin nhắn cuối để hiển thị danh sách chat
                      final sortedByMessageTime = filteredData.where((m) => m['lastMessage'] != null).toList();
                      sortedByMessageTime.sort((a, b) {
                        final aTime =
                            a['lastMessageTime'] ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        final bTime =
                            b['lastMessageTime'] ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        return bTime.compareTo(aTime);
                      });

                      developer.log(
                        'Sorted by message time: ${sortedByMessageTime.map((m) => '${(m['user'] as UserModel).username}: ${m['lastMessageTime']}')}',
                        name: 'MatchListScreen',
                      );

                      return NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          // Truyền scroll event lên TabBarVisibility để auto-hide TabBar
                          try {
                            TabBarVisibility.of(context).update(n);
                          } catch (_) {}
                          return false;
                        },
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            // Header cho dãy avatar
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 20,
                                top: 16,
                                bottom: 4,
                              ),
                              child: Text(
                                'TƯƠNG HỢP MỚI',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textSecondaryColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            // Dãy avatar ngang của các match, sắp xếp theo thời gian match
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: SizedBox(
                                height:
                                    120, // Increased height for Neo-Brutalism layout
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: sortedByMatchTime.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 16),
                                  itemBuilder: (context, index) {
                                    final user =
                                        sortedByMatchTime[index]['user']
                                            as UserModel;
                                    final matchId =
                                        sortedByMatchTime[index]['matchId']
                                            as String;

                                    return GestureDetector(
                                      // Tap để vào chat
                                      onTap: () => _handleChatTap(context, matchId, user, isLargeScreen),
                                      // Long press để unmatch
                                      onLongPress: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            elevation: 0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: context.isDarkMode
                                                    ? Colors.black
                                                    : const Color(0xFFF4F4F4),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: context.isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                                  width: 3,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: context.isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                    offset: const Offset(8, 8),
                                                  ),
                                                ],
                                              ),
                                              padding: const EdgeInsets.all(24),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Hủy tương hợp?',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: context.textColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    'Bạn có chắc muốn hủy tương hợp với ${user.username}?',
                                                    style: TextStyle(
                                                      color: context
                                                          .textSecondaryColor,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 24),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              false,
                                                            ),
                                                        style: TextButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 20,
                                                                vertical: 12,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          'Không',
                                                          style: TextStyle(
                                                            color: context
                                                                .textSecondaryColor,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              true,
                                                            ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                                0xFFFF6E40,
                                                              ),
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 24,
                                                                vertical: 12,
                                                              ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          elevation: 0,
                                                        ),
                                                        child: const Text(
                                                          'Hủy tương hợp',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                        if (confirm == true) {
                                          await Provider.of<MatchProvider>(
                                            context,
                                            listen: false,
                                          ).unmatch(matchId);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Đã hủy tương hợp với ${user.username}',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Avatar Neo-Brutalism
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              border: Border.all(
                                                color: context.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                width: 2,
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(2.5),
                                            child: ClipOval(
                                              child: SizedBox(
                                                width: 56,
                                                height: 56,
                                                child:
                                                    user.avatarUrl != null &&
                                                        user
                                                            .avatarUrl!
                                                            .isNotEmpty
                                                    ? GamenectNetworkImage(
                                                        imageUrl:
                                                            user.avatarUrl!,
                                                        fit: BoxFit.cover,
                                                        placeholder:
                                                            (
                                                              context,
                                                              url,
                                                            ) => Container(
                                                              color:
                                                                  context
                                                                      .isDarkMode
                                                                  ? Colors.white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        )
                                                                  : Colors.black
                                                                        .withValues(
                                                                          alpha:
                                                                              0.05,
                                                                        ),
                                                            ),
                                                        errorWidget:
                                                            (
                                                              context,
                                                              url,
                                                              error,
                                                            ) => Container(
                                                              color:
                                                                  context
                                                                      .isDarkMode
                                                                  ? Colors.white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        )
                                                                  : Colors.black
                                                                        .withValues(
                                                                          alpha:
                                                                              0.05,
                                                                        ),
                                                              child: Icon(
                                                                Icons.person,
                                                                size: 28,
                                                                color: context
                                                                    .textColor,
                                                              ),
                                                            ),
                                                      )
                                                    : Container(
                                                        color:
                                                            context.isDarkMode
                                                            ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  )
                                                            : Colors.black
                                                                  .withValues(
                                                                    alpha: 0.05,
                                                                  ),
                                                        child: Icon(
                                                          Icons.person,
                                                          size: 28,
                                                          color:
                                                              context.textColor,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          // Tên user
                                          SizedBox(
                                            width: 66,
                                            child: Text(
                                              user.username,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: context.textColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            if (searchText.isNotEmpty) ...[
                              // Header cho danh sách Tìm Kiếm Mọi Người
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  top: 12,
                                  bottom: 4,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'MỌI NGƯỜI (GLOBAL)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: context.textSecondaryColor,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    if (_isSearchingGlobal)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8.0),
                                        child: SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFFF6E40),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (!_isSearchingGlobal &&
                                  _globalSearchResults.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Center(
                                    child: Text(
                                      'Không tìm thấy ai',
                                      style: TextStyle(
                                        color: context.textSecondaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ..._globalSearchResults.map((user) {
                                // Kiểm tra xem đã match chưa
                                final isMatched = matchedData.any((m) {
                                  final mUser = m['user'] as UserModel;
                                  return mUser.id == user.id;
                                });

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PeerProfileScreen(
                                            peerUser: user,
                                            showActions:
                                                !isMatched, // Ẩn nút like nếu đã match
                                          ),
                                        ),
                                      );
                                    },
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 4,
                                          ),
                                      leading: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: context.cardBorderColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: SizedBox(
                                            width: 56,
                                            height: 56,
                                            child:
                                                user.avatarUrl != null &&
                                                    user.avatarUrl!.isNotEmpty
                                                ? GamenectNetworkImage(
                                                    imageUrl: user.avatarUrl!,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (
                                                          context,
                                                          url,
                                                        ) => Container(
                                                          color:
                                                              context.isDarkMode
                                                              ? Colors.white
                                                                    .withOpacity(
                                                                      0.1,
                                                                    )
                                                              : Colors.black
                                                                    .withOpacity(
                                                                      0.05,
                                                                    ),
                                                        ),
                                                    errorWidget:
                                                        (
                                                          context,
                                                          url,
                                                          error,
                                                        ) => Container(
                                                          color:
                                                              context.isDarkMode
                                                              ? Colors.white
                                                                    .withOpacity(
                                                                      0.1,
                                                                    )
                                                              : Colors.black
                                                                    .withOpacity(
                                                                      0.05,
                                                                    ),
                                                          child: Icon(
                                                            Icons.person,
                                                            size: 28,
                                                            color: context
                                                                .textColor,
                                                          ),
                                                        ),
                                                  )
                                                : Container(
                                                    color: context.isDarkMode
                                                        ? Colors.white
                                                              .withOpacity(0.1)
                                                        : Colors.black
                                                              .withOpacity(
                                                                0.05,
                                                              ),
                                                    child: Icon(
                                                      Icons.person,
                                                      size: 28,
                                                      color: context.textColor,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        user.username,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: context.textColor,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${user.age} tuổi • ${user.location}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: context.textSecondaryColor,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.chevron_right,
                                        color: context.textSecondaryColor,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],

                            // Header cho danh sách tin nhắn
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 20,
                                top: 12,
                                bottom: 4,
                              ),
                              child: Text(
                                'TIN NHẮN',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondaryColor,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Danh sách chat dọc, sắp xếp theo thời gian tin nhắn cuối
                            ...sortedByMessageTime.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final matchId = item['matchId'] as String;
                              final user = item['user'] as UserModel;
                              final lastMessage =
                                  item['lastMessage'] as String?;
                              final lastMessageTime =
                                  item['lastMessageTime'] as DateTime?;
                              final lastMessageRead =
                                  item['lastMessageRead'] as bool? ?? true;
                              final lastMessageSenderId =
                                  item['lastMessageSenderId'] as String? ?? '';

                              final isUnread =
                                  !lastMessageRead &&
                                  lastMessageSenderId != _currentUserId;

                              return InkWell(
                                onTap: () => _handleChatTap(context, matchId, user, isLargeScreen),
                                onLongPress: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: context.isDarkMode
                                              ? Colors.black
                                              : const Color(0xFFF4F4F4),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: context.isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: context.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                              offset: const Offset(8, 8),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Xóa hội thoại?',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: context.textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            Text(
                                              'Bạn có chắc muốn xóa cuộc trò chuyện với ${user.username}? (Bên kia vẫn sẽ giữ lại tin nhắn)',
                                              style: TextStyle(
                                                color: context
                                                    .textSecondaryColor,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        ctx,
                                                        false,
                                                      ),
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 20,
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Không',
                                                    style: TextStyle(
                                                      color: context
                                                          .textSecondaryColor,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        ctx,
                                                        true,
                                                      ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(
                                                          0xFFFF6E40,
                                                        ),
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 24,
                                                          vertical: 12,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: const Text(
                                                    'Xóa',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  if (confirm == true) {
                                    await Provider.of<MatchProvider>(
                                      context,
                                      listen: false,
                                    ).clearChatForMe(matchId);
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Đã xóa hội thoại với ${user.username}',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: context.cardBorderColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: SizedBox(
                                          width: 56,
                                          height: 56,
                                          child:
                                              user.avatarUrl != null &&
                                                  user.avatarUrl!.isNotEmpty
                                              ? GamenectNetworkImage(
                                                  imageUrl: user.avatarUrl!,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                        color:
                                                            context.isDarkMode
                                                            ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  )
                                                            : Colors.black
                                                                  .withValues(
                                                                    alpha: 0.05,
                                                                  ),
                                                      ),
                                                  errorWidget:
                                                      (
                                                        context,
                                                        url,
                                                        error,
                                                      ) => Container(
                                                        color:
                                                            context.isDarkMode
                                                            ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  )
                                                            : Colors.black
                                                                  .withValues(
                                                                    alpha: 0.05,
                                                                  ),
                                                        child: Icon(
                                                          Icons.person,
                                                          size: 28,
                                                          color:
                                                              context.textColor,
                                                        ),
                                                      ),
                                                )
                                              : Container(
                                                  color: context.isDarkMode
                                                      ? Colors.white.withValues(
                                                          alpha: 0.1,
                                                        )
                                                      : Colors.black.withValues(
                                                          alpha: 0.05,
                                                        ),
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 28,
                                                    color: context.textColor,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      user.username,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isUnread
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: context.textColor,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${user.age} tuổi • ${user.location}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: context.textSecondaryColor,
                                          ),
                                        ),
                                        if (lastMessage != null)
                                          Text(
                                            lastMessage,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isUnread
                                                  ? context.textColor
                                                  : context.textTertiaryColor,
                                              fontWeight: isUnread
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                    trailing: lastMessageTime != null
                                        ? Text(
                                            _formatTime(lastMessageTime),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isUnread
                                                  ? const Color(0xFFFF6E40)
                                                  : context.textTertiaryColor,
                                              fontWeight: isUnread
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ), // đóng ListView
                      ); // đóng NotificationListener
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Format thời gian hiển thị: hôm nay thì hiện giờ:phút, hôm khác hiện ngày/tháng
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 800;

        if (isLargeScreen) {
          return Scaffold(
            backgroundColor: context.isDarkMode ? Colors.black : const Color(0xFFF4F4F4),
            body: Row(
              children: [
                SizedBox(
                  width: 380,
                  child: _buildMobileOrLeftPane(context, true),
                ),
                Container(width: 2, color: context.textColor), // Neo divider
                Expanded(
                  child: _activeMatchId != null && _activePeerUser != null
                      ? ChatScreen(
                          key: ValueKey(_activeMatchId!),
                          matchId: _activeMatchId!,
                          peerUser: _activePeerUser!,
                          showBackButton: false,
                        )
                      : _buildEmptyState(),
                ),
              ],
            ),
          );
        }

        return _buildMobileOrLeftPane(context, false);
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: context.isDarkMode ? Colors.black : const Color(0xFFF4F4F4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.cardBgColor,
                shape: BoxShape.circle,
                border: Border.all(color: context.textColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: context.textColor,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tin nhắn của bạn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chọn một đoạn chat để bắt đầu trò chuyện',
              style: TextStyle(
                fontSize: 16,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

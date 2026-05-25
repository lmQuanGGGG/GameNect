import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/match_provider.dart';
import '../chat/chat_screen.dart';
import 'dart:ui';
import '../premium/subscription_screen.dart';
import '../../../core/providers/profile_provider.dart';
import 'dart:developer' as developer;
import '../../widgets/tab_bar_visibility.dart';
import '../../../core/theme/theme_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (_currentUserId!.isNotEmpty) {
      // Khởi tạo stream để lắng nghe realtime danh sách match
      _matchStream = Provider.of<MatchProvider>(context, listen: false)
          .matchedUsersStream(_currentUserId!);
      
      developer.log('Stream initialized for user: $_currentUserId', name: 'MatchListScreen');
      
      // Load profile sau khi frame đầu tiên được build để tránh lỗi
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<ProfileProvider>(context, listen: false).loadUserProfile();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra user đã đăng nhập chưa
    if (_matchStream == null || _currentUserId == null || _currentUserId!.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: context.appBarBgColor,
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
                shadows: [Shadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.5), blurRadius: 12)],
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
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber, Colors.orange.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
                          builder: (_) => const SubscriptionScreen()),
                    );
                  },
                  icon: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.deepOrange,
                    size: 20,
                  ),
                  label: const Text(
                    'Nâng cấp',
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w600,
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
          // Background Orbs
          Positioned(
            top: 50, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6E40).withValues(alpha: 0.12 * context.bgOrbOpacityMultiplier),
                boxShadow: [BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.1 * context.bgOrbOpacityMultiplier), blurRadius: 100, spreadRadius: 40)],
              ),
            ),
          ),
          Positioned(
            bottom: 100, right: -80,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBF360C).withValues(alpha: 0.15 * context.bgOrbOpacityMultiplier),
                boxShadow: [BoxShadow(color: const Color(0xFFBF360C).withValues(alpha: 0.1 * context.bgOrbOpacityMultiplier), blurRadius: 120, spreadRadius: 50)],
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Content
          SafeArea(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _matchStream,
        builder: (context, snapshot) {
          // Xử lý các trạng thái loading, error, no data
          if (snapshot.connectionState == ConnectionState.waiting) {
            developer.log('Stream waiting...', name: 'MatchListScreen');
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            developer.log('Stream error: ${snapshot.error}', name: 'MatchListScreen', error: snapshot.error);
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            developer.log('Stream has no data', name: 'MatchListScreen');
            return const Center(child: CircularProgressIndicator());
          }

          final matchedData = snapshot.data!;
          developer.log('Stream data received: ${matchedData.length} matches', name: 'MatchListScreen');

          if (matchedData.isEmpty) {
            return Center(child: Text('Bạn chưa có match nào!', style: TextStyle(color: context.textSecondaryColor)));
          }

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
            final aTime = a['matchedAt'] ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b['matchedAt'] ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          // Sắp xếp theo thời gian tin nhắn cuối để hiển thị danh sách chat
          final sortedByMessageTime = [...filteredData];
          sortedByMessageTime.sort((a, b) {
            final aTime = a['lastMessageTime'] ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b['lastMessageTime'] ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          developer.log('Sorted by message time: ${sortedByMessageTime.map((m) => '${(m['user'] as UserModel).username}: ${m['lastMessageTime']}')}', name: 'MatchListScreen');

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
                padding: const EdgeInsets.only(left: 20, top: 16, bottom: 4),
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
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sortedByMatchTime.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final user = sortedByMatchTime[index]['user'] as UserModel;
                      final matchId = sortedByMatchTime[index]['matchId'] as String;

                      return GestureDetector(
                        // Tap để vào chat
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChatScreen(matchId: matchId, peerUser: user),
                            ),
                          );
                        },
                        // Long press để unmatch
                        onLongPress: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Dialog(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 30,
                                      sigmaY: 30,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: context.dialogBgColor.withValues(
                                          alpha: 0.85,
                                        ),
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                          color: context.cardBorderColor,
                                          width: 1.5,
                                        ),
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
                                              fontWeight: FontWeight.w600,
                                              color: context.textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            'Bạn có chắc muốn hủy tương hợp với ${user.username}?',
                                            style: TextStyle(
                                              color: context.textSecondaryColor,
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
                                                    Navigator.pop(ctx, false),
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
                                                    color: context.textSecondaryColor,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFFF6E40),
                                                  foregroundColor: Colors.white,
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
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (confirm == true) {
                            await Provider.of<MatchProvider>(
                              context,
                              listen: false,
                            ).unmatch(matchId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã hủy tương hợp với ${user.username}',
                                ),
                              ),
                            );
                          }
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Avatar với viền gradient Liquid
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF6E40), Color(0xFFFF8A65)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6E40).withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(2.5),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.scaffoldBackgroundColor,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: ClipOval(
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: user.avatarUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(color: context.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                                            errorWidget: (context, url, error) => Container(
                                              color: context.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                              child: Icon(Icons.person, size: 28, color: context.textColor),
                                            ),
                                          )
                                        : Container(
                                            color: context.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                            child: Icon(Icons.person, size: 28, color: context.textColor),
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
              // Thanh tìm kiếm (Liquid Glass Pill)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.cardBgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.cardBorderColor, width: 1),
                      ),
                      child: TextField(
                        style: TextStyle(color: context.textColor),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm tên...',
                          hintStyle: TextStyle(color: context.textTertiaryColor),
                          prefixIcon: Icon(Icons.search, color: context.textSecondaryColor),
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) => setState(() => searchText = value),
                      ),
                    ),
                  ),
                ),
              ),
              // Header cho danh sách tin nhắn
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 12, bottom: 4),
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
              ...sortedByMessageTime.map((item) {
                final matchId = item['matchId'] as String;
                final user = item['user'] as UserModel;
                final lastMessage = item['lastMessage'] as String?;
                final lastMessageTime = item['lastMessageTime'] as DateTime?;

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(matchId: matchId, peerUser: user),
                      ),
                    );
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: context.cardBorderColor, width: 1),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: user.avatarUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: context.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                                  errorWidget: (context, url, error) => Container(
                                    color: context.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                    child: Icon(Icons.person, size: 28, color: context.textColor),
                                  ),
                                )
                              : Container(
                                  color: context.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                  child: Icon(Icons.person, size: 28, color: context.textColor),
                                ),
                        ),
                      ),
                    ),
                    title: Text(
                      user.username,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textColor),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.age} tuổi • ${user.location}',
                          style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
                        ),
                        if (lastMessage != null)
                          Text(
                            lastMessage,
                            style: TextStyle(fontSize: 13, color: context.textTertiaryColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: lastMessageTime != null
                        ? Text(
                            _formatTime(lastMessageTime),
                            style: const TextStyle(fontSize: 12, color: Color(0xFFFF6E40), fontWeight: FontWeight.w500),
                          )
                        : null,
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
}
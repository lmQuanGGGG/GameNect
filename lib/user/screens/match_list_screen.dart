import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/match_provider.dart';
import 'chat_screen.dart';
import 'dart:ui';
import 'subscription_screen.dart';
import '../../core/providers/profile_provider.dart';
import 'dart:developer' as developer;

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
      // Tạo stream 1 LẦN duy nhất trong initState
      _matchStream = Provider.of<MatchProvider>(context, listen: false)
          .matchedUsersStream(_currentUserId!);
      
      developer.log('Stream initialized for user: $_currentUserId', name: 'MatchListScreen');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_matchStream == null || _currentUserId == null || _currentUserId!.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.5),
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 0,
        title: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12.0),
              child: Icon(
                Icons.sports_esports,
                color: Colors.deepOrange,
                size: 26,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'gamenect',
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _matchStream, // Dùng stream đã tạo trong initState
        builder: (context, snapshot) {
          // LOG để debug
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
            return const Center(child: Text('Bạn chưa có match nào!'));
          }

          // Lọc theo searchText
          final filteredData = searchText.isEmpty
              ? matchedData
              : matchedData.where((m) {
                  final user = m['user'] as UserModel;
                  return user.username.toLowerCase().contains(
                    searchText.toLowerCase(),
                  );
                }).toList();

          // SẮP XẾP NGAY TẠI ĐÂY - một lần duy nhất cho avatar list
          final sortedByMatchTime = [...filteredData];
          sortedByMatchTime.sort((a, b) {
            final aTime = a['matchedAt'] ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b['matchedAt'] ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          // SẮP XẾP cho chat list theo lastMessageTime
          final sortedByMessageTime = [...filteredData];
          sortedByMessageTime.sort((a, b) {
            final aTime = a['lastMessageTime'] ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b['lastMessageTime'] ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          developer.log('Sorted by message time: ${sortedByMessageTime.map((m) => '${(m['user'] as UserModel).username}: ${m['lastMessageTime']}')}', name: 'MatchListScreen');

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // Chữ "Danh sách tương hợp" nhỏ phía trên avatar
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 16, bottom: 4),
                child: Text(
                  'Danh sách tương hợp',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Dãy avatar ngang - SẮP XẾP THEO matchedAt
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChatScreen(matchId: matchId, peerUser: user),
                            ),
                          );
                        },
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
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Hủy tương hợp?',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            'Bạn có chắc muốn hủy tương hợp với ${user.username}?',
                                            style: const TextStyle(
                                              color: Colors.white70,
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
                                                    color: Colors.white
                                                        .withValues(alpha: 0.7),
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
                                                  backgroundColor:
                                                      Colors.deepOrange,
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
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFee9ca7),
                                    Color(0xFFffdde1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(3),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundImage:
                                    user.avatarUrl != null &&
                                        user.avatarUrl!.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        user.avatarUrl!,
                                      )
                                    : null,
                                child: user.avatarUrl == null
                                    ? const Icon(Icons.person, size: 30)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 60,
                              child: Text(
                                user.username,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
              // Thanh tìm kiếm
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm tên...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchText = value;
                    });
                  },
                ),
              ),
              // Chữ "Tin nhắn" nhỏ phía trên danh sách chat
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 12, bottom: 4),
                child: Text(
                  'Tin nhắn',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Divider(height: 1),
              // Danh sách chat dọc - SẮP XẾP THEO lastMessageTime
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
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage:
                          user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? const Icon(Icons.person, size: 28)
                          : null,
                    ),
                    title: Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.age} tuổi • ${user.location}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (lastMessage != null)
                          Text(
                            lastMessage,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: lastMessageTime != null
                        ? Text(
                            _formatTime(lastMessageTime),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}
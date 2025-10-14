import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/user_model.dart';
import '../../core/widgets/profile_card.dart';
import '../../core/providers/match_provider.dart';
import 'chat_screen.dart';

class MatchListScreen extends StatefulWidget {
  const MatchListScreen({Key? key}) : super(key: key);

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  String searchText = '';

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.5),
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Provider.of<MatchProvider>(context).matchedUsersStream(currentUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final matchedData = snapshot.data!;
          if (matchedData.isEmpty) {
            return const Center(child: Text('Bạn chưa có match nào!'));
          }

          // Lọc theo searchText
          final filteredData = searchText.isEmpty
              ? matchedData
              : matchedData.where((m) {
                  final user = m['user'] as UserModel;
                  return user.username.toLowerCase().contains(searchText.toLowerCase());
                }).toList();

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredData.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      // Sắp xếp theo thời gian match
                      final sortedMatchList = [...filteredData];
                      sortedMatchList.sort((a, b) {
                        final aTime = a['matchedAt'] ?? DateTime.fromMillisecondsSinceEpoch(0);
                        final bTime = b['matchedAt'] ?? DateTime.fromMillisecondsSinceEpoch(0);
                        return bTime.compareTo(aTime);
                      });
                      final user = sortedMatchList[index]['user'] as UserModel;
                      final matchId = sortedMatchList[index]['matchId'] as String;
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                matchId: matchId,
                                peerUser: user,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFee9ca7), Color(0xFFffdde1)],
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
                                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                    ? CachedNetworkImageProvider(user.avatarUrl!)
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
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm tên...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
              ...(() {
                final sortedChatList = [...filteredData];
                sortedChatList.sort((a, b) {
                  final aTime = a['lastMessageTime'] ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime = b['lastMessageTime'] ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });
                return List.generate(sortedChatList.length, (index) {
                  final matchId = sortedChatList[index]['matchId'] as String;
                  final user = sortedChatList[index]['user'] as UserModel;
                  final lastMessage = sortedChatList[index]['lastMessage'] as String?;
                  final lastMessageTime = sortedChatList[index]['lastMessageTime'] as DateTime?;

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            matchId: matchId,
                            peerUser: user,
                          ),
                        ),
                      );
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null 
                            ? const Icon(Icons.person, size: 28) 
                            : null,
                      ),
                      title: Text(
                        user.username,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
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
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: lastMessageTime != null
                          ? Text(
                              _formatTime(lastMessageTime),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            )
                          : null,
                    ),
                  );
                });
              })(),
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
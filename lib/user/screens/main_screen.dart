import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'profile.dart';
import 'match_screen.dart';
import 'liked_me_screen.dart';
import 'match_list_screen.dart';
import 'moment_screen.dart';

// Màn hình chính với bottom navigation bar
// Quản lý 5 tab: Match, Moment, Liked Me, Messages, Profile
// Hiển thị badge đếm số lượt thích mới, tin nhắn chưa đọc và moments mới
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Danh sách 5 màn hình tương ứng với 5 tab
  final List<Widget> _screens = [
    MatchScreen(),
    const MomentScreen(),
    LikedMeScreen(),
    MatchListScreen(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: StreamBuilder<Map<String, int>>(
        // Stream để theo dõi realtime số lượng badge
        stream: _getBadgeCountsStream(currentUserId),
        builder: (context, snapshot) {
          final badgeCounts = snapshot.data ?? {'likes': 0, 'messages': 0, 'moments': 0};

          developer.log('Badge counts: $badgeCounts', name: 'MainScreen');

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Colors.deepOrange,
            unselectedItemColor: Colors.grey.shade600,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 4, 
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.sports_esports),
                label: 'Trang chủ',
              ),
              BottomNavigationBarItem(
                icon: _buildIconWithBadge(
                  icon: CupertinoIcons.search,
                  count: badgeCounts['moments'] ?? 0,
                ),
                label: 'Feed',
              ),
              BottomNavigationBarItem(
                icon: _buildIconWithBadge(
                  icon: CupertinoIcons.heart,
                  count: badgeCounts['likes'] ?? 0,
                ),
                label: 'Lượt thích',
              ),
              BottomNavigationBarItem(
                icon: _buildIconWithBadge(
                  icon: CupertinoIcons.chat_bubble,
                  count: badgeCounts['messages'] ?? 0,
                ),
                label: 'Tin nhắn',
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person),
                label: 'Hồ sơ',
              ),
            ],
          );
        },
      ),
    );
  }

  // Widget hiển thị icon với badge đếm số thông báo
  Widget _buildIconWithBadge({required IconData icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: Colors.grey),
        // Hiển thị badge đỏ nếu có thông báo
        if (count > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Stream kết hợp để theo dõi realtime số lượng likes, messages và moments mới
  Stream<Map<String, int>> _getBadgeCountsStream(String currentUserId) {
    if (currentUserId.isEmpty) {
      return Stream.value({'likes': 0, 'messages': 0, 'moments': 0});
    }

    // Stream theo dõi matches để đếm tin nhắn chưa đọc
    final matchesStream = FirebaseFirestore.instance
        .collection('matches')
        .where('userIds', arrayContains: currentUserId)
        .where('status', isEqualTo: 'confirmed')
        .snapshots();

    // Stream theo dõi moments mới
    final momentsStream = FirebaseFirestore.instance
        .collection('moments')
        .where('matchIds', arrayContains: currentUserId)
        .snapshots();

    // Kết hợp 2 streams để cập nhật đồng thời
    return matchesStream.asyncExpand((matchesSnapshot) {
      return momentsStream.asyncMap((momentsSnapshot) async {
        // Đếm lượt thích mới chưa match và chưa bị cancelled
        final likeSnapshot = await FirebaseFirestore.instance
            .collection('swipe_history')
            .where('targetUserId', isEqualTo: currentUserId)
            .where('action', isEqualTo: 'like')
            .get();

        // Lấy danh sách user đã match để loại trừ
        final matchedUserIds = <String>{};
        for (var doc in matchesSnapshot.docs) {
          final userIds = List<String>.from(doc['userIds'] ?? []);
          matchedUserIds.addAll(userIds.where((id) => id != currentUserId));
        }

        // Lấy danh sách user đã cancelled để loại trừ
        final cancelledSnapshot = await FirebaseFirestore.instance
            .collection('matches')
            .where('userIds', arrayContains: currentUserId)
            .where('status', isEqualTo: 'cancelled')
            .get();

        final cancelledUserIds = <String>{};
        for (var doc in cancelledSnapshot.docs) {
          final userIds = List<String>.from(doc['userIds'] ?? []);
          cancelledUserIds.addAll(userIds.where((id) => id != currentUserId));
        }

        // Đếm chỉ những like từ user chưa match và chưa cancelled
        final newLikesCount = likeSnapshot.docs.where((doc) {
          final userId = doc['userId'];
          return !matchedUserIds.contains(userId) && !cancelledUserIds.contains(userId);
        }).length;

        // Đếm tin nhắn chưa đọc trong các cuộc trò chuyện
        int unreadMessagesCount = 0;
        for (var matchDoc in matchesSnapshot.docs) {
          final matchData = matchDoc.data();
          final lastMessageTime = matchData['lastMessageTime'];
          final lastMessageSenderId = matchData['lastMessageSenderId'];
          final lastSeen = matchData['lastSeen_$currentUserId'];

          // Chỉ đếm nếu tin nhắn cuối không phải từ mình và chưa xem
          if (lastMessageTime != null &&
              lastMessageSenderId != null &&
              lastMessageSenderId != currentUserId) {
            
            // Parse thời gian tin nhắn cuối
            DateTime? lastMsgTime;
            if (lastMessageTime is Timestamp) {
              lastMsgTime = lastMessageTime.toDate();
            } else if (lastMessageTime is String) {
              lastMsgTime = DateTime.tryParse(lastMessageTime);
            }

            // Parse thời gian xem cuối
            DateTime? lastSeenTime;
            if (lastSeen is Timestamp) {
              lastSeenTime = lastSeen.toDate();
            } else if (lastSeen is String) {
              lastSeenTime = DateTime.tryParse(lastSeen);
            }

            // So sánh thời gian để xác định tin nhắn chưa đọc
            if (lastMsgTime != null) {
              if (lastSeenTime == null || lastMsgTime.isAfter(lastSeenTime)) {
                unreadMessagesCount++;
              }
            }
          }
        }

        // Đếm moments mới chưa xem
        int newMomentsCount = 0;
        
        try {
          // Lấy thời gian xem moments lần cuối từ user document
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();
          
          DateTime? lastSeenMoments;
          if (userDoc.exists) {
            final lastSeen = userDoc.data()?['lastSeenMoments'];
            if (lastSeen is Timestamp) {
              lastSeenMoments = lastSeen.toDate();
            } else if (lastSeen is String) {
              lastSeenMoments = DateTime.tryParse(lastSeen);
            }
          }

          // Đếm moments được tạo sau lần xem cuối
          if (lastSeenMoments != null) {
            newMomentsCount = momentsSnapshot.docs.where((doc) {
              final data = doc.data();
              final userId = data['userId'];
              final createdAt = data['createdAt'];
              
              // Bỏ qua moments của chính mình
              if (userId == currentUserId) return false;
              
              // So sánh thời gian tạo với thời gian xem cuối
              if (createdAt is Timestamp) {
                return createdAt.toDate().isAfter(lastSeenMoments!);
              }
              return false;
            }).length;
          } else {
            // Nếu chưa từng xem, đếm tất cả moments của người khác
            newMomentsCount = momentsSnapshot.docs
                .where((doc) => doc.data()['userId'] != currentUserId)
                .length;
          }

          developer.log('New moments count: $newMomentsCount', name: 'MainScreen.Badge');
        } catch (e) {
          developer.log('Error counting moments: $e', name: 'MainScreen.Badge', error: e);
          newMomentsCount = 0;
        }

        // Trả về map chứa số lượng badge cho cả 3 tab
        return {
          'likes': newLikesCount,
          'messages': unreadMessagesCount,
          'moments': newMomentsCount,
        };
      });
    });
  }
}
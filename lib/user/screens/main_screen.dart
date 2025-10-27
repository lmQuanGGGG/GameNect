import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gamenect_new/core/providers/chat_provider.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'profile.dart';
import 'match_screen.dart';
import 'liked_me_screen.dart';
import 'match_list_screen.dart';
import 'moment_screen.dart';
import 'dart:async';
import '../../core/models/user_model.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    MatchScreen(),
    const MomentScreen(),
    LikedMeScreen(),
    MatchListScreen(),
    const ProfilePage(),
  ];

  List<StreamSubscription> _messageSubscriptions = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        // Lấy danh sách matchId và peerUser từ Firestore
        final matchesSnapshot = await FirebaseFirestore.instance
            .collection('matches')
            .where('userIds', arrayContains: currentUserId)
            .where('status', isEqualTo: 'confirmed')
            .get();

        for (var doc in matchesSnapshot.docs) {
          final matchId = doc.id;
          final userIds = List<String>.from(doc['userIds'] ?? []);
          final peerId = userIds.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );
          if (peerId != null) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(peerId).get();
            if (userDoc.exists) {
              final peerUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
              // Gọi messagesStream để lắng nghe tin nhắn mới, KHÔNG ảnh hưởng UI
              final sub = chatProvider.messagesStream(matchId, peerUser).listen((_) {});
              _messageSubscriptions.add(sub);
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    for (final sub in _messageSubscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: StreamBuilder<Map<String, int>>(
        stream: _getBadgeCountsStream(currentUserId),
        builder: (context, snapshot) {
          final badgeCounts = snapshot.data ?? {'likes': 0, 'messages': 0, 'moments': 0};

          developer.log('Badge counts: $badgeCounts', name: 'MainScreen');

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Colors.deepOrange,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
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

  Widget _buildIconWithBadge({required IconData icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: Colors.grey),
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

  Stream<Map<String, int>> _getBadgeCountsStream(String currentUserId) {
  if (currentUserId.isEmpty) {
    return Stream.value({'likes': 0, 'messages': 0, 'moments': 0});
  }

  // Kết hợp 2 streams: matches và moments
  final matchesStream = FirebaseFirestore.instance
      .collection('matches')
      .where('userIds', arrayContains: currentUserId)
      .where('status', isEqualTo: 'confirmed')
      .snapshots();

  final momentsStream = FirebaseFirestore.instance
      .collection('moments')
      .where('matchIds', arrayContains: currentUserId)
      .snapshots();

  // Combine 2 streams
  return matchesStream.asyncExpand((matchesSnapshot) {
    return momentsStream.asyncMap((momentsSnapshot) async {
      // 1. Đếm lượt thích mới (chưa match VÀ chưa cancelled)
      final likeSnapshot = await FirebaseFirestore.instance
          .collection('swipe_history')
          .where('targetUserId', isEqualTo: currentUserId)
          .where('action', isEqualTo: 'like')
          .get();

      // Lấy danh sách user đã match (confirmed)
      final matchedUserIds = <String>{};
      for (var doc in matchesSnapshot.docs) {
        final userIds = List<String>.from(doc['userIds'] ?? []);
        matchedUserIds.addAll(userIds.where((id) => id != currentUserId));
      }

      // Lấy danh sách user đã cancelled
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

      // Đếm chỉ những user chưa match VÀ chưa cancelled
      final newLikesCount = likeSnapshot.docs.where((doc) {
        final userId = doc['userId'];
        return !matchedUserIds.contains(userId) && !cancelledUserIds.contains(userId);
      }).length;

      // 2. Đếm tin nhắn chưa đọc
      int unreadMessagesCount = 0;
      for (var matchDoc in matchesSnapshot.docs) {
        final matchData = matchDoc.data();
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

      // 3. Đếm moments mới chưa xem (dùng momentsSnapshot từ stream)
      int newMomentsCount = 0;
      
      try {
        // Lấy thời gian xem moments lần cuối
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

        // Lọc moments từ snapshot
        if (lastSeenMoments != null) {
          newMomentsCount = momentsSnapshot.docs.where((doc) {
            final data = doc.data();
            final userId = data['userId'];
            final createdAt = data['createdAt'];
            
            // Bỏ qua moments của chính mình
            if (userId == currentUserId) return false;
            
            // So sánh thời gian
            if (createdAt is Timestamp) {
              return createdAt.toDate().isAfter(lastSeenMoments!); // THÊM ! để assert non-null
            }
            return false;
          }).length;
        } else {
          // Nếu chưa có lastSeenMoments, đếm tất cả moments (trừ của mình)
          newMomentsCount = momentsSnapshot.docs
              .where((doc) => doc.data()['userId'] != currentUserId)
              .length;
        }

        developer.log('New moments count: $newMomentsCount', name: 'MainScreen.Badge');
      } catch (e) {
        developer.log('Error counting moments: $e', name: 'MainScreen.Badge', error: e);
        newMomentsCount = 0;
      }

      return {
        'likes': newLikesCount,
        'messages': unreadMessagesCount,
        'moments': newMomentsCount,
      };
    });
  });
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart'; // Thư viện hỗ trợ kết hợp nhiều stream
import 'dart:developer' as developer;

// MatchProvider quản lý logic ghép đôi, đề xuất người dùng, lịch sử swipe, các stream liên quan đến match và swipe.
class MatchProvider with ChangeNotifier {
  // Danh sách đề xuất người dùng cho currentUser
  List<UserModel> _recommendations = [];
  // Trạng thái đang tải dữ liệu
  bool _isLoading = false;

  // Getter trả về danh sách đề xuất
  List<UserModel> get recommendations => _recommendations;
  // Getter trả về trạng thái loading
  bool get isLoading => _isLoading;

  // Hàm lấy danh sách đề xuất người dùng dựa trên bộ lọc và gọi API recommend
  Future<void> fetchRecommendations(
    UserModel currentUser,
    List<UserModel> candidateUsers,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Lọc theo tuổi, giới tính, khoảng cách
      final minAge = currentUser.minAge;
      final maxAge = currentUser.maxAge;
      final interestedInGender = currentUser.interestedInGender;
      final maxDistance = currentUser.maxDistance;

      debugPrint('Filter settings: Age[$minAge-$maxAge], Gender[$interestedInGender], Distance[<=$maxDistance km]');
      debugPrint('Current User Location: (${currentUser.latitude}, ${currentUser.longitude})');

      // Lấy danh sách user đã swipe
      final swipedUserIds = await FirestoreService().getSwipedUserIds(currentUser.id);
      debugPrint('Already swiped users: ${swipedUserIds.length}');

      // Tính khoảng cách cho tất cả candidates
      for (var user in candidateUsers) {
        if (user.latitude != null && user.longitude != null &&
            currentUser.latitude != null && currentUser.longitude != null) {
          user.distanceKm = calculateDistance(
            currentUser.latitude!, currentUser.longitude!,
            user.latitude!, user.longitude!,
          );
        } else {
          user.distanceKm = null;
        }
      }

      // Lọc user: chưa swipe, đúng tuổi, giới tính, khoảng cách, có chung game
      final filteredCandidates = candidateUsers.where((user) {
        final notSwiped = !swipedUserIds.contains(user.id);
        final ageOk = user.age >= minAge && user.age <= maxAge;
        final notCurrentUser = user.id != currentUser.id; 
        final genderOk = interestedInGender == 'Tất cả' || user.gender == interestedInGender;
        final distanceOk = user.distanceKm == null || user.distanceKm! <= maxDistance;

        // THÊM ĐIỀU KIỆN CHUNG GAME
        final hasCommonGame = user.favoriteGames.any((game) => currentUser.favoriteGames.contains(game));

        return notCurrentUser && notSwiped && ageOk && genderOk && distanceOk && hasCommonGame;
      }).toList();

      debugPrint('Filtered candidates: ${filteredCandidates.length}/${candidateUsers.length}');

      // Chuẩn bị dữ liệu gửi lên API
      final url = Uri.parse('https://web-production-188ce.up.railway.app/recommend');
      final currentUserMap = currentUser.toMap();
      if (currentUserMap.containsKey('id')) {
        currentUserMap['user_id'] = currentUserMap['id'];
        currentUserMap.remove('id');
      }

      final candidateUsersList = filteredCandidates.map((user) {
        final userMap = user.toMap();
        if (userMap.containsKey('id')) {
          userMap['user_id'] = userMap['id'];
          userMap.remove('id');
        }
        return userMap;
      }).toList();

      final body = json.encode({
        'current_user': currentUserMap,
        'candidate_users': candidateUsersList,
      });

      // Gửi request lên API recommend
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      debugPrint('API status: ${response.statusCode}');
      debugPrint('API body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> recs = data['recommendations'] ?? [];
        List<UserModel> temp = [];
        
        debugPrint('Processing ${recs.length} recommendations from API');
        debugPrint('=========================================');
        
        for (var e in recs) {
          debugPrint('---');
          debugPrint('User ID from API: ${e['user_id']}');
          debugPrint('Distance from API: ${e['distance_km']} km (will be recalculated)');
          
          final userMap = await FirestoreService().getUserMapById(e['user_id']);
          if (userMap != null) {
            final user = UserModel.fromMap(userMap, e['user_id']);
            
            // Tính lại khoảng cách cho user này
            if (user.latitude != null && user.longitude != null &&
                currentUser.latitude != null && currentUser.longitude != null) {
              user.distanceKm = calculateDistance(
                currentUser.latitude!, currentUser.longitude!,
                user.latitude!, user.longitude!,
              );
              
              debugPrint('User: ${user.username}');
              debugPrint('Location: (${user.latitude}, ${user.longitude})');
              debugPrint('REAL Distance: ${user.distanceKm?.toStringAsFixed(1)} km');
              debugPrint('Max Distance: $maxDistance km');
              
              // Kiểm tra lại điều kiện khoảng cách
              if (user.distanceKm! <= maxDistance) {
                temp.add(user);
                debugPrint('ADDED to recommendations');
              } else {
                debugPrint('REJECTED: Too far (${user.distanceKm?.toStringAsFixed(1)} km > $maxDistance km)');
              }
            } else {
              debugPrint('User: ${user.username}');
              debugPrint('No coordinates: lat=${user.latitude}, lon=${user.longitude}');
              debugPrint('REJECTED: Missing location data');
            }
          }
        }
        
        debugPrint('=========================================');
        debugPrint('Final recommendations count: ${temp.length}/${recs.length}');
        
        _recommendations = temp;
      } else {
        _recommendations = [];
      }
    } catch (e) {
      debugPrint('Lỗi gọi API: $e');
      _recommendations = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Hàm xóa danh sách đề xuất
  void clearRecommendations() {
    _recommendations = [];
    notifyListeners();
  }

  // Hàm tính khoảng cách giữa hai tọa độ (Haversine)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // bán kính Trái Đất km
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // Lưu lịch sử swipe (like/dislike), kiểm tra match, tạo match mới nếu like đôi bên
  Future<void> saveSwipeHistory(String currentUserId, UserModel targetUser, bool isLike) async {
    try {
      await FirestoreService().saveSwipeHistory(
        userId: currentUserId,
        targetUserId: targetUser.id,
        action: isLike ? 'like' : 'dislike',
      );

      // Kiểm tra nếu cả hai cùng like thì tạo match mới
      final isMutual = await FirestoreService().checkMutualLike(
        userId: currentUserId,
        targetUserId: targetUser.id,
      );
      if (isMutual) {
        if (currentUserId != targetUser.id) {
          await FirestoreService().createNewMatch(
            userIds: [currentUserId, targetUser.id],
            game: 'Tên game',
            expiresAt: DateTime.now().add(const Duration(hours: 24)),
          );
        }
        // Hiển thị dialog match thành công
      }
    } catch (e) {
      debugPrint('Error saving swipe history: $e');
    }
  }

  // Lấy danh sách người dùng chưa bị swipe bởi currentUser
  Future<List<UserModel>> fetchFilteredUsers(String currentUserId) async {
    try {
      // Lấy danh sách tất cả người dùng từ Firestore
      final allUsers = await FirestoreService().getAllUsers();

      // Lọc những người dùng đã vuốt (swiped) bởi người dùng hiện tại
      final swipedUserIds = await FirestoreService().getSwipedUserIds(currentUserId);
      final filteredUsers = allUsers.where((u) =>
        u.id != currentUserId && !swipedUserIds.contains(u.id)
      ).toList();

      return filteredUsers;
    } catch (e) {
      debugPrint('Error fetching filtered users: $e');
      return [];
    }
  }

  // Lấy lịch sử dislike, giới hạn số lượng theo loại tài khoản
  Future<void> fetchDislikeHistory(UserModel currentUser, BuildContext context) async {
    try {
      final isPremium = currentUser.isPremium;
      final limit = isPremium ? 1000 : 10;
      final dislikeHistory = await FirestoreService().getDislikeHistory(currentUser.id, limit: limit);

      debugPrint('Dislike history: $dislikeHistory');

      if (!isPremium && dislikeHistory.length >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tài khoản chưa mua gói chỉ xem được tối đa 10 người đã dislike/match bạn.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching dislike history: $e');
    }
  }

  // Lấy danh sách người đã like mình nhưng chưa match
  Future<List<UserModel>> fetchLikedMeUsers(String currentUserId, {int limit = 20}) async {
    try {
      final likedMeHistory = await FirestoreService().getLikedMeHistory(currentUserId, limit: limit);
      final userIds = likedMeHistory.map((h) => h.userId).toList();

      // Lấy danh sách user đã match với mình
      final matchedUserIds = await FirestoreService().getMatchedUserIds(currentUserId);

      // Lọc bỏ những user đã match
      final filteredUserIds = userIds.where((id) => !matchedUserIds.contains(id)).toList();

      List<UserModel> users = [];
      for (final id in filteredUserIds) {
        final user = await FirestoreService().getUser(id);
        if (user != null) users.add(user);
      }
      return users;
    } catch (e) {
      debugPrint('Error fetching liked me users: $e');
      return [];
    }
  }

  // Lấy danh sách user đã match kèm matchId và tin nhắn cuối cùng
  Future<List<Map<String, dynamic>>> fetchMatchedUsersWithMatchId(String currentUserId) async {
  try {
    final matchDocs = await FirestoreService().getMatchDocsForUser(currentUserId);
    List<Map<String, dynamic>> result = [];

    for (var matchDoc in matchDocs) {
      final data = matchDoc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final userIds = List<String>.from(data['userIds'] ?? []);
      final peerUserId = userIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      if (peerUserId.isEmpty) continue;

      final user = await FirestoreService().getUser(peerUserId);

      // LẤY TIN NHẮN CUỐI CÙNG TỪ CHATS
      final lastMsg = await FirestoreService().getLastMessage(matchDoc.id);
      String? lastMessage;
      DateTime? lastMessageTime;
      if (lastMsg != null) {
        lastMessage = lastMsg['text'] as String?;
        lastMessageTime = (lastMsg['timestamp'] as Timestamp?)?.toDate();
      }

      if (user != null) {
        result.add({
          'matchId': matchDoc.id,
          'user': user,
          'lastMessage': lastMessage,
          'lastMessageTime': lastMessageTime,
        });
      }
    }

    // SẮP XẾP THEO THỜI GIAN TIN NHẮN MỚI NHẤT
    result.sort((a, b) {
      final aTime = a['lastMessageTime'] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b['lastMessageTime'] ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return result;
  } catch (e) {
    debugPrint('Error fetching matched users: $e');
    return [];
  }
}

  // Stream danh sách user đã match, kèm thông tin tin nhắn cuối cùng
  Stream<List<Map<String, dynamic>>> matchedUsersStream(String currentUserId) {
    final matchQuery = FirebaseFirestore.instance
        .collection('matches')
        .where('userIds', arrayContains: currentUserId)
        .where('status', isEqualTo: 'confirmed')
        .snapshots();

    return matchQuery.switchMap((matchSnap) {
      if (matchSnap.docs.isEmpty) return Stream.value([]);

      final streams = matchSnap.docs.map((doc) {
        final matchId = doc.id;
        final userIds = List<String>.from(doc['userIds'] ?? []);
        final peerId = userIds.firstWhere((id) => id != currentUserId, orElse: () => '');
        final userFuture = FirestoreService().getUser(peerId);

        // Stream lấy message cuối cùng
        final msgStream = FirebaseFirestore.instance
    .collection('chats')
    .doc(matchId)
    .collection('messages')
    .orderBy('timestamp', descending: true)
    .limit(1)
    .snapshots()
    .asyncMap((msgSnap) async {
      String? lastMessage;
      DateTime? lastMessageTime;
      if (msgSnap.docs.isNotEmpty) {
        final msg = msgSnap.docs.first.data();
        lastMessageTime = (msg['timestamp'] as Timestamp?)?.toDate();
        
        final msgType = msg['type'] ?? 'text';
        final senderId = msg['senderId'];
        final isMe = senderId == currentUserId; // ← Kiểm tra ai gửi
        
        switch (msgType) {
          case 'call':
            if (msg['callStatus'] == 'missed') {
              lastMessage = isMe ? 'Bạn: Cuộc gọi nhỡ' : 'Cuộc gọi nhỡ';
            } else if (msg['callStatus'] == 'declined') {
              lastMessage = isMe ? 'Bạn: Cuộc gọi bị từ chối' : 'Cuộc gọi bị từ chối';
            } else if (msg['callStatus'] == 'cancelled') {
              lastMessage = isMe ? 'Bạn: Đã hủy' : 'Đã hủy';
            } else {
              final duration = msg['duration'] ?? 0;
              lastMessage = isMe 
                ? 'Bạn: Đã gọi ${_formatDuration(duration)}'
                : 'Đã gọi ${_formatDuration(duration)}';
            }
            break;
          
          case 'voice':
            lastMessage = isMe 
              ? 'Bạn: Đã gửi tin nhắn thoại' 
              : 'Đã gửi tin nhắn thoại';
            break;
          
          case 'react':
            final emoji = msg['emoji'] ?? '❤️';
            lastMessage = isMe 
              ? 'Bạn: Đã thả cảm xúc $emoji'
              : 'Đã thả cảm xúc $emoji';
            break;
          
          case 'media':
            final isVideo = msg['isVideo'] ?? false;
            if (isMe) {
              lastMessage = isVideo ? 'Bạn: Đã gửi video' : 'Bạn: Đã gửi hình ảnh';
            } else {
              lastMessage = isVideo ? 'Đã gửi video' : 'Đã gửi hình ảnh';
            }
            break;
          
          default:
            // Tin nhắn văn bản thông thường
            final text = msg['text'] ?? '';
            lastMessage = isMe ? 'Bạn: $text' : text;
        }
      }
      final user = await userFuture;
      return {
        'user': user,
        'matchId': matchId,
        'matchedAt': (doc['matchedAt'] as Timestamp?)?.toDate(),
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime,
      };
    });
        return msgStream;
      }).toList();

      return Rx.combineLatestList(streams);
    });
  }

  // Hàm format thời lượng cuộc gọi sang dạng phút/giây
  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds giây';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return sec == 0 ? '$min phút' : '$min:${sec.toString().padLeft(2, '0')} phút';
  }

  // Stream danh sách người đã like mình nhưng chưa match hoặc đã bị hủy match
  Stream<List<UserModel>> streamLikedMeUsers(String currentUserId, {int limit = 20}) {
  // Stream các thay đổi của swipe_history
  final swipeStream = FirebaseFirestore.instance
      .collection('swipe_history')
      .where('targetUserId', isEqualTo: currentUserId)
      .where('action', isEqualTo: 'like')
      .limit(limit)
      .snapshots();

  // Stream các thay đổi của matches
  final matchStream = FirebaseFirestore.instance
      .collection('matches')
      .where('userIds', arrayContains: currentUserId)
      .where('status', isEqualTo: 'confirmed') // CHỈ LẤY CONFIRMED
      .snapshots();

  // Kết hợp 2 stream để luôn cập nhật khi có match mới hoặc swipe mới
  return Rx.combineLatest2(swipeStream, matchStream, (QuerySnapshot swipeSnap, QuerySnapshot matchSnap) async {
    // Lấy danh sách user đã match CONFIRMED với mình
    final matchedUserIds = <String>{};
    for (var doc in matchSnap.docs) {
      final userIds = List<String>.from(doc['userIds'] ?? []);
      matchedUserIds.addAll(userIds.where((id) => id != currentUserId));
    }

    // THÊM: Lấy danh sách user đã unmatch (cancelled)
    final cancelledMatchSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('userIds', arrayContains: currentUserId)
        .where('status', isEqualTo: 'cancelled')
        .get();
    
    final cancelledUserIds = <String>{};
    for (var doc in cancelledMatchSnap.docs) {
      final userIds = List<String>.from(doc['userIds'] ?? []);
      cancelledUserIds.addAll(userIds.where((id) => id != currentUserId));
    }

    // Lấy danh sách user đã thích mình nhưng chưa match VÀ chưa bị cancelled
    final users = <UserModel>[];
    for (var doc in swipeSnap.docs) {
      final userId = doc['userId'];
      
      // BỎ QUA user đã match HOẶC đã cancelled
      if (matchedUserIds.contains(userId) || cancelledUserIds.contains(userId)) {
        continue;
      }
      
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        users.add(UserModel.fromMap(userDoc.data()!, userId));
      }
    }
    
    developer.log('Liked me users: ${users.length} (excluded ${matchedUserIds.length} matched + ${cancelledUserIds.length} cancelled)', name: 'MatchProvider');
    
    return users;
  }).asyncMap((f) => f).asBroadcastStream();
}

  // Stream danh sách người mình đã dislike, loại bỏ những người đã match hoặc đã hủy match
  Stream<List<UserModel>> streamMyDislikedUsers(String currentUserId, {int limit = 100}) {
  final swipeStream = FirebaseFirestore.instance
      .collection('swipe_latest')
      .where('userId', isEqualTo: currentUserId)
      .where('action', isEqualTo: 'dislike')
      .limit(limit)
      .snapshots();

  final matchStream = FirebaseFirestore.instance
      .collection('matches')
      .where('userIds', arrayContains: currentUserId)
      .snapshots(); // ← Lấy TẤT CẢ matches (confirmed + cancelled) 1 lần

  return Rx.combineLatest2(swipeStream, matchStream,
      (QuerySnapshot swipeSnap, QuerySnapshot matchSnap) async {
    // Lọc confirmed và cancelled từ cùng 1 snapshot
    final matchedUserIds = <String>{};
    final cancelledUserIds = <String>{};
    
    for (var doc in matchSnap.docs) {
      final status = doc['status'];
      final ids = List<String>.from(doc['userIds'] ?? []);
      final otherIds = ids.where((id) => id != currentUserId);
      
      if (status == 'confirmed') {
        matchedUserIds.addAll(otherIds);
      } else if (status == 'cancelled') {
        cancelledUserIds.addAll(otherIds);
      }
    }

    final users = <UserModel>[];
    for (var doc in swipeSnap.docs) {
      final targetId = doc['targetUserId'];
      if (matchedUserIds.contains(targetId) || cancelledUserIds.contains(targetId)) continue;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(targetId).get();
      if (userDoc.exists) {
        users.add(UserModel.fromMap(userDoc.data()!, targetId));
      }
    }

    developer.log('My disliked users: ${users.length}', name: 'MatchProvider');
    return users;
  }).asyncMap((f) => f).asBroadcastStream(); // ← ĐÃ CÓ broadcast
}

  // Hàm hủy match giữa hai người dùng
  Future<void> unmatch(String matchId) async {
    await FirestoreService().unmatch(matchId);
    notifyListeners();
  }
}
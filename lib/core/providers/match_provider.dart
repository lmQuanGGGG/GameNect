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

  void setRecommendations(List<UserModel> users) {
    _recommendations = users;
    notifyListeners();
  }

  void removeRecommendation(String userId) {
    _recommendations.removeWhere((u) => u.id == userId);
    notifyListeners();
  }

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

      debugPrint(
        'Filter settings: Age[$minAge-$maxAge], Gender[$interestedInGender], Distance[<=$maxDistance km]',
      );
      debugPrint(
        'Current User Location: (${currentUser.latitude}, ${currentUser.longitude})',
      );

      // Lấy danh sách user đã swipe
      final swipedUserIds = await FirestoreService().getSwipedUserIds(
        currentUser.id,
      );
      debugPrint('Already swiped users: ${swipedUserIds.length}');

      // Tính khoảng cách cho tất cả candidates
      for (var user in candidateUsers) {
        if (user.latitude != null &&
            user.longitude != null &&
            currentUser.latitude != null &&
            currentUser.longitude != null) {
          user.distanceKm = calculateDistance(
            currentUser.latitude!,
            currentUser.longitude!,
            user.latitude!,
            user.longitude!,
          );
        } else {
          user.distanceKm = null;
        }
      }

      // Lọc cứng: bỏ user đã swipe, không đúng giới tính, vượt khoảng cách tối đa
      // filterCommonGame = true → chỉ lấy người có chung ít nhất 1 game (user tự chọn)
      final filterGame = currentUser.filterCommonGame;
      final filteredCandidates = candidateUsers.where((user) {
        final notCurrentUser = user.id != currentUser.id;
        final notSwiped = !swipedUserIds.contains(user.id);
        final ageOk = user.age >= minAge && user.age <= maxAge;
        final genderOk =
            interestedInGender == 'Tất cả' || user.gender == interestedInGender;
        final distanceOk =
            user.distanceKm == null || user.distanceKm! <= maxDistance;
        // Game filter — chỉ áp dụng khi user bật tùy chọn này
        final gameOk =
            !filterGame ||
            user.favoriteGames.any(currentUser.favoriteGames.contains);
        return notCurrentUser &&
            notSwiped &&
            ageOk &&
            genderOk &&
            distanceOk &&
            gameOk;
      }).toList();

      final withCommonGame = filteredCandidates
          .where((u) => u.favoriteGames.any(currentUser.favoriteGames.contains))
          .length;
      debugPrint(
        'Filtered: ${filteredCandidates.length}/${candidateUsers.length} '
        '(chung game: $withCommonGame | filterGame=$filterGame)',
      );

      // Chuẩn bị dữ liệu gửi lên API
      final url = Uri.parse(
        'https://web-production-188ce.up.railway.app/recommend',
      );
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
      // debugPrint('API body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> recs = data['recommendations'] ?? [];
        List<UserModel> temp = [];

        debugPrint('Processing ${recs.length} recommendations from API');
        debugPrint('=========================================');

        for (var e in recs) {
          final String userId = e['user_id'];
          // Lấy điểm từ AI (hỗ trợ nhiều format key)
          // Nếu không có key nào → null (không lọc theo score, chấp nhận tất cả)
          final num? rawScore =
              e['score'] ?? e['match_score'] ?? e['compatibility_score'];
          final double? score = rawScore?.toDouble();

          debugPrint('---');
          debugPrint('User ID from API: $userId, Score: $score');

          // Nếu API không trả score → chấp nhận luôn (không lọc)
          // Nếu có score: hệ 1 (0.0–1.0) thì ngưỡng 0.5, hệ 100 thì ngưỡng 50.0
          bool passScore = true;
          if (score != null) {
            final double threshold = (score <= 1.0) ? 0.5 : 50.0;
            passScore = score >= threshold;
          }

          if (passScore) {
            // TỐI ƯU: Tìm trực tiếp trong danh sách filteredCandidates đã lọc
            try {
              final user = filteredCandidates.firstWhere((u) => u.id == userId);
              temp.add(user);
              debugPrint(
                'ADDED to recommendations: ${user.username} - Distance: ${user.distanceKm?.toStringAsFixed(1)} km',
              );
            } catch (_) {
              debugPrint(
                'REJECTED: User $userId không tìm thấy trong filteredCandidates',
              );
            }
          } else {
            final double threshold = (score! <= 1.0) ? 0.5 : 50.0;
            debugPrint(
              'REJECTED: User $userId bị loại vì điểm số quá thấp ($score < $threshold)',
            );
          }
        }

        debugPrint('=========================================');
        debugPrint(
          'Final recommendations count: ${temp.length}/${recs.length}',
        );

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
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // Lưu lịch sử swipe (like/dislike), kiểm tra match, tạo match mới nếu like đôi bên
  Future<void> saveSwipeHistory(
    String currentUserId,
    UserModel targetUser,
    bool isLike,
  ) async {
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
          // Kiem tra xem da co match ton tai chua de tranh bug bam 2 lan tao ra 2 cuoc hoi thoai
          final existingMatch = await FirestoreService().getMatchBetweenUsers(
            currentUserId,
            targetUser.id,
          );
          if (existingMatch == null) {
            await FirestoreService().createNewMatch(
              userIds: [currentUserId, targetUser.id],
              game: 'Tên game',
              expiresAt: DateTime.now().add(const Duration(hours: 24)),
            );
          }
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
      final currentUser = await FirestoreService().getUser(currentUserId);
      if (currentUser == null) return [];

      if (currentUser.latitude == null || currentUser.longitude == null) {
        developer.log(
          'Bỏ qua fetchFilteredUsers vì user chưa có tọa độ đã lưu',
          name: 'MatchProvider',
        );
        return [];
      }

      final candidateUsers = await FirestoreService().getUsersWithinRadius(
        latitude: currentUser.latitude!,
        longitude: currentUser.longitude!,
        radiusKm: currentUser.maxDistance,
        excludeUserId: currentUserId,
        limit: 100,
      );

      // Lọc những người dùng đã vuốt (swiped) bởi người dùng hiện tại
      final swipedUserIds = await FirestoreService().getSwipedUserIds(
        currentUserId,
      );
      final filteredUsers = candidateUsers
          .where((u) => u.id != currentUserId && !swipedUserIds.contains(u.id))
          .toList();

      return filteredUsers;
    } catch (e) {
      debugPrint('Error fetching filtered users: $e');
      return [];
    }
  }

  // Lấy lịch sử dislike, giới hạn số lượng theo loại tài khoản
  Future<void> fetchDislikeHistory(
    UserModel currentUser,
    BuildContext context,
  ) async {
    try {
      final isPremium = currentUser.isPremium ?? false;
      final limit = isPremium ? 1000 : 10;
      final dislikeHistory = await FirestoreService().getDislikeHistory(
        currentUser.id,
        limit: limit,
      );

      debugPrint('Dislike history: $dislikeHistory');

      if (!isPremium && dislikeHistory.length >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tài khoản chưa mua gói chỉ xem được tối đa 10 người đã dislike/match bạn.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching dislike history: $e');
    }
  }

  // Lấy danh sách người đã like mình nhưng chưa match
  Future<List<UserModel>> fetchLikedMeUsers(
    String currentUserId, {
    int limit = 20,
  }) async {
    try {
      final likedMeHistory = await FirestoreService().getLikedMeHistory(
        currentUserId,
        limit: limit,
      );
      final userIds = likedMeHistory.map((h) => h.userId).toList();

      // Lấy danh sách user đã match với mình
      final matchedUserIds = await FirestoreService().getMatchedUserIds(
        currentUserId,
      );

      // Lọc bỏ những user đã match
      final filteredUserIds = userIds
          .where((id) => !matchedUserIds.contains(id))
          .toList();

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
  Future<List<Map<String, dynamic>>> fetchMatchedUsersWithMatchId(
    String currentUserId,
  ) async {
    try {
      final matchDocs = await FirestoreService().getMatchDocsForUser(
        currentUserId,
      );
      final futures = matchDocs.map((matchDoc) async {
        final data = matchDoc.data() as Map<String, dynamic>?;
        if (data == null) return null;

        final userIds = List<String>.from(data['userIds'] ?? []);
        final peerUserId = userIds.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );
        if (peerUserId.isEmpty) return null;

        UserModel? user;
        if (_userCache.containsKey(peerUserId)) {
          user = _userCache[peerUserId];
        } else {
          user = await FirestoreService().getUser(peerUserId);
          if (user != null) {
            _userCache[peerUserId] = user;
          }
        }

        // LẤY TIN NHẮN CUỐI CÙNG TỪ CHATS
        final lastMsg = await FirestoreService().getLastMessage(matchDoc.id);
        String? lastMessage;
        DateTime? lastMessageTime;
        if (lastMsg != null) {
          lastMessage = lastMsg['text'] as String?;
          lastMessageTime = (lastMsg['timestamp'] as Timestamp?)?.toDate();
        }

        if (user != null) {
          return <String, dynamic>{
            'matchId': matchDoc.id,
            'user': user,
            'lastMessage': lastMessage,
            'lastMessageTime': lastMessageTime,
            'lastMessageRead': data['lastMessageRead'] ?? true,
            'lastMessageSenderId': data['lastMessageSenderId'] ?? '',
          };
        }
        return null;
      });

      final results = await Future.wait(futures);
      final list = results.whereType<Map<String, dynamic>>().toList();

      // SẮP XẾP THEO THỜI GIAN TIN NHẮN MỚI NHẤT
      list.sort((a, b) {
        final aTime =
            a['lastMessageTime'] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b['lastMessageTime'] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return list;
    } catch (e) {
      debugPrint('Error fetching matched users: $e');
      return [];
    }
  }

  // Cache thông tin user để tránh query lại nhiều lần khi stream cập nhật
  final Map<String, UserModel> _userCache = {};

  // Stream danh sách user đã match, kèm thông tin tin nhắn cuối cùng lấy trực tiếp từ match doc
  Stream<List<Map<String, dynamic>>> matchedUsersStream(String currentUserId) {
    final matchQuery = FirebaseFirestore.instance
        .collection('matches')
        .where('userIds', arrayContains: currentUserId)
        .where('status', isEqualTo: 'confirmed')
        .snapshots();

    return matchQuery.asyncMap((matchSnap) async {
      if (matchSnap.docs.isEmpty) return [];

      final futures = matchSnap.docs.map((doc) async {
        final data = doc.data();
        final matchId = doc.id;
        final userIds = List<String>.from(data['userIds'] ?? []);
        final peerId = userIds.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        UserModel? user;
        if (_userCache.containsKey(peerId)) {
          user = _userCache[peerId];
        } else {
          user = await FirestoreService().getUser(peerId);
          if (user != null) {
            _userCache[peerId] = user;
          }
        }

        String? lastMessage = data['lastMessage'] as String?;
        final lastMessageTime = (data['lastMessageTime'] as Timestamp?)
            ?.toDate();
        final lastMessageSenderId =
            data['lastMessageSenderId'] as String? ?? '';
        final lastSeenMe = (data['lastSeen_$currentUserId'] as Timestamp?)
            ?.toDate();

        // Tính toán trạng thái đã đọc
        bool lastMessageRead = true;
        if (data.containsKey('lastMessageRead')) {
          lastMessageRead = data['lastMessageRead'] == true;
        }
        if (lastSeenMe != null && lastMessageTime != null) {
          lastMessageRead = !lastSeenMe.isBefore(lastMessageTime);
        }

        final isMe = lastMessageSenderId == currentUserId;

        // Xử lý tiền tố "Bạn: " cho lastMessage
        if (lastMessage != null && lastMessage.isNotEmpty) {
          if (isMe && !lastMessage.startsWith('Bạn: ')) {
            // Trường hợp gửi media, game, call thường set cứng text, thêm "Bạn: " vào trước
            // Tin nhắn text do user tự gõ cũng cần "Bạn: " nếu isMe
            // Ví dụ "Đã gửi video" -> "Bạn: Đã gửi video"
            // Ví dụ "Alo" -> "Bạn: Alo"
            lastMessage = 'Bạn: $lastMessage';
          }
        }

        // Xử lý ẩn chat nếu user đã xóa hội thoại
        final clearedAt = (data['clearedAt_$currentUserId'] as Timestamp?)
            ?.toDate();
        if (clearedAt != null &&
            lastMessageTime != null &&
            !lastMessageTime.isAfter(clearedAt)) {
          lastMessage = null;
        }

        return {
          'matchId': matchId,
          'user': user,
          'matchedAt': (data['matchedAt'] as Timestamp?)?.toDate(),
          'lastMessage': lastMessage,
          'lastMessageTime': lastMessageTime,
          'lastMessageRead': lastMessageRead,
          'lastMessageSenderId': lastMessageSenderId,
        };
      });

      final list = await Future.wait(futures);
      return list.where((item) => item['user'] != null).toList();
    });
  }

  // Stream danh sách người đã like mình nhưng chưa match hoặc đã bị hủy match
  Stream<List<UserModel>> streamLikedMeUsers(
    String currentUserId, {
    int limit = 20,
  }) {
    // Stream các thay đổi của swipe_history (người khác like mình)
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

    // Lắng nghe thêm danh sách mình đã quẹt (để ẩn ngay khi mình ấn like/dislike)
    final mySwipeStream = FirebaseFirestore.instance
        .collection('swipe_latest')
        .where('userId', isEqualTo: currentUserId)
        .snapshots();

    // Kết hợp 3 stream
    return Rx.combineLatest3(swipeStream, matchStream, mySwipeStream, (
      QuerySnapshot swipeSnap,
      QuerySnapshot matchSnap,
      QuerySnapshot mySwipeSnap,
    ) async {
      // Lấy danh sách user đã match CONFIRMED với mình
      final matchedUserIds = <String>{};
      for (var doc in matchSnap.docs) {
        final userIds = List<String>.from(doc['userIds'] ?? []);
        matchedUserIds.addAll(userIds.where((id) => id != currentUserId));
      }

      // Lấy danh sách user mình ĐÃ quẹt (cả like/dislike)
      final mySwipedIds = <String>{};
      for (var doc in mySwipeSnap.docs) {
        mySwipedIds.add(doc['targetUserId'] as String);
      }

      // Lấy danh sách user đã unmatch (cancelled)
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

      // Lấy danh sách user đã thích mình nhưng chưa match VÀ chưa bị cancelled VÀ mình chưa quẹt
      final users = <UserModel>[];
      for (var doc in swipeSnap.docs) {
        final userId = doc['userId'];

        // BỎ QUA user đã match HOẶC đã cancelled HOẶC mình đã quẹt phản hồi
        if (matchedUserIds.contains(userId) ||
            cancelledUserIds.contains(userId) ||
            mySwipedIds.contains(userId)) {
          continue;
        }

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          users.add(UserModel.fromMap(userDoc.data()!, userId));
        }
      }

      developer.log(
        'Liked me users: ${users.length} (excluded ${matchedUserIds.length} matched, ${cancelledUserIds.length} cancelled, ${mySwipedIds.length} swiped by me)',
        name: 'MatchProvider',
      );

      return users;
    }).asyncMap((f) => f).asBroadcastStream();
  }

  // Stream danh sách người mình đã dislike, loại bỏ những người đã match hoặc đã hủy match
  Stream<List<UserModel>> streamMyDislikedUsers(
    String currentUserId, {
    int limit = 100,
  }) {
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

    return Rx.combineLatest2(swipeStream, matchStream, (
      QuerySnapshot swipeSnap,
      QuerySnapshot matchSnap,
    ) async {
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
        if (matchedUserIds.contains(targetId) ||
            cancelledUserIds.contains(targetId))
          continue;

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetId)
            .get();
        if (userDoc.exists) {
          users.add(UserModel.fromMap(userDoc.data()!, targetId));
        }
      }

      developer.log(
        'My disliked users: ${users.length}',
        name: 'MatchProvider',
      );
      return users;
    }).asyncMap((f) => f).asBroadcastStream(); // ← ĐÃ CÓ broadcast
  }

  // Hàm hủy match giữa hai người dùng
  Future<void> unmatch(String matchId) async {
    await FirestoreService().unmatch(matchId);
    notifyListeners();
  }

  // Xóa hội thoại (ẩn tin nhắn)
  Future<void> clearChatForMe(String matchId) async {
    await FirestoreService().clearChatForMe(matchId);
    notifyListeners();
  }
}

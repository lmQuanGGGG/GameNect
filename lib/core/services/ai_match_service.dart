import '../../core/models/user_model.dart';
import '../../core/models/match_model.dart';
import '../../core/services/firestore_service.dart';

class AIMatchService {
  final FirestoreService _firestoreService = FirestoreService();

  Future<MatchModel?> findMatch(UserModel user) async {
    var usersSnapshot = await _firestoreService.db.collection('users').get();
    List<UserModel> allUsers = usersSnapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .where((u) => u.id != user.id)
        .toList();

    for (var otherUser in allUsers) {
      bool sameGame = user.favoriteGames.any(
        (game) => otherUser.favoriteGames.contains(game),
      );
      bool similarRank = _compareRanks(user.rank, otherUser.rank);
      if (sameGame && similarRank) {
        // Tạo match mới với xác nhận ban đầu
        MatchModel newMatch = MatchModel(
          id: DateTime.now().toString(),
          userIds: [user.id, otherUser.id],
          game: user.favoriteGames.firstWhere(
            (g) => otherUser.favoriteGames.contains(g),
          ),
          matchedAt: DateTime.now(),
          confirmations: {user.id: false, otherUser.id: false},
        );
        await _firestoreService.createMatch(newMatch);
        return newMatch;
      }
    }
    return null;
  }

  // Xác nhận match
  Future<void> confirmMatch(String userId, String matchId, bool confirm) async {
    var matchRef = _firestoreService.db.collection('matches').doc(matchId);
    await matchRef.update({'confirmations.$userId': confirm});
  }

  // Kiểm tra xem match đã hoàn tất chưa
  Future<bool> isMatchConfirmed(String matchId) async {
    var snapshot = await _firestoreService.db
        .collection('matches')
        .doc(matchId)
        .get();
    if (snapshot.exists) {
      MatchModel match = MatchModel.fromMap(snapshot.data()!, matchId);
      return match.userIds.every((uid) => match.confirmations[uid] == true);
    }
    return false;
  }

  // Lấy danh sách người đã thích (match chưa xác nhận)
  Future<List<UserModel>> getLikedUsers(String userId) async {
    var matchesSnapshot = await _firestoreService.db
        .collection('matches')
        .where('userIds', arrayContains: userId)
        .where('confirmations.$userId', isEqualTo: false)
        .get();
    List<UserModel> likedUsers = [];
    for (var doc in matchesSnapshot.docs) {
      MatchModel match = MatchModel.fromMap(doc.data(), doc.id);
      String otherUserId = match.userIds.firstWhere((id) => id != userId);
      var userData = await _firestoreService.getUser(otherUserId);
      if (userData != null) likedUsers.add(userData);
    }
    return likedUsers;
  }

  bool _compareRanks(String rank1, String rank2) {
    List<String> ranks = [
      'Gà Mờ',
      'Tập Sự Truyền Thuyết',
      'Chiến Binh Phèn',
      'Thánh Né',
      'Quái Vật Cân Team',
      'Trùm Cuối',
      'Thượng Đế AFK',
    ];
    int index1 = ranks.indexOf(rank1);
    int index2 = ranks.indexOf(rank2);
    return (index1 - index2).abs() <= 1;
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:logger/logger.dart';

final Logger _logger = Logger();

class CreateTestUsers {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Danh sách tên Việt Nam ─────────────────────────────────────
  final List<String> _firstNames = [
    'Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Huỳnh', 'Phan',
    'Vũ', 'Võ', 'Đặng', 'Bùi', 'Đỗ', 'Hồ', 'Ngô', 'Dương',
    'Lý', 'Đinh', 'Trịnh', 'Tô', 'La', 'Mai', 'Tạ', 'Châu',
    'Tăng', 'Lâm', 'Chu', 'Thái', 'Tiêu', 'Quách', 'Hà',
  ];

  final List<String> _lastNames = [
    'Gia Huy', 'Minh Khang', 'Khánh An', 'Bảo Ngọc', 'Hải Đăng',
    'Nhật Minh', 'Quỳnh Anh', 'Phương Linh', 'Yến Nhi', 'Đức Thịnh',
    'Hoàng Nam', 'Tuấn Kiệt', 'Thanh Trúc', 'Diễm My', 'Ngọc Mai',
    'Kim Ngân', 'Hà My', 'Khôi Nguyên', 'Minh Quân', 'Tiến Đạt',
    'Vân Anh', 'Thiên Ân', 'Bảo Châu', 'Quang Huy', 'Mỹ Duyên',
    'Anh Thư', 'Tường Vy', 'Hữu Phước', 'Gia Linh', 'Đức Anh',
  ];

  // ─── Game list ───────────────────────────────────────────────────
  final List<String> _games = [
    'Liên Quân Mobile', 'PUBG Mobile', 'Free Fire', 'Tốc Chiến',
    'Valorant', 'League of Legends', 'Đấu Trường Chân Lý', 'CS2',
    'Genshin Impact', 'Honkai: Star Rail', 'Zenless Zone Zero',
    'Minecraft', 'Roblox', 'FC Online', 'Naraka: Bladepoint',
    'Apex Legends', 'Overwatch 2', 'Warzone Mobile', 'Marvel Rivals',
  ];

  // ─── Locations ───────────────────────────────────────────────────
  final List<Map<String, dynamic>> _locations = [
    {'city': 'Hà Nội',          'lat': 21.0278, 'lng': 105.8342},
    {'city': 'TP. Hồ Chí Minh', 'lat': 10.7769, 'lng': 106.7009},
    {'city': 'Đà Nẵng',         'lat': 16.0678, 'lng': 108.2208},
    {'city': 'Hải Phòng',       'lat': 20.8449, 'lng': 106.6881},
    {'city': 'Cần Thơ',         'lat': 10.0452, 'lng': 105.7469},
    {'city': 'Nha Trang',       'lat': 12.2388, 'lng': 109.1967},
    {'city': 'Huế',             'lat': 16.4637, 'lng': 107.5909},
    {'city': 'Đà Lạt',          'lat': 11.9404, 'lng': 108.4583},
    {'city': 'Quy Nhơn',        'lat': 13.7820, 'lng': 109.2197},
    {'city': 'Vũng Tàu',        'lat': 10.4114, 'lng': 107.1362},
    {'city': 'Buôn Ma Thuột',   'lat': 12.6667, 'lng': 108.0500},
    {'city': 'Thái Nguyên',     'lat': 21.5942, 'lng': 105.8482},
    {'city': 'Long Xuyên',      'lat': 10.3833, 'lng': 105.4333},
    {'city': 'Rạch Giá',        'lat': 10.0125, 'lng': 105.0808},
  ];

  // ─── Bios ────────────────────────────────────────────────────────
  final List<String> _bios = [
    'Tối online sau 8h, ưu tiên team nói chuyện vui vẻ.',
    'Main support nhưng sẵn sàng fill mọi vị trí khi cần.',
    'Thích leo rank nghiêm túc, không toxic, call rõ ràng.',
    'Chơi game để xả stress, thua cũng cười.',
    'Ưu tiên đồng đội kiên nhẫn, cùng nhau cải thiện.',
    'Fan game chiến thuật, thích đọc meta và thử bài dị.',
    'Cuối tuần cày dài, ngày thường chơi 1-2 trận.',
    'Thích duo ổn định, không ghost giữa trận.',
    'Mục tiêu mùa này: lên rank mới và giữ winrate đẹp.',
    'Vừa chơi vừa học, thích chia sẻ kinh nghiệm cho team.',
    'Không try-hard quá mức, tôn trọng đồng đội là chính.',
    'Nếu bạn thích teamwork thì bắt cặp luôn nhé.',
    'Mình chơi đều nhiều tựa, từ MOBA tới FPS.',
    'Tìm bạn nói chuyện hợp vibe và chơi lâu dài.',
    'Lên game đúng giờ, kỷ luật nhưng vẫn thoải mái.',
    'Sẵn sàng train cùng người mới, miễn là có tinh thần.',
    'Tập trung objective, hạn chế combat vô nghĩa.',
    'Duo buổi tối, cuối tuần có thể lập team 5 người.',
    'Ưu tiên giao tiếp lịch sự, cùng nhau win sạch đẹp.',
    'Mong gặp đồng đội tích cực để đi đường dài.',
  ];

  // ─── Options (khớp với UI app) ───────────────────────────────────
  final List<String> _ranks = [
    'Gà Mờ', 'Tập Sự Truyền Thuyết', 'Chiến Binh Phèn',
    'Thánh Né', 'Quái vật cân team', 'Trùm Cuối', 'Thượng Đế AFK',
  ];

  final List<String> _gameStyles = [
    'Casual', 'Competitive', 'Streamer', 'Pro Player', 'Vừa chơi vừa học',
  ];

  final List<String> _allInterests = [
    'Anime/Manga', 'Thể thao', 'Du lịch', 'Âm nhạc', 'Phim ảnh',
    'Nấu ăn', 'Sách', 'Công nghệ', 'Thời trang', 'Nhiếp ảnh',
  ];

  final List<String> _lookingForOptions = [
    'Bạn chơi game', 'Hẹn hò', 'Cả hai', 'Người chỉ dạy', 'Đồng đội lâu dài',
  ];

  final List<String> _genders = ['Nam', 'Nữ', 'Khác'];

  // ─── Avatars — Unsplash (cuò Unsplash photo IDs — người Việt/châu Á) ──
  // ?w=400&h=400&fit=crop&q=80 — ảnh đầy đủ chất lượng cao
  static const String _uBase = 'https://images.unsplash.com/photo-';
  static const String _uSuffix = '?w=400&h=400&fit=crop&q=80';

  final List<String> _maleAvatars = [
    '${_uBase}1507003211169-0a1dd7228f2d$_uSuffix',   // chàng trai trẻ
    '${_uBase}1506794778202-cad84cf45f1d$_uSuffix',
    '${_uBase}1500648767791-00dcc994a43e$_uSuffix',
    '${_uBase}1472099645785-5658abf4ff4e$_uSuffix',
    '${_uBase}1519085360753-af0119f7cbe7$_uSuffix',
    '${_uBase}1531427186611-141c8f1d0905$_uSuffix',
    '${_uBase}1552374196-c4e7ffc6e126$_uSuffix',
    '${_uBase}1557862921-37829c790f19$_uSuffix',
    '${_uBase}1545167622-43594be8ab5c$_uSuffix',
    '${_uBase}1570295999919-56ceb5ecca61$_uSuffix',
    '${_uBase}1543610892-0b1f7e6d8ac1$_uSuffix',
    '${_uBase}1544005313-94ddf0286df2$_uSuffix',
    '${_uBase}1547425260-76bcf1f62a9a$_uSuffix',
    '${_uBase}1564564321837-a57b7070ac4f$_uSuffix',
    '${_uBase}1583864697784-a0a91e79f23a$_uSuffix',
    '${_uBase}1599566150163-29194dcaad36$_uSuffix',
    '${_uBase}1601455782032-d09d6ab4e065$_uSuffix',
    '${_uBase}1613532390232-43d6f9dea8e5$_uSuffix',
    '${_uBase}1633332755192-727a05c4013d$_uSuffix',
    '${_uBase}1640951613773-54706b0a5bb4$_uSuffix',
  ];

  final List<String> _femaleAvatars = [
    '${_uBase}1529626455594-bae7079b7bbf$_uSuffix',   // phụ nữ Việt/châu Á
    '${_uBase}1534528741775-53994a69daeb$_uSuffix',
    '${_uBase}1438761681033-6461ffad8d80$_uSuffix',
    '${_uBase}1494790108377-be9c29b29330$_uSuffix',
    '${_uBase}1488426862026-3ee34a7d66df$_uSuffix',
    '${_uBase}1502823403499-6ccfcf4fb453$_uSuffix',
    '${_uBase}1504703395778-ae55b8bf7ff2$_uSuffix',
    '${_uBase}1519699047748-de8e457a634e$_uSuffix',
    '${_uBase}1521119989659-3d20af1f2144$_uSuffix',
    '${_uBase}1522075469751-3a6694fb2f61$_uSuffix',
    '${_uBase}1544005313-94ddf0286df2$_uSuffix',
    '${_uBase}1548142542-d0a46e9edd56$_uSuffix',
    '${_uBase}1554080353-a576cf803bda$_uSuffix',
    '${_uBase}1570158268183-d296b2892211$_uSuffix',
    '${_uBase}1582142306909-195724d33b79$_uSuffix',
    '${_uBase}1598550874175-4d0ef436c909$_uSuffix',
    '${_uBase}1607746882042-944635dfe10e$_uSuffix',
    '${_uBase}1614283233556-f35b0c801ef1$_uSuffix',
    '${_uBase}1618641986557-1ecd230959aa$_uSuffix',
    '${_uBase}1631947430066-0d6764b4f3df$_uSuffix',
  ];

  final List<String> _otherAvatars = [
    '${_uBase}1580489944761-15a19d654956$_uSuffix',
    '${_uBase}1567532939604-b6b5b0db2604$_uSuffix',
    '${_uBase}1560250097-0b93528c311a$_uSuffix',
    '${_uBase}1573496359142-b8d87734a5a2$_uSuffix',
    '${_uBase}1601455782032-d09d6ab4e065$_uSuffix',
    '${_uBase}1531123897727-240d604e82d7$_uSuffix',
    '${_uBase}1525134489668-dea9a0a19be5$_uSuffix',
    '${_uBase}1508214751196-bcfd4ca60f91$_uSuffix',
    '${_uBase}1595152772835-219674b2a163$_uSuffix',
    '${_uBase}1548142542-d0a46e9edd56$_uSuffix',
  ];

  final Random _random = Random();

  // ─── Helpers ─────────────────────────────────────────────────────

  DateTime _generateRandomBirthDate() {
    final now = DateTime.now();
    final age = 18 + _random.nextInt(18); // 18-35 tuổi
    return DateTime(now.year - age, 1 + _random.nextInt(12), 1 + _random.nextInt(28));
  }

  String _getAvatarByGender(String gender) {
    if (gender == 'Nam') return _maleAvatars[_random.nextInt(_maleAvatars.length)];
    if (gender == 'Nữ') return _femaleAvatars[_random.nextInt(_femaleAvatars.length)];
    return _otherAvatars[_random.nextInt(_otherAvatars.length)];
  }

  String _removeVietnameseTones(String str) {
    const vietnamese =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const latin =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    String result = str;
    for (int i = 0; i < vietnamese.length; i++) {
      result = result.replaceAll(vietnamese[i], latin[i]);
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════════
  // TẠO 1 USER
  // ════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> createRandomUser(int index) async {
    try {
      final firstName   = _firstNames[_random.nextInt(_firstNames.length)];
      final lastName    = _lastNames[_random.nextInt(_lastNames.length)];
      final displayName = '$firstName $lastName';
      final username    =
          '${_removeVietnameseTones(firstName.toLowerCase())}'
          '${_removeVietnameseTones(lastName.toLowerCase())}'
          '${index.toString().padLeft(3, '0')}';
      final email    = 'testuser${index.toString().padLeft(4, '0')}@gamenect.com';
      final password = 'Test@123';

      _logger.i('Đang tạo user [$index]: $email');

      User? user;
      try {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
        user = cred.user;
        _logger.i('✓ Tạo mới Auth: $email');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _logger.w('⚠️  Đã tồn tại, cập nhật: $email');
          try {
            final cred = await _auth.signInWithEmailAndPassword(
                email: email, password: password);
            user = cred.user;
          } catch (_) {
            _logger.e('❌ Không đăng nhập được: $email');
            return null;
          }
        } else {
          rethrow;
        }
      }
      if (user == null) return null;

      await user.updateDisplayName(displayName);

      // ── Profile fields ─────────────────────────────────────────
      final gender    = _genders[_random.nextInt(_genders.length)];
      final birthDate = _generateRandomBirthDate();
      final age       = DateTime.now().year - birthDate.year;
      final height    = 150 + _random.nextInt(41);
      final location  = _locations[_random.nextInt(_locations.length)];
      final bio       = _bios[_random.nextInt(_bios.length)];
      final rank      = _ranks[_random.nextInt(_ranks.length)];
      final gameStyle = _gameStyles[_random.nextInt(_gameStyles.length)];
      final playTime  = _random.nextInt(5001);
      final winRate   = 30 + _random.nextInt(51);
      final isPremium  = _random.nextInt(10) == 0;
      final isVerified = _random.nextInt(10) < 3;
      final isOnline   = _random.nextInt(5) == 0;

      // Games (1-3)
      final gamesCopy = List<String>.from(_games);
      final numGames  = 1 + _random.nextInt(3);
      final selectedGames = <String>[];
      for (int i = 0; i < numGames; i++) {
        selectedGames.add(gamesCopy.removeAt(_random.nextInt(gamesCopy.length)));
      }

      // Interests (2-5)
      final intCopy   = List<String>.from(_allInterests);
      final numInt    = 2 + _random.nextInt(4);
      final interests = <String>[];
      for (int i = 0; i < numInt; i++) {
        interests.add(intCopy.removeAt(_random.nextInt(intCopy.length)));
      }

      // Photos phụ — Unsplash cuò thêm với face crop
      final additionalPhotos = <String>[];
      final numPhotos = 1 + _random.nextInt(4);
      final pool = gender == 'Nam' ? _maleAvatars : _femaleAvatars;
      final used = <String>{};
      for (int i = 0; i < numPhotos; i++) {
        if (i < 2) {
          // Nhặt ảnh khác từ pool (không trùng avatar chính)
          String pick;
          do { pick = pool[_random.nextInt(pool.length)]; } while (used.contains(pick));
          used.add(pick);
          additionalPhotos.add(pick);
        } else {
          // Lifestyle shot — Unsplash cầnh phố/game cafe Việt Nam
          final lifestyleIds = [
            '1558618666-fcd25c85cd64', // cà phê Việt Nam
            '1506126613408-eca07ce68773', // cảnh phố
            '1574236170878-0e69a1609099', // gaming
            '1542751371-adc538436a54', // esports
            '1511512578047-dfb367046420', // gaming setup
            '1593305841991-05c297ba4575', // cà phê
            '1524592094714-0f0654e359e3', // bàn game
            '1600861194942-f883de0dfe96', // lạc phố Việt Nam
          ];
          final id = lifestyleIds[_random.nextInt(lifestyleIds.length)];
          additionalPhotos.add('https://images.unsplash.com/photo-$id?w=600&h=800&fit=crop&q=80');
        }
      }

      // ⭐ Preferences (QUAN TRỌNG cho ML model) ──────────────────
      final interestedInGender = _random.nextInt(3) == 0
          ? 'Tất cả'
          : (_random.nextBool() ? 'Nam' : 'Nữ');
      final minAge     = 18 + _random.nextInt(5);          // 18-22
      final maxAge     = age + 5 + _random.nextInt(10);    // age+5 → age+15
      final maxDistance = [10.0, 20.0, 30.0, 50.0, 100.0][_random.nextInt(5)];
      final lookingFor = _lookingForOptions[_random.nextInt(_lookingForOptions.length)];

      // ── Last seen: trong vòng 30 ngày qua ─────────────────────
      final lastSeenDaysAgo = _random.nextInt(30);
      final lastSeen = DateTime.now()
          .subtract(Duration(days: lastSeenDaysAgo, hours: _random.nextInt(24)))
          .toIso8601String();

      final profileData = {
        // Identity
        'uid':         user.uid,
        'email':       email,
        'username':    username,
        'displayName': displayName,
        'photoURL':    _getAvatarByGender(gender),
        'avatarUrl':   _getAvatarByGender(gender),
        'bio':         bio,

        // Personal
        'gender':    gender,
        'birthDate': birthDate.toIso8601String(),
        'age':       age,
        'height':    height,

        // Game
        'favoriteGames': selectedGames,
        'rank':          rank,
        'playTime':      playTime,
        'winRate':       winRate,
        'gameStyle':     gameStyle,

        // Social
        'interests':   interests,
        'lookingFor':  lookingFor,

        // ⭐ Preferences (ML model dùng)
        'interestedInGender': interestedInGender,
        'minAge':             minAge,
        'maxAge':             maxAge,
        'maxDistance':        maxDistance,

        // Location
        'location': {
          'city':      location['city'],
          'latitude':  location['lat'],
          'longitude': location['lng'],
          'updatedAt': DateTime.now().toIso8601String(),
        },

        // Media
        'additionalPhotos': additionalPhotos,

        // Status
        'isOnline':         isOnline,
        'lastSeen':         lastSeen,
        'isPremium':        isPremium,
        'isVerified':       isVerified,
        'showOnlineStatus': _random.nextBool(),
        'isTestAccount':    true,

        // Timestamps
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),

        // ⭐ Social proof stats (ML model dùng)
        'likeCount':       _random.nextInt(200),
        'matchCount':      _random.nextInt(50),
        'friendCount':     _random.nextInt(100),
        'superLikeCount':  _random.nextInt(20),
        'profileViews':    _random.nextInt(300),
        'totalMatches':    _random.nextInt(50),
        'totalLikes':      _random.nextInt(200),
        'totalSuperLikes': _random.nextInt(20),

        // Settings
        'showAge':      _random.nextBool(),
        'showDistance': _random.nextBool(),

        // Account
        'subscriptionTier':   'free',
        'subscriptionEndDate': null,
        'incognitoMode':      false,
        'blockedUserIds':     <String>[],
        'reportedUserIds':    <String>[],
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      _logger.i(
        '✓ $email | $displayName | ${location['city']} | '
        '$age tuổi | $gender | $rank | ${selectedGames.join(', ')}',
      );

      await _auth.signOut();

      return {
        'uid':         user.uid,
        'email':       email,
        'username':    username,
        'password':    password,
        'displayName': displayName,
        'city':        location['city'],
        'lat':         location['lat'],
        'lng':         location['lng'],
        'age':         age,
        'gender':      gender,
        'games':       selectedGames,
        'interests':   interests,
        'rank':        rank,
        'gameStyle':   gameStyle,
        'lookingFor':  lookingFor,
        'winRate':     winRate,
        'playTime':    playTime,
        'interestedInGender': interestedInGender,
        'minAge':      minAge,
        'maxAge':      maxAge,
        'maxDistance': maxDistance,
        'isVerified':  isVerified,
        'isPremium':   isPremium,
      };
    } catch (e) {
      _logger.e('✗ Lỗi tạo user $index: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ⭐ TẠO SWIPE DATA THỰC TẾ (QUAN TRỌNG NHẤT CHO ML MODEL)
  // Logic: dùng profile similarity để quyết định like/dislike
  // → Labels THỰC, không random hoàn toàn
  // ════════════════════════════════════════════════════════════════

  Future<void> createRealisticSwipeData(
      List<Map<String, dynamic>> users) async {
    _logger.i('\n=== TẠO SWIPE DATA (${users.length} users) ===\n');

    int totalSwipes = 0;
    int likeCount   = 0;
    int dislikeCount = 0;

    // Mỗi user swipe ~15-25 users khác
    for (int i = 0; i < users.length; i++) {
      final swiper = users[i];
      final swiperId = swiper['uid'] as String;

      // Số lượng người được swipe (15-25)
      final numSwipes = 15 + _random.nextInt(11);
      final candidates = List<Map<String, dynamic>>.from(users)
        ..removeWhere((u) => u['uid'] == swiperId)
        ..shuffle(_random);
      final toSwipe = candidates.take(numSwipes).toList();

      for (final target in toSwipe) {
        final targetId = target['uid'] as String;

        // ── Tính compatibility score để quyết định like/dislike ──
        final score = _computeCompatibility(swiper, target);

        // Score cao → thích, thấp → không thích
        // Thêm randomness để realistic (không ai like 100% dựa theo rules)
        final randomFactor = (_random.nextDouble() - 0.5) * 0.3; // ±0.15
        final finalScore   = (score + randomFactor).clamp(0.0, 1.0);
        final action       = finalScore >= 0.5 ? 'like' : 'dislike';

        if (action == 'like') likeCount++; else dislikeCount++;
        totalSwipes++;

        // Lưu vào swipe_history
        final swipeDoc = _firestore.collection('swipe_history').doc();
        await swipeDoc.set({
          'id':           swipeDoc.id,
          'userId':       swiperId,
          'targetUserId': targetId,
          'action':       action,
          'timestamp':    DateTime.now()
              .subtract(Duration(
                days: _random.nextInt(30),
                hours: _random.nextInt(24),
                minutes: _random.nextInt(60),
              ))
              .toIso8601String(),
          // metadata cho debug
          '_compatScore': score,
          '_isTestData':  true,
        });

        // Cũng lưu vào swipe_latest (snapshot mới nhất của cặp)
        final latestId = [swiperId, targetId]..sort();
        await _firestore
            .collection('swipe_latest')
            .doc('${latestId[0]}_${latestId[1]}')
            .set({
          'userId':       swiperId,
          'targetUserId': targetId,
          'action':       action,
          'timestamp':    DateTime.now().toIso8601String(),
          '_isTestData':  true,
        }, SetOptions(merge: true));
      }

      if ((i + 1) % 10 == 0) {
        _logger.i(
          'Swipe progress: ${i + 1}/${users.length} users | '
          'total=$totalSwipes like=$likeCount dislike=$dislikeCount',
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    _logger.i('\n✅ Swipe data done:');
    _logger.i('  Total swipes : $totalSwipes');
    _logger.i('  Like         : $likeCount (${(likeCount/totalSwipes*100).toStringAsFixed(1)}%)');
    _logger.i('  Dislike      : $dislikeCount (${(dislikeCount/totalSwipes*100).toStringAsFixed(1)}%)');

    // Tạo matches từ mutual likes
    await _createMatchesFromMutualLikes(users);
  }

  // ════════════════════════════════════════════════════════════════
  // Tính compatibility score (0-1) giữa 2 users — giống ML model
  // ════════════════════════════════════════════════════════════════
  double _computeCompatibility(Map<String, dynamic> u1, Map<String, dynamic> u2) {
    double score = 0.0;
    int    factors = 0;

    // 1. Gender preference match
    final pref1  = u1['interestedInGender'] as String? ?? 'Tất cả';
    final pref2  = u2['interestedInGender'] as String? ?? 'Tất cả';
    final g1     = u1['gender'] as String? ?? '';
    final g2     = u2['gender'] as String? ?? '';
    final m12    = pref1 == 'Tất cả' || pref1 == g2;
    final m21    = pref2 == 'Tất cả' || pref2 == g1;
    score  += (m12 && m21) ? 1.0 : (m12 || m21) ? 0.4 : 0.0;
    factors++;

    // 2. Age preference
    final age1   = (u1['age'] as num?)?.toDouble() ?? 25;
    final age2   = (u2['age'] as num?)?.toDouble() ?? 25;
    final minAge1 = (u1['minAge'] as num?)?.toDouble() ?? 18;
    final maxAge1 = (u1['maxAge'] as num?)?.toDouble() ?? 60;
    final minAge2 = (u2['minAge'] as num?)?.toDouble() ?? 18;
    final maxAge2 = (u2['maxAge'] as num?)?.toDouble() ?? 60;
    final agePref = (minAge1 <= age2 && age2 <= maxAge1) &&
                    (minAge2 <= age1 && age1 <= maxAge2);
    score  += agePref ? 1.0 : 0.0;
    factors++;

    // 3. Age diff
    final ageDiff = (age1 - age2).abs();
    score  += ageDiff <= 3 ? 1.0 : ageDiff <= 7 ? 0.7 : ageDiff <= 12 ? 0.4 : 0.1;
    factors++;

    // 4. Game style compatibility
    final s1 = u1['gameStyle'] as String? ?? '';
    final s2 = u2['gameStyle'] as String? ?? '';
    if (s1 == s2) {
      score += 1.0;
    } else if ((s1 == 'Competitive' && s2 == 'Pro Player') ||
               (s1 == 'Pro Player'  && s2 == 'Competitive') ||
               (s1 == 'Casual'      && s2 == 'Vừa chơi vừa học') ||
               (s1 == 'Vừa chơi vừa học' && s2 == 'Casual')) {
      score += 0.8;
    } else {
      score += 0.3;
    }
    factors++;

    // 5. Shared games (Jaccard)
    final g1s = Set<String>.from((u1['games'] as List?)?.cast<String>() ?? []);
    final g2s = Set<String>.from((u2['games'] as List?)?.cast<String>() ?? []);
    final union = g1s.union(g2s).length;
    final intersect = g1s.intersection(g2s).length;
    score  += union > 0 ? intersect / union : 0.0;
    factors++;

    // 6. Shared interests (Jaccard)
    final i1s = Set<String>.from((u1['interests'] as List?)?.cast<String>() ?? []);
    final i2s = Set<String>.from((u2['interests'] as List?)?.cast<String>() ?? []);
    final uI  = i1s.union(i2s).length;
    final iI  = i1s.intersection(i2s).length;
    score  += uI > 0 ? iI / uI : 0.0;
    factors++;

    // 7. Win rate diff (skill)
    final wr1   = (u1['winRate'] as num?)?.toDouble() ?? 50;
    final wr2   = (u2['winRate'] as num?)?.toDouble() ?? 50;
    final wrDiff = (wr1 - wr2).abs();
    score  += wrDiff <= 10 ? 1.0 : wrDiff <= 25 ? 0.6 : wrDiff <= 40 ? 0.3 : 0.1;
    factors++;

    // 8. Same looking for
    final lf1 = u1['lookingFor'] as String? ?? '';
    final lf2 = u2['lookingFor'] as String? ?? '';
    score  += lf1 == lf2 ? 1.0 : 0.3;
    factors++;

    // 9. Location — same city hoặc cùng vùng
    final lat1 = (u1['lat'] as num?)?.toDouble() ?? 0;
    final lng1 = (u1['lng'] as num?)?.toDouble() ?? 0;
    final lat2 = (u2['lat'] as num?)?.toDouble() ?? 0;
    final lng2 = (u2['lng'] as num?)?.toDouble() ?? 0;
    final approxDist = (((lat1 - lat2) * 111).abs() + ((lng1 - lng2) * 111).abs());
    score  += approxDist < 5 ? 1.0 : approxDist < 30 ? 0.7 : approxDist < 100 ? 0.4 : 0.1;
    factors++;

    return factors > 0 ? score / factors : 0.5;
  }

  // ════════════════════════════════════════════════════════════════
  // TẠO MATCHES từ mutual likes
  // ════════════════════════════════════════════════════════════════
  Future<void> _createMatchesFromMutualLikes(
      List<Map<String, dynamic>> users) async {
    _logger.i('\n=== TẠO MATCHES TỪ MUTUAL LIKES ===');

    // Load tất cả swipe_latest để tìm mutual
    final swipeSnap = await _firestore.collection('swipe_latest').get();
    final swipeMap  = <String, String>{}; // "u1_u2" → action

    for (final doc in swipeSnap.docs) {
      final data = doc.data();
      if (data['_isTestData'] == true) {
        final key = '${data['userId']}_${data['targetUserId']}';
        swipeMap[key] = data['action'] as String;
      }
    }

    int matchCount = 0;
    final processed = <String>{};

    for (final u1 in users) {
      for (final u2 in users) {
        final id1 = u1['uid'] as String;
        final id2 = u2['uid'] as String;
        if (id1 == id2) continue;

        final pairKey = [id1, id2]..sort();
        final pairStr = pairKey.join('_');
        if (processed.contains(pairStr)) continue;
        processed.add(pairStr);

        final k12 = '${id1}_$id2';
        final k21 = '${id2}_$id1';
        final a12 = swipeMap[k12];
        final a21 = swipeMap[k21];

        if (a12 == 'like' && a21 == 'like') {
          // Mutual like → tạo match
          final compatibility = _computeCompatibility(u1, u2);
          final status = compatibility >= 0.6 ? 'confirmed' : 'cancelled';

          await _firestore.collection('matches').add({
            'userIds':      [id1, id2],
            'status':       status,
            'isActive':     status == 'confirmed',
            'game':         (u1['games'] as List).isNotEmpty
                ? (u1['games'] as List).first
                : 'Liên Quân Mobile',
            'confirmations': {id1: true, id2: true},
            'createdAt':    DateTime.now().toIso8601String(),
            'matchedAt':    DateTime.now().toIso8601String(),
            'updatedAt':    DateTime.now().toIso8601String(),
            'expiresAt':    DateTime.now()
                .add(const Duration(days: 1))
                .toIso8601String(),
            'cancelledAt':  status == 'cancelled'
                ? DateTime.now().toIso8601String()
                : null,
            '_compatScore': compatibility,
            '_isTestData':  true,
          });

          matchCount++;
          _logger.i('💕 Match: ${u1['displayName']} ↔ ${u2['displayName']} [$status]');
        }
      }
    }

    _logger.i('\n✅ Created $matchCount matches');
  }

  // ════════════════════════════════════════════════════════════════
  // TẠO NHIỀU USERS + SWIPE DATA (gọi hàm này từ UI)
  // ════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> createMultipleUsers(int count) async {
    _logger.i('=== BẮT ĐẦU TẠO $count USERS + SWIPE DATA ===\n');

    final createdUsers = <Map<String, dynamic>>[];

    for (int i = 1; i <= count; i++) {
      final userData = await createRandomUser(i);
      if (userData != null) createdUsers.add(userData);

      await Future.delayed(const Duration(milliseconds: 500));

      if (i % 10 == 0) {
        _logger.i('--- Đã tạo $i/$count users ---');
      }
    }

    _logger.i('\n✅ Users: ${createdUsers.length}/$count');

    // ⭐ Tạo swipe data sau khi có đủ users
    if (createdUsers.length >= 2) {
      await createRealisticSwipeData(createdUsers);
    }

    _logger.i('\n=== HOÀN TẤT ===');
    _logger.i('Users    : ${createdUsers.length}');
    _logger.i('Tổng cặp swipe có thể tạo: '
        '${createdUsers.length * (createdUsers.length - 1)} pairs');
    _logger.i('→ Chạy collect_from_firebase.py để lấy data train model!');

    return createdUsers;
  }

  // ════════════════════════════════════════════════════════════════
  // EXPORT LOG
  // ════════════════════════════════════════════════════════════════

  void exportUsersList(List<Map<String, dynamic>> users) {
    _logger.i('\n=== DANH SÁCH USERS ===\n');
    for (int i = 0; i < users.length; i++) {
      final u = users[i];
      _logger.i(
        '${i + 1}. ${u['email']} | ${u['displayName']} | '
        '${u['age']}t ${u['gender']} | ${u['city']} | '
        '${u['rank']} | ${u['gameStyle']} | '
        'games: ${(u['games'] as List).join(', ')}',
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  // XÓA TEST DATA
  // ════════════════════════════════════════════════════════════════

  Future<void> deleteAllTestUsers() async {
    _logger.i('=== XÓA TEST USERS ===');

    // Xóa users
    final userSnap = await _firestore
        .collection('users')
        .where('isTestAccount', isEqualTo: true)
        .get();
    for (final doc in userSnap.docs) {
      await doc.reference.delete();
    }
    _logger.i('✓ Đã xóa ${userSnap.docs.length} users');

    // Xóa swipe_history test
    final swipeSnap = await _firestore
        .collection('swipe_history')
        .where('_isTestData', isEqualTo: true)
        .get();
    for (final doc in swipeSnap.docs) {
      await doc.reference.delete();
    }
    _logger.i('✓ Đã xóa ${swipeSnap.docs.length} swipe records');

    // Xóa swipe_latest test
    final latestSnap = await _firestore
        .collection('swipe_latest')
        .where('_isTestData', isEqualTo: true)
        .get();
    for (final doc in latestSnap.docs) {
      await doc.reference.delete();
    }
    _logger.i('✓ Đã xóa ${latestSnap.docs.length} swipe_latest records');

    // Xóa matches test
    final matchSnap = await _firestore
        .collection('matches')
        .where('_isTestData', isEqualTo: true)
        .get();
    for (final doc in matchSnap.docs) {
      await doc.reference.delete();
    }
    _logger.i('✓ Đã xóa ${matchSnap.docs.length} matches');

    _logger.w('⚠️  Vào Firebase Auth Console để xóa thủ công các test accounts');
  }
}

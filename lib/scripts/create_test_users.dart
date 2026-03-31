import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:logger/logger.dart';

final Logger _logger = Logger();

class CreateTestUsers {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Danh sách tên Việt Nam
  final List<String> _firstNames = [
    'Nguyễn',
    'Trần',
    'Lê',
    'Phạm',
    'Hoàng',
    'Huỳnh',
    'Phan',
    'Vũ',
    'Võ',
    'Đặng',
    'Bùi',
    'Đỗ',
    'Hồ',
    'Ngô',
    'Dương',
    'Lý',
    'Đinh',
    'Trịnh',
    'Tô',
    'La',
    'Mai',
    'Tạ',
    'Châu',
    'Tăng',
    'Lâm',
    'Chu',
    'Thái',
    'Tiêu',
    'Quách',
    'Hà',
  ];

  final List<String> _lastNames = [
    'Gia Huy',
    'Minh Khang',
    'Khánh An',
    'Bảo Ngọc',
    'Hải Đăng',
    'Nhật Minh',
    'Quỳnh Anh',
    'Phương Linh',
    'Yến Nhi',
    'Đức Thịnh',
    'Hoàng Nam',
    'Tuấn Kiệt',
    'Thanh Trúc',
    'Diễm My',
    'Ngọc Mai',
    'Kim Ngân',
    'Hà My',
    'Khôi Nguyên',
    'Minh Quân',
    'Tiến Đạt',
    'Vân Anh',
    'Thiên Ân',
    'Bảo Châu',
    'Quang Huy',
    'Mỹ Duyên',
    'Anh Thư',
    'Tường Vy',
    'Hữu Phước',
    'Gia Linh',
    'Đức Anh',
  ];

  // Danh sách game phổ biến
  final List<String> _games = [
    'Liên Quân Mobile',
    'PUBG Mobile',
    'Free Fire',
    'Tốc Chiến',
    'Valorant',
    'League of Legends',
    'Đấu Trường Chân Lý',
    'CS2',
    'Genshin Impact',
    'Honkai: Star Rail',
    'Zenless Zone Zero',
    'Minecraft',
    'Roblox',
    'FC Online',
    'Naraka: Bladepoint',
    'Apex Legends',
    'Overwatch 2',
    'Warzone Mobile',
    'Marvel Rivals',
  ];

  // Danh sách tỉnh thành Việt Nam
  final List<Map<String, dynamic>> _locations = [
    {'city': 'Hà Nội', 'lat': 21.0278, 'lng': 105.8342},
    {'city': 'TP. Hồ Chí Minh', 'lat': 10.7769, 'lng': 106.7009},
    {'city': 'Đà Nẵng', 'lat': 16.0678, 'lng': 108.2208},
    {'city': 'Hải Phòng', 'lat': 20.8449, 'lng': 106.6881},
    {'city': 'Cần Thơ', 'lat': 10.0452, 'lng': 105.7469},
    {'city': 'Nha Trang', 'lat': 12.2388, 'lng': 109.1967},
    {'city': 'Huế', 'lat': 16.4637, 'lng': 107.5909},
    {'city': 'Đà Lạt', 'lat': 11.9404, 'lng': 108.4583},
    {'city': 'Quy Nhơn', 'lat': 13.7820, 'lng': 109.2197},
    {'city': 'Vũng Tàu', 'lat': 10.4114, 'lng': 107.1362},
    {'city': 'Buôn Ma Thuột', 'lat': 12.6667, 'lng': 108.0500},
    {'city': 'Thái Nguyên', 'lat': 21.5942, 'lng': 105.8482},
    {'city': 'Long Xuyên', 'lat': 10.3833, 'lng': 105.4333},
    {'city': 'Rạch Giá', 'lat': 10.0125, 'lng': 105.0808},
  ];

  // Danh sách bio mẫu
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

  // 🏆 Rank Options (ĐÚNG THEO YÊU CẦU)
  final List<String> _ranks = [
    'Gà Mờ',
    'Tập Sự Truyền Thuyết',
    'Chiến Binh Phèn',
    'Thánh Né',
    'Quái vật cân team',
    'Trùm Cuối',
    'Thượng Đế AFK',
  ];

  // 🎮 Game Style Options (ĐÚNG THEO YÊU CẦU)
  final List<String> _gameStyles = [
    'Casual',
    'Competitive',
    'Streamer',
    'Pro Player',
    'Vừa chơi vừa học',
  ];

  // 🎯 Interest Options (ĐÚNG THEO YÊU CẦU)
  final List<String> _allInterests = [
    'Anime/Manga',
    'Thể thao',
    'Du lịch',
    'Âm nhạc',
    'Phim ảnh',
    'Nấu ăn',
    'Sách',
    'Công nghệ',
    'Thời trang',
    'Nhiếp ảnh',
  ];

  // 💞 Looking For Options (ĐÚNG THEO YÊU CẦU)
  final List<String> _lookingForOptions = [
    'Bạn chơi game',
    'Hẹn hò',
    'Cả hai',
    'Người chỉ dạy',
    'Đồng đội lâu dài',
  ];

  // 🚻 Gender Options (ĐÚNG THEO YÊU CẦU)
  final List<String> _genders = ['Nam', 'Nữ', 'Khác'];

  // Danh sách avatar URLs
  final List<String> _maleAvatars = [
    'https://i.pravatar.cc/400?img=11',
    'https://i.pravatar.cc/400?img=12',
    'https://i.pravatar.cc/400?img=13',
    'https://i.pravatar.cc/400?img=14',
    'https://i.pravatar.cc/400?img=15',
    'https://i.pravatar.cc/400?img=16',
    'https://i.pravatar.cc/400?img=17',
    'https://i.pravatar.cc/400?img=18',
    'https://i.pravatar.cc/400?img=19',
    'https://i.pravatar.cc/400?img=20',
  ];

  final List<String> _femaleAvatars = [
    'https://i.pravatar.cc/400?img=31',
    'https://i.pravatar.cc/400?img=32',
    'https://i.pravatar.cc/400?img=33',
    'https://i.pravatar.cc/400?img=34',
    'https://i.pravatar.cc/400?img=35',
    'https://i.pravatar.cc/400?img=36',
    'https://i.pravatar.cc/400?img=37',
    'https://i.pravatar.cc/400?img=38',
    'https://i.pravatar.cc/400?img=39',
    'https://i.pravatar.cc/400?img=40',
  ];

  final List<String> _otherAvatars = [
    'https://i.pravatar.cc/400?img=51',
    'https://i.pravatar.cc/400?img=52',
    'https://i.pravatar.cc/400?img=53',
    'https://i.pravatar.cc/400?img=54',
    'https://i.pravatar.cc/400?img=55',
    'https://i.pravatar.cc/400?img=56',
  ];

  final Random _random = Random();

  /// Tạo ngày sinh ngẫu nhiên (18-35 tuổi)
  DateTime _generateRandomBirthDate() {
    final now = DateTime.now();
    final age = 18 + _random.nextInt(18); // 18-35 tuổi
    final year = now.year - age;
    final month = 1 + _random.nextInt(12);
    final day = 1 + _random.nextInt(28);
    return DateTime(year, month, day);
  }

  /// Chọn avatar phù hợp với giới tính
  String _getAvatarByGender(String gender) {
    if (gender == 'Nam') {
      return _maleAvatars[_random.nextInt(_maleAvatars.length)];
    } else if (gender == 'Nữ') {
      return _femaleAvatars[_random.nextInt(_femaleAvatars.length)];
    } else {
      return _otherAvatars[_random.nextInt(_otherAvatars.length)];
    }
  }

  /// Tạo một user ngẫu nhiên với ĐẦY ĐỦ các trường
  Future<Map<String, dynamic>?> createRandomUser(int index) async {
    try {
      // Tạo thông tin cơ bản
      final firstName = _firstNames[_random.nextInt(_firstNames.length)];
      final lastName = _lastNames[_random.nextInt(_lastNames.length)];
      final displayName = '$firstName $lastName';

      // Tạo username unique (chữ thường không dấu + số)
      final username =
          '${_removeVietnameseTones(firstName.toLowerCase())}${_removeVietnameseTones(lastName.toLowerCase())}${index.toString().padLeft(3, '0')}';

      final email = 'testuser${index.toString().padLeft(3, '9999')}@gamenect.com';
      final password = 'Test@123';

      _logger.i('Đang tạo user: $email (username: $username)');

      // Tạo hoặc lấy user từ Firebase Auth
      User? user;
      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        user = userCredential.user;
        _logger.i('✓ Tạo mới Authentication user: $email');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Email đã tồn tại -> Đăng nhập để lấy UID
          _logger.w('⚠️  Email đã tồn tại, đang cập nhật dữ liệu: $email');
          try {
            final userCredential = await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            user = userCredential.user;
          } catch (signInError) {
            _logger.e('❌ Không thể đăng nhập với email $email: $signInError');
            return null;
          }
        } else {
          rethrow;
        }
      }

      if (user == null) {
        _logger.e('❌ Không tạo được user $email');
        return null;
      }

      // Cập nhật display name
      await user.updateDisplayName(displayName);

      // === TẠO DỮ LIỆU ĐẦY ĐỦ ===

      // 1. Gender (ĐÚNG OPTIONS)
      final gender = _genders[_random.nextInt(_genders.length)];

      // 2. Birth Date & Age
      final birthDate = _generateRandomBirthDate();
      final age = DateTime.now().year - birthDate.year;

      // 3. Height (150-190cm)
      final height = 150 + _random.nextInt(41);

      // 4. Games (1-3 games)
      final numGames = _random.nextInt(3) + 1;
      final selectedGames = <String>[];
      final gamesCopy = List<String>.from(_games);
      for (int i = 0; i < numGames; i++) {
        final game = gamesCopy.removeAt(_random.nextInt(gamesCopy.length));
        selectedGames.add(game);
      }

      // 5. Location
      final location = _locations[_random.nextInt(_locations.length)];

      // 6. Bio
      final bio = _bios[_random.nextInt(_bios.length)];

      // 7. Rank (ĐÚNG OPTIONS)
      final rank = _ranks[_random.nextInt(_ranks.length)];

      // 8. Play Time (0-5000 giờ)
      final playTime = _random.nextInt(5001);

      // 9. Win Rate (30-80%)
      final winRate = 30 + _random.nextInt(51);

      // 10. Interests (2-5 sở thích) (ĐÚNG OPTIONS)
      final numInterests = 2 + _random.nextInt(4);
      final interests = <String>[];
      final interestsCopy = List<String>.from(_allInterests);
      for (int i = 0; i < numInterests; i++) {
        final interest = interestsCopy.removeAt(
          _random.nextInt(interestsCopy.length),
        );
        interests.add(interest);
      }

      // 11. Looking For (ĐÚNG OPTIONS)
      final lookingFor =
          _lookingForOptions[_random.nextInt(_lookingForOptions.length)];

      // 12. Game Style (ĐÚNG OPTIONS)
      final gameStyle = _gameStyles[_random.nextInt(_gameStyles.length)];

      // 13. Avatar (phù hợp với giới tính)
      final avatarUrl = _getAvatarByGender(gender);

      // 14. Additional Photos (0-4 ảnh)
      final numAdditionalPhotos = _random.nextInt(5);
      final additionalPhotos = <String>[];
      for (int i = 0; i < numAdditionalPhotos; i++) {
        final photoNum = _random.nextInt(1000);
        additionalPhotos.add('https://picsum.photos/400/600?random=$photoNum');
      }

      // 15. Premium Status (10% chance)
      final isPremium = _random.nextInt(10) == 0;

      // 16. Online Status (20% chance)
      final isOnline = _random.nextInt(5) == 0;

      // 17. Verification Status (30% chance)
      final isVerified = _random.nextInt(10) < 3;

      // === TẠO PROFILE DATA ĐẦY ĐỦ ===
      final profileData = {
        // Basic Info
        'uid': user.uid,
        'email': email,
        'username': username,
        'displayName': displayName,
        'photoURL': avatarUrl,
        'avatarUrl': avatarUrl,
        'bio': bio,

        // Personal Info
        'gender': gender,
        'birthDate': birthDate.toIso8601String(),
        'age': age,
        'height': height,

        // Game Info
        'favoriteGames': selectedGames,
        'rank': rank,
        'playTime': playTime,
        'winRate': winRate,
        'gameStyle': gameStyle,

        // Social Info
        'interests': interests,
        'lookingFor': lookingFor,

        // Location
        'location': {
          'city': location['city'],
          'latitude': location['lat'],
          'longitude': location['lng'],
          'updatedAt': DateTime.now().toIso8601String(),
        },

        // Media
        'additionalPhotos': additionalPhotos,

        // Status
        'isOnline': isOnline,
        'lastSeen': DateTime.now().toIso8601String(),
        'isPremium': isPremium,
        'isVerified': isVerified,
        'isTestAccount': true,

        // Timestamps
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),

        // Stats
        'matchCount': _random.nextInt(50),
        'friendCount': _random.nextInt(100),
        'likeCount': _random.nextInt(200),
        'superLikeCount': _random.nextInt(20),

        // Settings
        'showAge': _random.nextBool(),
        'showDistance': _random.nextBool(),
        'showOnlineStatus': _random.nextBool(),

        // === THÊM CÁC TRƯỜNG MỚI ===
        'subscriptionTier': 'free',
        'subscriptionEndDate': null,
        'incognitoMode': false,
        'blockedUserIds': [],
        'reportedUserIds': [],
        'profileViews': _random.nextInt(100),
        'totalMatches': _random.nextInt(50),
        'totalLikes': _random.nextInt(200),
        'totalSuperLikes': _random.nextInt(20),
      };

      // ✅ Lưu vào Firestore với merge để ghi đè nếu đã tồn tại
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      _logger.i(
        '✓ Đã tạo/cập nhật user: $email (username: $username, ${location['city']}, $age tuổi, $gender, $rank)',
      );

      // Đăng xuất để tạo user tiếp theo
      await _auth.signOut();

      return {
        'email': email,
        'username': username,
        'password': password,
        'displayName': displayName,
        'city': location['city'],
        'age': age,
        'gender': gender,
        'games': selectedGames,
        'rank': rank,
        'gameStyle': gameStyle,
        'lookingFor': lookingFor,
        'avatar': avatarUrl,
        'photos': additionalPhotos.length,
      };
    } catch (e) {
      _logger.e('✗ Lỗi khi tạo user ${index}: $e');
      return null;
    }
  }

  /// Hàm bỏ dấu tiếng Việt để tạo username
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

  /// Tạo nhiều users
  Future<List<Map<String, dynamic>>> createMultipleUsers(int count) async {
    _logger.i('=== BẮT ĐẦU TẠO $count USERS ===\n');

    final createdUsers = <Map<String, dynamic>>[];

    for (int i = 1; i <= count; i++) {
      final userData = await createRandomUser(i);
      if (userData != null) {
        createdUsers.add(userData);
      }

      // Delay nhỏ giữa các lần tạo để tránh rate limit
      await Future.delayed(const Duration(milliseconds: 500));

      // Log progress mỗi 10 users
      if (i % 10 == 0) {
        _logger.i('--- Đã tạo $i/$count users ---');
      }
    }

    _logger.i('\n=== HOÀN TẤT ===');
    _logger.i('Đã tạo thành công: ${createdUsers.length}/$count users');

    return createdUsers;
  }

  /// Export danh sách users ra console
  void exportUsersList(List<Map<String, dynamic>> users) {
    _logger.i('\n=== DANH SÁCH USERS ĐÃ TẠO ===\n');
    _logger.i(
      'STT | Email | Username | Tên | Tuổi | Giới tính | Thành phố | Rank',
    );
    _logger.i('-' * 150);

    for (int i = 0; i < users.length; i++) {
      final user = users[i];
      _logger.i(
        '${i + 1} | '
        '${user['email']} | '
        '${user['username']} | ' //  Hiển thị username
        '${user['displayName']} | '
        '${user['age']} | '
        '${user['gender']} | '
        '${user['city']} | '
        '${user['rank']} | '
        '${user['gameStyle']} | '
        '${user['lookingFor']}',
      );
    }
  }

  /// Xóa tất cả test users
  Future<void> deleteAllTestUsers() async {
    _logger.i('=== XÓA TẤT CẢ TEST USERS ===\n');

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isTestAccount', isEqualTo: true)
          .get();

      _logger.i('Tìm thấy ${snapshot.docs.length} test users');

      int deleted = 0;
      for (var doc in snapshot.docs) {
        try {
          await doc.reference.delete();
          deleted++;
          _logger.i('✓ Đã xóa user: ${doc.data()['email']}');
        } catch (e) {
          _logger.e('✗ Lỗi khi xóa user ${doc.data()['email']}: $e');
        }
      }

      _logger.i('\n=== HOÀN TẤT ===');
      _logger.i('Đã xóa $deleted/${snapshot.docs.length} users từ Firestore');
      _logger.w('⚠️ Lưu ý: Cần xóa users từ Firebase Auth Console thủ công');
    } catch (e) {
      _logger.e('Lỗi: $e');
    }
  }
}

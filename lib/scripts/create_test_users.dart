import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class CreateTestUsers {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Danh sách tên Việt Nam
  final List<String> _firstNames = [
    'Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Huỳnh', 'Phan', 'Vũ', 'Võ', 'Đặng',
    'Bùi', 'Đỗ', 'Hồ', 'Ngô', 'Dương', 'Lý', 'Mai', 'Đinh', 'Trịnh', 'Tô'
  ];

  final List<String> _lastNames = [
    'Minh', 'Anh', 'Hùng', 'Dũng', 'Tuấn', 'Hải', 'Long', 'Nam', 'Quân', 'Khoa',
    'Thảo', 'Linh', 'Hương', 'Lan', 'Mai', 'Hà', 'Trang', 'Ngọc', 'Phương', 'Châu',
    'Khánh', 'Đức', 'Thành', 'Phúc', 'Bảo', 'Thiên', 'An', 'Bình', 'Hoàng', 'Tâm'
  ];

  // Danh sách game phổ biến
  final List<String> _games = [
    'Liên Quân Mobile',
    'PUBG Mobile',
    'Free Fire',
    'Mobile Legends',
    'Tốc Chiến',
    'Valorant',
    'League of Legends',
    'Dota 2',
    'CS:GO',
    'Genshin Impact',
    'Minecraft',
    'Among Us',
    'FIFA Online 4',
    'Võ Lâm Truyền Kỳ',
    'Blade & Soul',
  ];

  // Danh sách tỉnh thành Việt Nam
  final List<Map<String, dynamic>> _locations = [
    {'city': 'Hà Nội', 'lat': 21.0285, 'lng': 105.8542},
    {'city': 'Hồ Chí Minh', 'lat': 10.8231, 'lng': 106.6297},
    {'city': 'Đà Nẵng', 'lat': 16.0544, 'lng': 108.2022},
    {'city': 'Hải Phòng', 'lat': 20.8449, 'lng': 106.6881},
    {'city': 'Cần Thơ', 'lat': 10.0452, 'lng': 105.7469},
    {'city': 'Biên Hòa', 'lat': 10.9510, 'lng': 106.8441},
    {'city': 'Nha Trang', 'lat': 12.2388, 'lng': 109.1967},
    {'city': 'Huế', 'lat': 16.4637, 'lng': 107.5909},
    {'city': 'Vũng Tàu', 'lat': 10.3460, 'lng': 107.0843},
    {'city': 'Buôn Ma Thuột', 'lat': 12.6667, 'lng': 108.0500},
  ];

  // Danh sách bio mẫu
  final List<String> _bios = [
    'Thích khám phá game mới, kết bạn cùng chơi.',
    'Luôn vui vẻ, không toxic, thích teamwork.',
    'Tìm đồng đội cùng leo rank, không bỏ cuộc.',
    'Chơi game để giải trí, ưu tiên vui là chính.',
    'Mê game chiến thuật, thích thử thách bản thân.',
    'Streamer nhỏ, thích giao lưu với mọi người.',
    'Tìm bạn chơi game lâu dài, cùng phát triển.',
    'Main support, luôn hỗ trợ đồng đội hết mình.',
    'Thích chơi game cùng bạn bè, không ngại thử thách.',
    'Tìm team cùng nhau chiến thắng mọi trận đấu.',
    'Yêu thích các tựa game MOBA và FPS.',
    'Chơi game mỗi ngày, không ngại học hỏi.',
    'Tìm người hướng dẫn, cùng nhau tiến bộ.',
    'Luôn sẵn sàng cho mọi kèo game mới.',
    'Game thủ đam mê, thích giao lưu kết bạn.',
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
  final List<String> _genders = [
    'Nam',
    'Nữ',
    'Khác',
  ];

  // Danh sách avatar URLs
  final List<String> _maleAvatars = [
    'https://images.unsplash.com/photo-1511367461989-f85a21fda167?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1465101046530-73398c7f28ca?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1519340333755-c89231c2e1e0?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?auto=format&fit=facearea&w=400&h=400',
  ];

  final List<String> _femaleAvatars = [
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1511367461989-f85a21fda167?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1465101046530-73398c7f28ca?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1519340333755-c89231c2e1e0?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=facearea&w=400&h=400',
  ];

  final List<String> _otherAvatars = [
    'https://images.unsplash.com/photo-1511367461989-f85a21fda167?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=facearea&w=400&h=400',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=facearea&w=400&h=400',
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
      final username = '${_removeVietnameseTones(firstName.toLowerCase())}${_removeVietnameseTones(lastName.toLowerCase())}${index.toString().padLeft(3, '0')}';
      
      final email = 'testuser${index.toString().padLeft(3, '7')}@gamenect.com';
      final password = 'Test@123';

      print('Đang tạo user: $email (username: $username)');

      // Tạo hoặc lấy user từ Firebase Auth
      User? user;
      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        user = userCredential.user;
        print('✓ Tạo mới Authentication user: $email');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Email đã tồn tại -> Đăng nhập để lấy UID
          print('⚠️  Email đã tồn tại, đang cập nhật dữ liệu: $email');
          try {
            final userCredential = await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            user = userCredential.user;
          } catch (signInError) {
            print('❌ Không thể đăng nhập với email $email: $signInError');
            return null;
          }
        } else {
          rethrow;
        }
      }

      if (user == null) {
        print('❌ Không tạo được user $email');
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
        final interest = interestsCopy.removeAt(_random.nextInt(interestsCopy.length));
        interests.add(interest);
      }

      // 11. Looking For (ĐÚNG OPTIONS)
      final lookingFor = _lookingForOptions[_random.nextInt(_lookingForOptions.length)];

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
      await _firestore.collection('users').doc(user.uid).set(
        profileData,
        SetOptions(merge: true),
      );

      print('✓ Đã tạo/cập nhật user: $email (username: $username, ${location['city']}, $age tuổi, $gender, $rank)');

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
      print('✗ Lỗi khi tạo user ${index}: $e');
      return null;
    }
  }

  /// Hàm bỏ dấu tiếng Việt để tạo username
  String _removeVietnameseTones(String str) {
    const vietnamese = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const latin = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    
    String result = str;
    for (int i = 0; i < vietnamese.length; i++) {
      result = result.replaceAll(vietnamese[i], latin[i]);
    }
    return result;
  }

  /// Tạo nhiều users
  Future<List<Map<String, dynamic>>> createMultipleUsers(int count) async {
    print('=== BẮT ĐẦU TẠO $count USERS ===\n');

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
        print('--- Đã tạo $i/$count users ---');
      }
    }

    print('\n=== HOÀN TẤT ===');
    print('Đã tạo thành công: ${createdUsers.length}/$count users');

    return createdUsers;
  }

  /// Export danh sách users ra console
  void exportUsersList(List<Map<String, dynamic>> users) {
    print('\n=== DANH SÁCH USERS ĐÃ TẠO ===\n');
    print('STT | Email | Username | Tên | Tuổi | Giới tính | Thành phố | Rank');
    print('-' * 150);

    for (int i = 0; i < users.length; i++) {
      final user = users[i];
      print(
        '${i + 1} | '
        '${user['email']} | '
        '${user['username']} | ' //  Hiển thị username
        '${user['displayName']} | '
        '${user['age']} | '
        '${user['gender']} | '
        '${user['city']} | '
        '${user['rank']} | '
        '${user['gameStyle']} | '
        '${user['lookingFor']}'
      );
    }
  }

  /// Xóa tất cả test users
  Future<void> deleteAllTestUsers() async {
    print('=== XÓA TẤT CẢ TEST USERS ===\n');

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isTestAccount', isEqualTo: true)
          .get();

      print('Tìm thấy ${snapshot.docs.length} test users');

      int deleted = 0;
      for (var doc in snapshot.docs) {
        try {
          await doc.reference.delete();
          deleted++;
          print('✓ Đã xóa user: ${doc.data()['email']}');
        } catch (e) {
          print('✗ Lỗi khi xóa user ${doc.data()['email']}: $e');
        }
      }

      print('\n=== HOÀN TẤT ===');
      print('Đã xóa $deleted/${snapshot.docs.length} users từ Firestore');
      print('⚠️ Lưu ý: Cần xóa users từ Firebase Auth Console thủ công');
    } catch (e) {
      print('Lỗi: $e');
    }
  }
}

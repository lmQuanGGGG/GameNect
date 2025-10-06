class UserModel {
  String id;
  String username;
  List<String> favoriteGames;
  String rank;
  String location; // Tên địa điểm (ví dụ: "Hà Nội")
  int playTime;
  int winRate;
  int points;
  final String? avatarUrl;
  final List<String> additionalPhotos;
  String gender;
  int age;
  int height;
  String bio;
  List<String> interests;
  String lookingFor;
  String gameStyle;
  final DateTime dateOfBirth;
  
  // ===== THÊM CÁC TRƯỜNG MỚI CHO LOCATION =====
  double? latitude;  // Vĩ độ
  double? longitude; // Kinh độ
  String? address;   // Địa chỉ đầy đủ
  String? city;      // Thành phố
  String? country;   // Quốc gia
  DateTime? lastLocationUpdate; // Lần cập nhật vị trí gần nhất
  
  // Cài đặt matching
  double maxDistance; // Khoảng cách tối đa cho matching (km)
  bool showDistance; // Hiển thị khoảng cách hay không
  int minAge; // Tuổi tối thiểu để match
  int maxAge; // Tuổi tối đa để match
  String interestedInGender; // Giới tính muốn tìm: 'Nam', 'Nữ', 'Tất cả'
  
  UserModel({
    required this.id,
    required this.username,
    required this.favoriteGames,
    required this.rank,
    required this.location,
    required this.dateOfBirth,
    this.playTime = 0,
    this.winRate = 0,
    this.points = 0,
    this.avatarUrl,
    this.additionalPhotos = const [],
    this.gender = 'Nam',
    this.age = 18,
    this.height = 160,
    this.bio = '',
    this.interests = const [],
    this.lookingFor = 'Bạn chơi game',
    this.gameStyle = 'Casual',
    // Thêm các giá trị mặc định cho location
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.country,
    this.lastLocationUpdate,
    this.maxDistance = 50.0, // Mặc định 50km
    this.showDistance = true,
    this.minAge = 18, // THÊM
    this.maxAge = 99, // THÊM
    this.interestedInGender = 'Tất cả', // THÊM
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'favoriteGames': favoriteGames,
      'rank': rank,
      'location': location,
      'playTime': playTime,
      'winRate': winRate,
      'points': points,
      'avatarUrl': avatarUrl,
      'additionalPhotos': additionalPhotos,
      'gender': gender,
      'age': age,
      'height': height,
      'bio': bio,
      'interests': interests,
      'lookingFor': lookingFor,
      'gameStyle': gameStyle,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      // Thêm location fields
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'country': country,
      'lastLocationUpdate': lastLocationUpdate?.toIso8601String(),
      'maxDistance': maxDistance,
      'showDistance': showDistance,
      'minAge': minAge, // THÊM
      'maxAge': maxAge, // THÊM
      'interestedInGender': interestedInGender, // THÊM
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      username: map['username'] ?? '',
      favoriteGames: List<String>.from(map['favoriteGames'] ?? []),
      rank: map['rank'] ?? 'Gà Mờ',
      location: map['location'] ?? '',
      playTime: (map['playTime'] ?? 0).toInt(),
      winRate: (map['winRate'] ?? 0).toInt(),
      points: (map['points'] ?? 0).toInt(),
      avatarUrl: map['avatarUrl'],
      additionalPhotos: List<String>.from(map['additionalPhotos'] ?? []),
      gender: map['gender'] ?? 'Khác',
      age: (map['age'] ?? 18).toInt(),
      height: (map['height'] ?? 160).toInt(),
      bio: map['bio'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      lookingFor: map['lookingFor'] ?? 'Bạn chơi game',
      gameStyle: map['gameStyle'] ?? 'Casual',
      dateOfBirth: map['dateOfBirth'] != null 
          ? DateTime.parse(map['dateOfBirth'])
          : DateTime(DateTime.now().year - ((map['age'] ?? 18) as int)),
      // Parse location fields
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      address: map['address'],
      city: map['city'],
      country: map['country'],
      lastLocationUpdate: map['lastLocationUpdate'] != null
          ? DateTime.parse(map['lastLocationUpdate'])
          : null,
      maxDistance: (map['maxDistance'] ?? 50.0).toDouble(),
      showDistance: map['showDistance'] ?? true,
      minAge: (map['minAge'] ?? 18).toInt(), // THÊM
      maxAge: (map['maxAge'] ?? 99).toInt(), // THÊM
      interestedInGender: map['interestedInGender'] ?? 'Tất cả', // THÊM
    );
  }
}

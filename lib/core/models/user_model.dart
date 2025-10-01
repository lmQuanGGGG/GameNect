class UserModel {
  String id;
  String username;
  List<String> favoriteGames; // Ví dụ: ["Liên Minh", "Free Fire"]
  String rank; // newbie, trung bình, pro
  String location; // Ví dụ: "Hà Nội", "TP.HCM"
  int playTime; // Thời gian chơi mỗi ngày (phút)
  int winRate; // Tỷ lệ thắng (%)
  int points; // Điểm thưởng gamification
  final String? avatarUrl; // URL ảnh đại diện
  final List<String> additionalPhotos; // Thêm trường ảnh bổ sung 
  // Thêm các trường mới
  String gender; // Nam/Nữ/Khác
  int age;
  int height; // Chiều cao (cm)
  String bio; // Giới thiệu bản thân
  List<String> interests; // Sở thích khác ngoài game
  String lookingFor; // Tìm kiếm mục đích gì (bạn chơi game, hẹn hò, etc)
  String gameStyle; // Phong cách chơi game (casual, competitive, etc)
  final DateTime dateOfBirth; // Thêm trường này
  
  UserModel({
    required this.id,
    required this.username,
    required this.favoriteGames,
    required this.rank,
    required this.location,
    this.playTime = 0,
    this.winRate = 0,
    this.points = 0,
    this.avatarUrl,
    this.additionalPhotos = const [],
    // Thay đổi ở đây - đặt các giá trị mặc định phù hợp
    this.gender = 'Nam',
    this.age = 18,
    this.height = 160,
    this.bio = '',
    this.interests = const [],
    this.lookingFor = 'Bạn chơi game',
    this.gameStyle = 'Casual',
    required this.dateOfBirth,
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
      // Thêm các trường mới vào map
      'gender': gender,
      'age': age,
      'height': height,
      'bio': bio,
      'interests': interests,
      'lookingFor': lookingFor,
      'gameStyle': gameStyle,
      'dateOfBirth': dateOfBirth.toIso8601String(), // Chuyển DateTime thành String
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
    lookingFor: map['lookingFor'] ?? '',
    gameStyle: map['gameStyle'] ?? 'Casual',
    dateOfBirth: map['dateOfBirth'] != null 
        ? DateTime.parse(map['dateOfBirth'])
        : DateTime(DateTime.now().year - ((map['age'] ?? 18) as int)),
  );
}

}

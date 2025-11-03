import 'package:cloud_firestore/cloud_firestore.dart';

// Lớp UserModel lưu toàn bộ thông tin cá nhân, cài đặt, trạng thái, quyền, thống kê và các thuộc tính liên quan đến một user trong hệ thống.
// Bao gồm thông tin cơ bản, vị trí, sở thích, game yêu thích, quyền admin, trạng thái premium, các trường nâng cao về bảo mật, thống kê, mạng xã hội, gaming...

class UserModel {
  // Các trường thông tin cá nhân cơ bản
  String id;                       
  String username;                 
  List<String> favoriteGames;      
  String rank;                     
  String location;                
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

  // Trường ngày sinh
  final DateTime dateOfBirth;

  // Các trường vị trí GPS
  double? latitude;
  double? longitude;
  String? address;
  String? city;
  String? country;
  DateTime? lastLocationUpdate;

  // Cài đặt ghép đôi/matching
  double maxDistance;              // Khoảng cách tối đa tìm kiếm
  bool showDistance;               // Có hiển thị khoảng cách không
  int minAge;                      // Tuổi tối thiểu tìm kiếm
  int maxAge;                      // Tuổi tối đa tìm kiếm
  String interestedInGender;       // Giới tính muốn ghép đôi

  // Các tính năng nâng cao
  bool isVerified;                 // Đã xác thực tài khoản chưa
  List<String> profilePrompts;     // Danh sách câu hỏi profile
  List<String> dealbreakers;       // Danh sách điều kiện loại trừ
  String? education;               // Trình độ học vấn
  String? occupation;              // Nghề nghiệp
  List<String> lifestyleBadges;    // Danh sách badge lối sống
  int boostCount;                  // Số lượt boost còn lại
  DateTime? lastBoostTime;         // Thời điểm boost gần nhất
  int superLikesRemaining;         // Số lượt super like còn lại
  DateTime? superLikesResetTime;   // Thời điểm reset super like
  bool canRewind;                  // Có thể quay lại swipe trước không
  bool showActiveStatus;           // Có hiển thị trạng thái hoạt động không
  DateTime? lastActiveTime;        // Thời điểm hoạt động gần nhất
  bool isOnline;                   // Đang online không
  bool readReceiptsEnabled;        // Có bật xác nhận đã đọc tin nhắn không
  String locationType;             // Loại vị trí (gps, manual...)

  // Thông tin subscription
  String subscriptionTier;         // Loại gói đăng ký (free, premium...)
  DateTime? subscriptionEndDate;   // Thời điểm hết hạn gói
  bool isPremium;                  // Đang là premium không

  // Mạng xã hội & xác thực
  Map<String, dynamic>? socialLinks; // Liên kết mạng xã hội

  String? phoneNumber;             // Số điện thoại
  bool phoneVerified;              // Đã xác thực số điện thoại chưa
  bool emailVerified;              // Đã xác thực email chưa

  // Quyền riêng tư
  bool incognitoMode;              // Chế độ ẩn danh
  List<String> blockedUserIds;     // Danh sách user bị chặn
  List<String> reportedUserIds;    // Danh sách user bị report

  // Thống kê
  int profileViews;                // Số lượt xem profile
  int totalMatches;                // Tổng số lần ghép đôi
  int totalLikes;                  // Tổng số lượt like
  int totalSuperLikes;             // Tổng số lượt super like

  // Thông tin gaming
  Map<String, dynamic>? gamingStats; // Thống kê gaming chi tiết
  List<String> gamingPlatforms;      // Danh sách nền tảng chơi game

  // Trường mới
  double? distanceKm;              // Khoảng cách đến user này (km)
  bool isAdmin;                    // Có phải admin không
  DateTime? premiumEndDate;        // Thời điểm hết hạn premium
  String? premiumPlan;             // Tên gói premium
  DateTime? premiumStartDate;      // Thời điểm bắt đầu premium

  // Hàm khởi tạo đối tượng UserModel với các tham số truyền vào.
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
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.country,
    this.lastLocationUpdate,
    this.maxDistance = 50.0,
    this.showDistance = true,
    this.minAge = 18,
    this.maxAge = 99,
    this.interestedInGender = 'Tất cả',
    this.isVerified = false,
    this.profilePrompts = const [],
    this.dealbreakers = const [],
    this.education,
    this.occupation,
    this.lifestyleBadges = const [],
    this.boostCount = 0,
    this.lastBoostTime,
    this.superLikesRemaining = 5,
    this.superLikesResetTime,
    this.canRewind = false,
    this.showActiveStatus = true,
    this.lastActiveTime,
    this.isOnline = false,
    this.readReceiptsEnabled = false,
    this.locationType = 'gps',
    this.subscriptionTier = 'free',
    this.subscriptionEndDate,
    this.isPremium = false,
    this.socialLinks,
    this.phoneNumber,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.incognitoMode = false,
    this.blockedUserIds = const [],
    this.reportedUserIds = const [],
    this.profileViews = 0,
    this.totalMatches = 0,
    this.totalLikes = 0,
    this.totalSuperLikes = 0,
    this.gamingStats,
    this.gamingPlatforms = const [],
    this.distanceKm,
    this.isAdmin = false,
    this.premiumEndDate,
    this.premiumPlan,
    this.premiumStartDate,
  });

  // Getter kiểm tra user có vị trí GPS chính xác không.
  bool get hasAccurateLocation =>
      locationType == 'gps' && latitude != null && longitude != null;

  // Getter kiểm tra user có thể boost không (dựa vào số lượt boost và thời gian boost gần nhất).
  bool get canBoost {
    if (boostCount <= 0) return false;
    if (lastBoostTime == null) return true;
    return DateTime.now().difference(lastBoostTime!).inHours >= 24;
  }

  // Getter kiểm tra user có thể super like không (dựa vào số lượt còn lại và thời gian reset).
  bool get canSuperLike {
    if (superLikesResetTime == null ||
        DateTime.now().isAfter(superLikesResetTime!)) {
      return true;
    }
    return superLikesRemaining > 0;
  }

  // Getter trả về chuỗi hiển thị vị trí của user.
  String get displayLocation {
    if (latitude != null && longitude != null) {
      // Có vị trí GPS
      return '$city, $country';
    } else if (lastLocationUpdate != null && city != null) {
      // Không có GPS, dùng vị trí cuối cùng
      return '$city, $country (lần cuối: ${lastLocationUpdate!.toLocal()})';
    } else {
      return 'Không xác định vị trí';
    }
  }

  // Hàm chuyển đối tượng UserModel thành Map để lưu vào Firestore.
  // Các trường thời gian được chuyển sang chuỗi ISO8601.
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
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'country': country,
      'lastLocationUpdate': lastLocationUpdate?.toIso8601String(),
      'maxDistance': maxDistance,
      'showDistance': showDistance,
      'minAge': minAge,
      'maxAge': maxAge,
      'interestedInGender': interestedInGender,
      'isVerified': isVerified,
      'profilePrompts': profilePrompts,
      'dealbreakers': dealbreakers,
      'education': education,
      'occupation': occupation,
      'lifestyleBadges': lifestyleBadges,
      'boostCount': boostCount,
      'lastBoostTime': lastBoostTime?.toIso8601String(),
      'superLikesRemaining': superLikesRemaining,
      'superLikesResetTime': superLikesResetTime?.toIso8601String(),
      'canRewind': canRewind,
      'showActiveStatus': showActiveStatus,
      'lastActiveTime': lastActiveTime?.toIso8601String(),
      'isOnline': isOnline,
      'readReceiptsEnabled': readReceiptsEnabled,
      'locationType': locationType,
      'subscriptionTier': subscriptionTier,
      'subscriptionEndDate': subscriptionEndDate?.toIso8601String(),
      'isPremium': isPremium,
      'socialLinks': socialLinks,
      'phoneNumber': phoneNumber,
      'phoneVerified': phoneVerified,
      'emailVerified': emailVerified,
      'incognitoMode': incognitoMode,
      'blockedUserIds': blockedUserIds,
      'reportedUserIds': reportedUserIds,
      'profileViews': profileViews,
      'totalMatches': totalMatches,
      'totalLikes': totalLikes,
      'totalSuperLikes': totalSuperLikes,
      'gamingStats': gamingStats,
      'gamingPlatforms': gamingPlatforms,
      'distanceKm': distanceKm,
      'isAdmin': isAdmin,
      'premiumEndDate': premiumEndDate?.toIso8601String(),
      'premiumPlan': premiumPlan,
      'premiumStartDate': premiumStartDate?.toIso8601String(),
    };
  }

  // Hàm tạo đối tượng UserModel từ Map lấy từ Firestore.
  // Xử lý các trường có thể là kiểu Map, List, String, Timestamp hoặc null.
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    final locationData = map['location'];
    final String locationString;
    final double? lat;
    final double? lon;
    
    if (locationData is Map) {
      locationString = locationData['city'] ?? '';
      lat = locationData['latitude']?.toDouble();
      lon = locationData['longitude']?.toDouble();
    } else {
      locationString = locationData?.toString() ?? '';
      lat = null;
      lon = null;
    }

    return UserModel(
      id: id,
      username: map['username'] ?? '',
      favoriteGames: (map['favoriteGames'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      rank: map['rank'] ?? 'Gà Mờ',
      location: locationString,
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
      latitude: lat ?? map['latitude']?.toDouble(),
      longitude: lon ?? map['longitude']?.toDouble(),
      address: map['address'],
      city: map['city'],
      country: map['country'],
      lastLocationUpdate: map['lastLocationUpdate'] != null
          ? DateTime.parse(map['lastLocationUpdate'])
          : null,
      maxDistance: (map['maxDistance'] ?? 50.0).toDouble(),
      showDistance: map['showDistance'] ?? true,
      minAge: (map['minAge'] ?? 18).toInt(),
      maxAge: (map['maxAge'] ?? 99).toInt(),
      interestedInGender: map['interestedInGender'] ?? 'Tất cả',
      isVerified: map['isVerified'] ?? false,
      profilePrompts: List<String>.from(map['profilePrompts'] ?? []),
      dealbreakers: List<String>.from(map['dealbreakers'] ?? []),
      education: map['education'],
      occupation: map['occupation'],
      lifestyleBadges: List<String>.from(map['lifestyleBadges'] ?? []),
      boostCount: (map['boostCount'] ?? 0).toInt(),
      lastBoostTime: map['lastBoostTime'] != null
          ? DateTime.parse(map['lastBoostTime'])
          : null,
      superLikesRemaining: (map['superLikesRemaining'] ?? 5).toInt(),
      superLikesResetTime: map['superLikesResetTime'] != null
          ? DateTime.parse(map['superLikesResetTime'])
          : null,
      canRewind: map['canRewind'] ?? false,
      showActiveStatus: map['showActiveStatus'] ?? true,
      lastActiveTime: map['lastActiveTime'] != null
          ? DateTime.parse(map['lastActiveTime'])
          : null,
      isOnline: map['isOnline'] ?? false,
      readReceiptsEnabled: map['readReceiptsEnabled'] ?? false,
      locationType: map['locationType'] ?? 'gps',
      subscriptionTier: map['subscriptionTier'] ?? 'free',
      subscriptionEndDate: map['subscriptionEndDate'] != null
          ? DateTime.parse(map['subscriptionEndDate'])
          : null,
      isPremium: map['isPremium'] ?? false,
      socialLinks: map['socialLinks'] != null
          ? Map<String, dynamic>.from(map['socialLinks'])
          : null,
      phoneNumber: map['phoneNumber'],
      phoneVerified: map['phoneVerified'] ?? false,
      emailVerified: map['emailVerified'] ?? false,
      incognitoMode: map['incognitoMode'] ?? false,
      blockedUserIds: List<String>.from(map['blockedUserIds'] ?? []),
      reportedUserIds: List<String>.from(map['reportedUserIds'] ?? []),
      profileViews: (map['profileViews'] ?? 0).toInt(),
      totalMatches: (map['totalMatches'] ?? 0).toInt(),
      totalLikes: (map['totalLikes'] ?? 0).toInt(),
      totalSuperLikes: (map['totalSuperLikes'] ?? 0).toInt(),
      gamingStats: map['gamingStats'],
      gamingPlatforms: List<String>.from(map['gamingPlatforms'] ?? []),
      distanceKm: map['distanceKm']?.toDouble(),
      isAdmin: map['isAdmin'] ?? false,
      premiumEndDate: map['premiumEndDate'] != null
          ? (map['premiumEndDate'] is Timestamp
              ? (map['premiumEndDate'] as Timestamp).toDate()
              : DateTime.tryParse(map['premiumEndDate'].toString()))
          : null,
      premiumPlan: map['premiumPlan'],
      premiumStartDate: map['premiumStartDate'] != null
          ? (map['premiumStartDate'] is Timestamp
              ? (map['premiumStartDate'] as Timestamp).toDate()
              : DateTime.tryParse(map['premiumStartDate'].toString()))
          : null,
    );
  }

  // Hàm copyWith cho phép tạo bản sao của UserModel với một số trường thay đổi.
  // Các trường không truyền vào sẽ giữ nguyên giá trị cũ.
  UserModel copyWith({
    String? id,
    String? username,
    List<String>? favoriteGames,
    String? rank,
    String? location,
    int? playTime,
    int? winRate,
    int? points,
    String? avatarUrl,
    List<String>? additionalPhotos,
    String? gender,
    int? age,
    int? height,
    String? bio,
    List<String>? interests,
    String? lookingFor,
    String? gameStyle,
    DateTime? dateOfBirth,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? country,
    DateTime? lastLocationUpdate,
    double? maxDistance,
    bool? showDistance,
    int? minAge,
    int? maxAge,
    String? interestedInGender,
    bool? isVerified,
    // Premium fields
    bool? isPremium,
    String? premiumPlan,
    DateTime? premiumStartDate,
    DateTime? premiumEndDate,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      favoriteGames: favoriteGames ?? this.favoriteGames,
      rank: rank ?? this.rank,
      location: location ?? this.location,
      playTime: playTime ?? this.playTime,
      winRate: winRate ?? this.winRate,
      points: points ?? this.points,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      additionalPhotos: additionalPhotos ?? this.additionalPhotos,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      lookingFor: lookingFor ?? this.lookingFor,
      gameStyle: gameStyle ?? this.gameStyle,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      maxDistance: maxDistance ?? this.maxDistance,
      showDistance: showDistance ?? this.showDistance,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      interestedInGender: interestedInGender ?? this.interestedInGender,
      isVerified: isVerified ?? this.isVerified,
      isPremium: isPremium ?? this.isPremium,
      premiumPlan: premiumPlan ?? this.premiumPlan,
      premiumStartDate: premiumStartDate ?? this.premiumStartDate,
      premiumEndDate: premiumEndDate ?? this.premiumEndDate,
    );
  }
}
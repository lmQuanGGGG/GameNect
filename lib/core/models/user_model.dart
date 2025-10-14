import 'dart:math';

class UserModel {
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
  final DateTime dateOfBirth;

  // Location fields
  double? latitude;
  double? longitude;
  String? address;
  String? city;
  String? country;
  DateTime? lastLocationUpdate;

  // Matching settings
  double maxDistance;
  bool showDistance;
  int minAge;
  int maxAge;
  String interestedInGender;

  // Advanced features
  bool isVerified;
  List<String> profilePrompts;
  List<String> dealbreakers;
  String? education;
  String? occupation;
  List<String> lifestyleBadges;
  int boostCount;
  DateTime? lastBoostTime;
  int superLikesRemaining;
  DateTime? superLikesResetTime;
  bool canRewind;
  bool showActiveStatus;
  DateTime? lastActiveTime;
  bool isOnline;
  bool readReceiptsEnabled;
  String locationType;

  // Subscription
  String subscriptionTier;
  DateTime? subscriptionEndDate;
  bool isPremium;

  // Social & Verification
  Map<String, dynamic>? socialLinks;

  String? phoneNumber;
  bool phoneVerified;
  bool emailVerified;

  // Privacy
  bool incognitoMode;
  List<String> blockedUserIds;
  List<String> reportedUserIds;

  // Stats
  int profileViews;
  int totalMatches;
  int totalLikes;
  int totalSuperLikes;

  // Gaming Details
  Map<String, dynamic>? gamingStats;
  List<String> gamingPlatforms;

  // New field
  double? distanceKm;

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
  });

  // Getters
  bool get hasAccurateLocation =>
      locationType == 'gps' && latitude != null && longitude != null;

  bool get canBoost {
    if (boostCount <= 0) return false;
    if (lastBoostTime == null) return true;
    return DateTime.now().difference(lastBoostTime!).inHours >= 24;
  }

  bool get canSuperLike {
    if (superLikesResetTime == null ||
        DateTime.now().isAfter(superLikesResetTime!)) {
      return true;
    }
    return superLikesRemaining > 0;
  }

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
    };
  }

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
    );
  }

  
}
class GameModel {
  final int id;
  final String name;
  final String? backgroundImage;
  final double rating;
  final int ratingsCount;
  final DateTime? released;
  final List<String> genres;
  final List<String> platforms;
  final String? description;
  final List<String> tags;
  final int metacritic;
  final bool isTrending;

  GameModel({
    required this.id,
    required this.name,
    this.backgroundImage,
    required this.rating,
    required this.ratingsCount,
    this.released,
    required this.genres,
    required this.platforms,
    this.description,
    required this.tags,
    required this.metacritic,
    this.isTrending = false,
  });

  // Parse từ RAWG API response
  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      backgroundImage: json['background_image'],
      rating: (json['rating'] ?? 0).toDouble(),
      ratingsCount: json['ratings_count'] ?? 0,
      released: json['released'] != null
          ? DateTime.tryParse(json['released'])
          : null,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => g['name'] as String)
              .toList() ??
          [],
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((p) => p['platform']['name'] as String)
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => t['name'] as String)
              .toList() ??
          [],
      metacritic: json['metacritic'] ?? 0,
      isTrending: json['added'] != null && json['added'] > 10000,
    );
  }

  // Convert sang Map để lưu Firestore (optional)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'backgroundImage': backgroundImage,
      'rating': rating,
      'ratingsCount': ratingsCount,
      'released': released?.toIso8601String(),
      'genres': genres,
      'platforms': platforms,
      'tags': tags,
      'metacritic': metacritic,
      'isTrending': isTrending,
    };
  }

  // Copy with (để update state)
  GameModel copyWith({
    int? id,
    String? name,
    String? backgroundImage,
    double? rating,
    int? ratingsCount,
    DateTime? released,
    List<String>? genres,
    List<String>? platforms,
    String? description,
    List<String>? tags,
    int? metacritic,
    bool? isTrending,
  }) {
    return GameModel(
      id: id ?? this.id,
      name: name ?? this.name,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      rating: rating ?? this.rating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      released: released ?? this.released,
      genres: genres ?? this.genres,
      platforms: platforms ?? this.platforms,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      metacritic: metacritic ?? this.metacritic,
      isTrending: isTrending ?? this.isTrending,
    );
  }
}

// Model cho game detail (khi tap vào game)
class GameDetailModel extends GameModel {
  final String? descriptionRaw;
  final String? website;
  final List<String> screenshots;
  final int playtime;
  final List<String> developers;
  final List<String> publishers;

  GameDetailModel({
    required super.id,
    required super.name,
    super.backgroundImage,
    required super.rating,
    required super.ratingsCount,
    super.released,
    required super.genres,
    required super.platforms,
    super.description,
    required super.tags,
    required super.metacritic,
    super.isTrending,
    this.descriptionRaw,
    this.website,
    required this.screenshots,
    required this.playtime,
    required this.developers,
    required this.publishers,
  });

  factory GameDetailModel.fromJson(Map<String, dynamic> json) {
    return GameDetailModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      backgroundImage: json['background_image'],
      rating: (json['rating'] ?? 0).toDouble(),
      ratingsCount: json['ratings_count'] ?? 0,
      released: json['released'] != null
          ? DateTime.tryParse(json['released'])
          : null,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => g['name'] as String)
              .toList() ??
          [],
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((p) => p['platform']['name'] as String)
              .toList() ??
          [],
      description: json['description_raw'],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => t['name'] as String)
              .toList() ??
          [],
      metacritic: json['metacritic'] ?? 0,
      descriptionRaw: json['description_raw'],
      website: json['website'],
      screenshots: (json['short_screenshots'] as List<dynamic>?)
              ?.map((s) => s['image'] as String)
              .toList() ??
          [],
      playtime: json['playtime'] ?? 0,
      developers: (json['developers'] as List<dynamic>?)
              ?.map((d) => d['name'] as String)
              .toList() ??
          [],
      publishers: (json['publishers'] as List<dynamic>?)
              ?.map((p) => p['name'] as String)
              .toList() ??
          [],
      isTrending: json['added'] != null && json['added'] > 10000,
    );
  }
}
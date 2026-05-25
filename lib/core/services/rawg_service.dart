import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/game_model.dart';

class RawgService {
  // ======================================================
  // RAWG API KEY - LẤY TỪ .env GIỐNG EDIT_PROFILE_SCREEN
  // ======================================================
  final String _apiKey = dotenv.env['RAWG_API_KEY'] ?? '754a38d2419a4aee8924fd13b8193b0f';
  static const String _baseUrl = 'https://api.rawg.io/api';
  
  final _logger = Logger();

  // ======================================================
  // LẤY GAMES TRENDING (Ordering by -added)
  // ======================================================
  Future<List<GameModel>> getTrendingGames({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/games?key=$_apiKey&page=$page&page_size=$pageSize&ordering=-added,-rating&dates=2024-01-01,2025-12-31',
      );

      _logger.i('Fetching trending games');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>;

        final games = results
            .map((json) => GameModel.fromJson(json))
            .toList();

        _logger.i('Loaded ${games.length} trending games');
        return games;
      } else {
        _logger.e('Failed to load games: ${response.statusCode}');
        throw Exception('Failed to load trending games');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching trending games', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ======================================================
  // LẤY GAMES MỚI PHÁT HÀNH
  // ======================================================
  Future<List<GameModel>> getNewReleases({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final now = DateTime.now();
      final oneMonthAgo = now.subtract(const Duration(days: 30));
      final dateStr = '${oneMonthAgo.year}-${oneMonthAgo.month.toString().padLeft(2, '0')}-${oneMonthAgo.day.toString().padLeft(2, '0')}';
      
      final url = Uri.parse(
        '$_baseUrl/games?key=$_apiKey&page=$page&page_size=$pageSize&ordering=-released&dates=$dateStr,${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>;

        return results.map((json) => GameModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load new releases');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching new releases', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ======================================================
  // LẤY GAMES THEO GENRE
  // ======================================================
  Future<List<GameModel>> getGamesByGenre(
    String genre, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/games?key=$_apiKey&page=$page&page_size=$pageSize&genres=$genre&ordering=-rating',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>;

        return results.map((json) => GameModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load games by genre');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching games by genre', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ======================================================
  // TÌM KIẾM GAMES
  // ======================================================
  Future<List<GameModel>> searchGames(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/games?key=$_apiKey&page=$page&page_size=$pageSize&search=$query',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>;

        return results.map((json) => GameModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search games');
      }
    } catch (e, stackTrace) {
      _logger.e('Error searching games', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ======================================================
  // LẤY CHI TIẾT GAME
  // ======================================================
  Future<GameDetailModel> getGameDetail(int gameId) async {
    try {
      final url = Uri.parse('$_baseUrl/games/$gameId?key=$_apiKey');

      _logger.i('Fetching game detail: $gameId');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GameDetailModel.fromJson(data);
      } else {
        throw Exception('Failed to load game detail');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching game detail', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ======================================================
  // LẤY DANH SÁCH GENRES
  // ======================================================
  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      final url = Uri.parse('$_baseUrl/genres?key=$_apiKey');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['results']);
      } else {
        throw Exception('Failed to load genres');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching genres', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
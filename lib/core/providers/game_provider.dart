import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_model.dart';
import '../services/rawg_service.dart';
import '../services/firestore_service.dart';

class GameProvider extends ChangeNotifier {
  final RawgService _rawgService = RawgService();
  final FirestoreService _firestoreService = FirestoreService();
  final _logger = Logger();

  // ======================================================
  // STATE
  // ======================================================
  List<GameModel> _trendingGames = [];
  List<GameModel> _newReleases = [];
  List<GameModel> _searchResults = [];
  GameDetailModel? _selectedGameDetail;
  
  bool _isLoadingTrending = false;
  bool _isLoadingNew = false;
  bool _isSearching = false;
  bool _isLoadingDetail = false;
  
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  // State cho Favorite
  bool _isFavorite = false;
  bool get isFavorite => _isFavorite;

  // State cho Filter
  String? _selectedGenre;
  String? get selectedGenre => _selectedGenre;
  
  // Danh sách Genres (Hardcode mẫu hoặc lấy từ API)
  final List<String> genres = ['Action', 'Indie', 'Adventure', 'RPG', 'Strategy', 'Shooter', 'Casual', 'Simulation', 'Puzzle', 'Arcade', 'Platformer', 'Racing', 'Sports'];

  // ======================================================
  // GETTERS
  // ======================================================
  List<GameModel> get trendingGames => _trendingGames;
  List<GameModel> get newReleases => _newReleases;
  List<GameModel> get searchResults => _searchResults;
  GameDetailModel? get selectedGameDetail => _selectedGameDetail;
  
  bool get isLoadingTrending => _isLoadingTrending;
  bool get isLoadingNew => _isLoadingNew;
  bool get isSearching => _isSearching;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get hasMore => _hasMore;
  
  String? get error => _error;

  // ======================================================
  // LOAD TRENDING GAMES
  // ======================================================
  Future<void> loadTrendingGames({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _trendingGames.clear();
    }

    if (_isLoadingTrending || !_hasMore) return;

    _isLoadingTrending = true;
    _error = null;
    notifyListeners();

    try {
      final games = await _rawgService.getTrendingGames(
        page: _currentPage,
        pageSize: 20,
      );

      if (games.isEmpty) {
        _hasMore = false;
      } else {
        _trendingGames.addAll(games);
        _currentPage++;
      }

      _logger.i('Loaded ${games.length} trending games');
    } catch (e, stackTrace) {
      _error = 'Không thể tải games: $e';
      _logger.e('Error loading trending games', error: e, stackTrace: stackTrace);
    } finally {
      _isLoadingTrending = false;
      notifyListeners();
    }
  }

  // ======================================================
  // LOAD NEW RELEASES
  // ======================================================
  Future<void> loadNewReleases() async {
    if (_isLoadingNew) return;

    _isLoadingNew = true;
    _error = null;
    notifyListeners();

    try {
      _newReleases = await _rawgService.getNewReleases(pageSize: 10);
      _logger.i('Loaded ${_newReleases.length} new releases');
    } catch (e, stackTrace) {
      _error = 'Không thể tải games mới: $e';
      _logger.e('Error loading new releases', error: e, stackTrace: stackTrace);
    } finally {
      _isLoadingNew = false;
      notifyListeners();
    }
  }

  // ======================================================
  // SEARCH GAMES
  // ======================================================
  Future<void> searchGames(String query) async {
    if (query.isEmpty) {
      _searchResults.clear();
      notifyListeners();
      return;
    }

    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      _searchResults = await _rawgService.searchGames(query, pageSize: 20);
      _logger.i('Found ${_searchResults.length} games for "$query"');
    } catch (e, stackTrace) {
      _error = 'Không thể tìm kiếm: $e';
      _logger.e('Error searching games', error: e, stackTrace: stackTrace);
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  // ======================================================
  // FAVORITE LOGIC
  // ======================================================

  Future<void> checkFavoriteStatus(int gameId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    _isFavorite = await _firestoreService.isGameFavorite(userId, gameId);
    notifyListeners();
  }

  Future<void> toggleFavorite() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _selectedGameDetail == null) return;

    // Optimistic UI Update (Cập nhật giao diện ngay lập tức)
    _isFavorite = !_isFavorite;
    notifyListeners();

    try {
      final result = await _firestoreService.toggleFavoriteGame(userId, _selectedGameDetail!);
      // Đồng bộ lại nếu kết quả khác dự đoán (hiếm khi xảy ra)
      if (result != _isFavorite) {
        _isFavorite = result;
        notifyListeners();
      }
    } catch (e) {
      // Revert nếu lỗi
      _isFavorite = !_isFavorite;
      notifyListeners();
      print("Error toggling favorite: $e");
    }
  }

  // ======================================================
  // FILTER LOGIC
  // ======================================================

  void setGenreFilter(String? genre) {
    if (_selectedGenre == genre) {
      _selectedGenre = null; // Toggle off
    } else {
      _selectedGenre = genre;
    }
    notifyListeners();
    
    // Reload list với filter mới
    if (_selectedGenre != null) {
      loadGamesByGenre(_selectedGenre!);
    } else {
      loadTrendingGames(refresh: true);
    }
  }

  Future<void> loadGamesByGenre(String genre) async {
    _isLoadingTrending = true;
    _trendingGames = []; // Clear list cũ
    notifyListeners();

    try {
      _trendingGames = await _rawgService.getGamesByGenre(genre.toLowerCase());
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingTrending = false;
      notifyListeners();
    }
  }
  
  // Cập nhật loadGameDetail để check favorite luôn
  Future<void> loadGameDetail(int gameId) async {
    _isLoadingDetail = true;
    _selectedGameDetail = null;
    notifyListeners();

    try {
      // Chạy song song: Lấy detail và Check favorite
      await Future.wait([
        _rawgService.getGameDetail(gameId).then((game) => _selectedGameDetail = game),
        checkFavoriteStatus(gameId),
      ]);
    } catch (e) {
      print(e);
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  // ======================================================
  // CLEAR SEARCH
  // ======================================================
  void clearSearch() {
    _searchResults.clear();
    notifyListeners();
  }

  // ======================================================
  // REFRESH ALL
  // ======================================================
  Future<void> refreshAll() async {
    await Future.wait([
      loadTrendingGames(refresh: true),
      loadNewReleases(),
    ]);
  }
}
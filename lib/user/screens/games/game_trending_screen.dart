import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../../../core/providers/game_provider.dart';
import '../../../core/models/game_model.dart';
import 'game_detail_screen.dart';

class GameTrendingScreen extends StatefulWidget {
  const GameTrendingScreen({super.key});

  @override
  State<GameTrendingScreen> createState() => _GameTrendingScreenState();
}

class _GameTrendingScreenState extends State<GameTrendingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Màu chủ đạo
  final Color _primaryColor = const Color(0xFFFF6E40);
  final Color _backgroundColor = const Color(0xFF101012);
  final Color _cardColor = const Color(0xFF1A1A1E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().loadTrendingGames();
      context.read<GameProvider>().loadNewReleases();
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_tabController.index == 0 &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9) {
      context.read<GameProvider>().loadTrendingGames();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6E40).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF6E40).withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6E40).withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.videogame_asset_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Discover',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            _buildSearchBar(),
            
            // Custom Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(4),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: const Color(0xFFFF6E40).withValues(alpha: 0.2),
                      border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.5), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6E40).withValues(alpha: 0.15),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    labelColor: const Color(0xFFFF6E40),
                    unselectedLabelColor: Colors.grey[500],
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 0.5),
                    dividerColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                    tabs: const [
                      Tab(text: 'Trending'),
                      Tab(text: 'New Releases'),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Consumer<GameProvider>(
                builder: (context, provider, child) {
                  if (_searchController.text.isNotEmpty) {
                    return _buildSearchResults(provider);
                  }
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTrendingTab(provider),
                      _buildNewReleasesTab(provider),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withValues(alpha: 0.05),
              child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search for games...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: _primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    context.read<GameProvider>().clearSearch();
                    setState(() {});
                  },
                )
              : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            onChanged: (query) {
              setState(() {});
              if (query.length >= 3) {
                context.read<GameProvider>().searchGames(query);
              } else if (query.isEmpty) {
                context.read<GameProvider>().clearSearch();
              }
            },
          ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildTrendingTab(GameProvider provider) {
    if (provider.isLoadingTrending && provider.trendingGames.isEmpty) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    if (provider.error != null && provider.trendingGames.isEmpty) {
      return _buildError(provider.error!, () => provider.loadTrendingGames(refresh: true));
    }

    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: _cardColor,
      onRefresh: () => provider.loadTrendingGames(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: provider.trendingGames.length + (provider.isLoadingTrending ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          if (index >= provider.trendingGames.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            );
          }
          return _buildModernGameCard(provider.trendingGames[index], index);
        },
      ),
    );
  }

  Widget _buildNewReleasesTab(GameProvider provider) {
    if (provider.isLoadingNew) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: _cardColor,
      onRefresh: provider.loadNewReleases,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: provider.newReleases.length,
        separatorBuilder: (context, index) => const SizedBox(height: 24),
        itemBuilder: (context, index) => _buildModernGameCard(provider.newReleases[index], index),
      ),
    );
  }

  Widget _buildSearchResults(GameProvider provider) {
    if (provider.isSearching) return Center(child: CircularProgressIndicator(color: _primaryColor));
    if (provider.searchResults.isEmpty) {
      return const Center(child: Text('No games found', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, index) => _buildModernGameCard(provider.searchResults[index], index),
    );
  }

  // ======================================================
  // MODERN GAME CARD (Immersive Style)
  // ======================================================
  Widget _buildModernGameCard(GameModel game, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameDetailScreen(gameId: game.id)),
        );
      },
      child: Container(
        height: 240, // Chiều cao cố định cho phong cách Cinematic
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6E40).withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Image
              game.backgroundImage != null
                  ? CachedNetworkImage(
                      imageUrl: game.backgroundImage!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: _cardColor),
                      errorWidget: (context, url, error) => Container(
                        color: _cardColor,
                        child: const Icon(Icons.videogame_asset, color: Colors.grey),
                      ),
                    )
                  : Container(color: _cardColor),

              // 2. Gradient Overlay (Bottom up)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.3, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // 3. Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating & Metacritic
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                game.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (game.metacritic > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _getMetacriticColor(game.metacritic),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Metascore ${game.metacritic}',
                              style: TextStyle(
                                color: _getMetacriticColor(game.metacritic),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Title
                    Text(
                      game.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Genres
                    if (game.genres.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.local_offer_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              game.genres.join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getMetacriticColor(int score) {
    if (score >= 75) return const Color(0xFF66CC33);
    if (score >= 50) return const Color(0xFFFFCC33);
    return const Color(0xFFFF0000);
  }
}
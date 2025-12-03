import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/game_provider.dart';
import '../../core/models/game_model.dart';
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
  final Color _primaryColor = const Color(0xFFBB86FC);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF1E1E1E);

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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.gamepad, color: _primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Discover Games',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 45,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: LinearGradient(
                    colors: [_primaryColor, Colors.purpleAccent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '🔥 Trending'),
                  Tab(text: '🆕 New Releases'),
                ],
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65, // Taller cards
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: provider.trendingGames.length + (provider.isLoadingTrending ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= provider.trendingGames.length) {
            return Center(child: CircularProgressIndicator(color: _primaryColor));
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
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: provider.newReleases.length,
        itemBuilder: (context, index) => _buildModernGameCard(provider.newReleases[index], index),
      ),
    );
  }

  Widget _buildSearchResults(GameProvider provider) {
    if (provider.isSearching) return Center(child: CircularProgressIndicator(color: _primaryColor));
    if (provider.searchResults.isEmpty) {
      return const Center(child: Text('No games found', style: TextStyle(color: Colors.grey)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: provider.searchResults.length,
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.95),
                    ],
                    stops: const [0.4, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // 3. Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating Badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 10, color: Colors.black),
                              const SizedBox(width: 2),
                              Text(
                                game.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (game.metacritic > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getMetacriticColor(game.metacritic).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getMetacriticColor(game.metacritic),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              game.metacritic.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Title
                    Text(
                      game.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Genres
                    if (game.genres.isNotEmpty)
                      Text(
                        game.genres.take(2).join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
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
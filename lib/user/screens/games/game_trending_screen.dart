import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/network_image.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/providers/game_provider.dart';
import '../../../core/models/game_model.dart';
import 'game_detail_screen.dart';
import '../../../core/theme/theme_helper.dart';

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
    final backgroundColor = context.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.scaffoldBackgroundColor, // Tự động đảo màu đen/trắng theo theme
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.textColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: context.textColor,
                            offset: const Offset(4, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2.0),
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: context.textColor, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Discover',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: context.textColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            _buildSearchBar(),
            
            // Custom Tab Bar (Neo-Brutalism)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              height: 54,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.textColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: context.textColor,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFFF6E40),
                  border: Border.all(color: context.textColor, width: 3),
                  boxShadow: [
                    BoxShadow(color: context.textColor, offset: const Offset(2, 2)),
                  ],
                ),
                labelColor: context.scaffoldBackgroundColor,
                unselectedLabelColor: context.textColor.withValues(alpha: 0.6),
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                tabs: const [
                  Tab(text: 'TRENDING'),
                  Tab(text: 'NEW RELEASES'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.textColor, width: 3),
          boxShadow: [
            BoxShadow(
              color: context.textColor,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'SEARCH FOR GAMES...',
            hintStyle: TextStyle(color: context.textColor.withValues(alpha: 0.5), fontWeight: FontWeight.w900),
            prefixIcon: Icon(Icons.search, color: context.textColor, size: 28),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: context.textColor),
                    onPressed: () {
                      _searchController.clear();
                      context.read<GameProvider>().clearSearch();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            filled: false,
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
    );
  }

  Widget _buildTrendingTab(GameProvider provider) {
    final cardColor = context.cardBgColor;
    if (provider.isLoadingTrending && provider.trendingGames.isEmpty) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    if (provider.error != null && provider.trendingGames.isEmpty) {
      return _buildError(provider.error!, () => provider.loadTrendingGames(refresh: true));
    }

    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: cardColor,
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
    final cardColor = context.cardBgColor;
    if (provider.isLoadingNew) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: cardColor,
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
      return Center(child: Text('No games found', style: TextStyle(color: context.textSecondaryColor)));
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
    final cardColor = context.cardBgColor;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameDetailScreen(gameId: game.id)),
        );
      },
      child: Container(
        height: 240, // Chiều cao cố định
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.textColor, width: 4),
          boxShadow: [
            BoxShadow(
              color: context.textColor,
              offset: const Offset(6, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12), // 16 - 4
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Image
              game.backgroundImage != null
                  ? GamenectNetworkImage(
                      imageUrl: game.backgroundImage!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: cardColor),
                      errorWidget: (context, url, error) => Container(
                        color: cardColor,
                        child: const Icon(Icons.videogame_asset, color: Colors.grey),
                      ),
                    )
                  : Container(color: cardColor),

              // 2. Gradient Overlay (Bottom up)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.9),
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
                            color: const Color(0xFFFFD54F),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Colors.black),
                              const SizedBox(width: 4),
                              Text(
                                game.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
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
                              color: _getMetacriticColor(game.metacritic),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                            ),
                            child: Text(
                              'SCORE ${game.metacritic}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Title
                    Text(
                      game.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 4),
                            blurRadius: 0,
                            color: Colors.black,
                          ),
                          Shadow(
                            offset: Offset(-2, -2),
                            blurRadius: 0,
                            color: Colors.black,
                          ),
                          Shadow(
                            offset: Offset(2, -2),
                            blurRadius: 0,
                            color: Colors.black,
                          ),
                          Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 0,
                            color: Colors.black,
                          ),
                          Shadow(
                            offset: Offset(-2, 2),
                            blurRadius: 0,
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
                          const Icon(Icons.local_offer_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              game.genres.join(' • ').toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
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
          Icon(Icons.cloud_off, size: 64, color: context.textTertiaryColor),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: context.textSecondaryColor)),
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
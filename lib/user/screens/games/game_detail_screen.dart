import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/game_provider.dart';
import '../../../core/models/game_model.dart';

class GameDetailScreen extends StatefulWidget {
  final int gameId;

  const GameDetailScreen({super.key, required this.gameId});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  final Color _primaryColor = const Color(0xFFBB86FC);
  final Color _backgroundColor = const Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().loadGameDetail(widget.gameId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Consumer<GameProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingDetail) {
            return Center(child: CircularProgressIndicator(color: _primaryColor));
          }

          if (provider.selectedGameDetail == null) {
            return const Center(
              child: Text('Could not load game details', style: TextStyle(color: Colors.grey)),
            );
          }

          final game = provider.selectedGameDetail!;
          return _buildModernContent(game);
        },
      ),
    );
  }

  Widget _buildModernContent(GameDetailModel game) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Modern App Bar
        SliverAppBar(
          expandedHeight: 350,
          pinned: true,
          backgroundColor: _backgroundColor,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (game.backgroundImage != null)
                  CachedNetworkImage(
                    imageUrl: game.backgroundImage!,
                    fit: BoxFit.cover,
                  ),
                // Gradient overlay for text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        _backgroundColor.withOpacity(0.5),
                        _backgroundColor,
                      ],
                      stops: const [0.5, 0.8, 1.0],
                    ),
                  ),
                ),
                // Title in AppBar
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (game.metacritic > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getMetacriticColor(game.metacritic),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Metacritic ${game.metacritic}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${game.rating} / 5',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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

        // 2. Content Body
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Grid
                _buildStatsGrid(game),
                const SizedBox(height: 24),

                // Genres
                if (game.genres.isNotEmpty) ...[
                  _buildSectionTitle('Genres'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: game.genres.map((g) => _buildChip(g)).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Description
                if (game.descriptionRaw != null) ...[
                  _buildSectionTitle('About'),
                  const SizedBox(height: 12),
                  Text(
                    game.descriptionRaw!,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Platforms
                if (game.platforms.isNotEmpty) ...[
                  _buildSectionTitle('Platforms'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: game.platforms.map((p) => _buildChip(p, isPlatform: true)).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Screenshots
                if (game.screenshots.isNotEmpty) ...[
                  _buildSectionTitle('Gallery'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: game.screenshots.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: game.screenshots[index],
                              width: 320,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Website Button
                if (game.website != null)
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, Colors.purpleAccent],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => _launchUrl(game.website!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.language, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Visit Official Website',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(GameDetailModel game) {
    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            Icons.calendar_today,
            'Released',
            game.released != null
                ? '${game.released!.day}/${game.released!.month}/${game.released!.year}'
                : 'TBA',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatBox(
            Icons.timer,
            'Playtime',
            '${game.playtime} hrs',
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primaryColor, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildChip(String label, {bool isPlatform = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isPlatform 
            ? Colors.blue.withOpacity(0.15) 
            : _primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlatform 
              ? Colors.blue.withOpacity(0.3) 
              : _primaryColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPlatform ? Colors.blue[200] : _primaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getMetacriticColor(int score) {
    if (score >= 75) return const Color(0xFF66CC33);
    if (score >= 50) return const Color(0xFFFFCC33);
    return const Color(0xFFFF0000);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch URL')),
        );
      }
    }
  }
}
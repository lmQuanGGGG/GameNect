// lib/user/screens/go_live_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/providers/livestream_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/theme/theme_helper.dart';
import 'package:flutter/cupertino.dart';

const _kAccent = Color(0xFFFF6E40);
const _kLiveBadge = Color(0xFFFF3B30);

final _kGames = [
  'LMHT', 'Valorant', 'PUBG', 'CS:GO', 'Dota 2',
  'Free Fire', 'Mobile Legends', 'Genshin Impact', 'Minecraft', 'Fortnite',
];

/// Màn hình chuẩn bị trước khi bắt đầu Livestream — Hỗ trợ Theme
class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final _titleCtrl = TextEditingController();
  String _selectedGame = 'LMHT';
  bool _isStarting = false;

  Widget _buildGlassContainer({required Widget child, double radius = 20}) {
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _startLive() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề stream'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isStarting = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profileProvider = context.read<ProfileProvider>();
    final userData = profileProvider.userData;
    final streamProvider = context.read<LivestreamProvider>();

    final streamId = await streamProvider.startStream(
      mentorId: user.uid,
      mentorUsername: userData?.username ?? 'Mentor',
      mentorAvatarUrl: userData?.avatarUrl ?? '',
      title: title,
      game: _selectedGame,
    );

    if (!mounted) return;
    setState(() => _isStarting = false);

    if (streamId != null) {
      Navigator.pushReplacementNamed(
        context,
        '/live-stream',
        arguments: {'streamId': streamId, 'isMentor': true},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể bắt đầu stream. Thử lại.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Bắt đầu Live',
          style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(CupertinoIcons.xmark, color: context.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.7)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background orbs
          Positioned(
            top: 50, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kLiveBadge.withValues(alpha: isDark ? 0.1 : 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kAccent.withValues(alpha: isDark ? 0.08 : 0.04),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [


                  // Title
                  Text(
                    'Tiêu đề stream *',
                    style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  _buildGlassContainer(
                    radius: 14,
                    child: TextField(
                      controller: _titleCtrl,
                      style: TextStyle(color: context.textColor),
                      maxLength: 80,
                      decoration: InputDecoration(
                        hintText: 'VD: Hướng dẫn leo rank Valorant cho người mới...',
                        hintStyle: TextStyle(color: context.textTertiaryColor, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                        counterStyle: TextStyle(color: context.textTertiaryColor),
                        prefixIcon: const Icon(CupertinoIcons.pen, color: _kAccent, size: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Game Search (RAWG API)
                  Text(
                    'Tên Game',
                    style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _selectedGame),
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.isEmpty) {
                        return _kGames;
                      }
                      final query = textEditingValue.text.trim();
                      final apiKey = dotenv.env['RAWG_API_KEY'];
                      
                      if (apiKey == null || apiKey.isEmpty) {
                        return _kGames.where((g) => g.toLowerCase().contains(query.toLowerCase()));
                      }

                      try {
                        final url = Uri.parse('https://api.rawg.io/api/games?key=$apiKey&search=$query&page_size=5');
                        final res = await http.get(url);
                        if (res.statusCode == 200) {
                          final data = jsonDecode(res.body);
                          final results = data['results'] as List;
                          final fetchedGames = results.map((e) => e['name'] as String).toList();
                          // Combine fetched with local defaults if they match
                          final localMatches = _kGames.where((g) => g.toLowerCase().contains(query.toLowerCase())).toList();
                          return {...localMatches, ...fetchedGames}.toList();
                        }
                      } catch (e) {
                        debugPrint('RAWG error: $e');
                      }
                      
                      return _kGames.where((g) => g.toLowerCase().contains(query.toLowerCase()));
                    },
                    onSelected: (String selection) {
                      setState(() {
                        _selectedGame = selection;
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      return _buildGlassContainer(
                        radius: 14,
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onEditingComplete: onEditingComplete,
                          style: TextStyle(color: context.textColor),
                          onChanged: (val) {
                            _selectedGame = val; // Also allow custom typed game names
                          },
                          decoration: InputDecoration(
                            hintText: 'Tìm hoặc nhập tên game...',
                            hintStyle: TextStyle(color: context.textTertiaryColor, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(14),
                            prefixIcon: const Icon(CupertinoIcons.gamecontroller, color: _kAccent, size: 20),
                          ),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: MediaQuery.of(context).size.width - 40,
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: context.cardBgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: context.cardBorderColor),
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option, style: TextStyle(color: context.textColor)),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Tips
                  _buildGlassContainer(
                    radius: 14,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(CupertinoIcons.lightbulb_fill, color: _kAccent, size: 18),
                              const SizedBox(width: 6),
                              Text('Mẹo stream hay', style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildTip('Đặt tiêu đề rõ ràng, hấp dẫn để thu hút người xem'),
                          _buildTip('Kiểm tra kết nối mạng trước khi bắt đầu'),
                          _buildTip('Nói chuyện với viewer để tăng tương tác'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Start button
                  GestureDetector(
                    onTap: _isStarting ? null : _startLive,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3B30), Color(0xFFFF6E40)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isStarting
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.play_circle_fill, size: 24, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Bắt đầu Live',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: TextStyle(color: context.textTertiaryColor)),
          Expanded(child: Text(text, style: TextStyle(color: context.textSecondaryColor, fontSize: 13))),
        ],
      ),
    );
  }
}

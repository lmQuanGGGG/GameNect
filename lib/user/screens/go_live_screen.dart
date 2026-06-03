// lib/user/screens/go_live_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/providers/livestream_provider.dart';
import '../../core/providers/profile_provider.dart';

const _kBg = Color(0xFF101012);
const _kAccent = Color(0xFFFF6E40);
const _kLiveBadge = Color(0xFFFF3B30);
const _kGlassBg = Color(0x14FFFFFF);
const _kGlassBorder = Color(0x1FFFFFFF);

final _kGames = [
  'LMHT', 'Valorant', 'PUBG', 'CS:GO', 'Dota 2',
  'Free Fire', 'Mobile Legends', 'Genshin Impact', 'Minecraft', 'Fortnite',
];

/// Màn hình chuẩn bị trước khi bắt đầu Livestream — Task 6.4
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: _kGlassBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _kGlassBorder, width: 1.5),
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
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Bắt đầu Live',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.white.withValues(alpha: 0.04)),
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
                color: _kLiveBadge.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kAccent.withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera preview placeholder
                  _buildGlassContainer(
                    radius: 20,
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kAccent.withValues(alpha: 0.2),
                              border: Border.all(color: _kAccent, width: 2),
                            ),
                            child: const Icon(Icons.videocam, color: _kAccent, size: 32),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Camera Preview',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Camera sẽ bật khi bắt đầu stream',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Tiêu đề stream *',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  _buildGlassContainer(
                    radius: 14,
                    child: TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      maxLength: 80,
                      decoration: InputDecoration(
                        hintText: 'VD: Hướng dẫn leo rank Valorant cho người mới...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                        counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        prefixIcon: const Icon(Icons.title, color: _kAccent, size: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Game dropdown
                  const Text(
                    'Game',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  _buildGlassContainer(
                    radius: 14,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGame,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E1E22),
                        icon: const Icon(Icons.expand_more, color: Colors.white54),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        style: const TextStyle(color: Colors.white),
                        items: _kGames.map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g),
                        )).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedGame = v);
                        },
                      ),
                    ),
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
                          const Row(
                            children: [
                              Icon(Icons.tips_and_updates, color: _kAccent, size: 18),
                              SizedBox(width: 6),
                              Text('Mẹo stream hay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isStarting ? null : _startLive,
                      icon: _isStarting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.live_tv_rounded, size: 22),
                      label: Text(
                        _isStarting ? 'Đang chuẩn bị...' : '🔴  Bắt đầu Live',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kLiveBadge,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        shadowColor: _kLiveBadge.withValues(alpha: 0.4),
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
          Text('•  ', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
          Expanded(child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13))),
        ],
      ),
    );
  }
}

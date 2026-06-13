// lib/user/screens/go_live_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/providers/livestream_provider.dart';
import '../../../core/providers/profile_provider.dart';

const _kAccent = Color(0xFFFF6E40);
const _kLiveRed = Color(0xFFFF2D55);
const _kDark = Color(0xFF1E1E24);
const _kCard = Color(0xFF2A2A32);
const _kLightBg = Color(0xFFF4F4F0);

final _kGames = [
  'LMHT', 'Valorant', 'PUBG', 'CS:GO', 'Dota 2',
  'Free Fire', 'Mobile Legends', 'Genshin Impact', 'Minecraft', 'Fortnite',
];

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final _titleCtrl = TextEditingController();
  String _selectedGame = 'LMHT';
  bool _isStarting = false;

  Future<void> _startLive() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Vui lòng nhập tiêu đề stream',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
          backgroundColor: _kLiveRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(0),
          ),
        ),
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

  // ── Neo-Brutalism input field (Hỗ trợ Sáng/Tối) ──────────────────────────
  Widget _neoInput(BuildContext context, {required Widget child, Color? customShadow}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bColor = isDark ? Colors.white : Colors.black;
    final sColor = customShadow ?? bColor;
    final cColor = isDark ? _kCard : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cColor,
        border: Border.all(color: bColor, width: 3),
        boxShadow: [BoxShadow(color: sColor, offset: const Offset(4, 4))],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _kDark : _kLightBg;
    final cardColor = isDark ? _kCard : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cardColor,
                        border: Border.all(color: borderColor, width: 3),
                        boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(3, 3))],
                      ),
                      child: Icon(Icons.close_rounded, color: textColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'BẮT ĐẦU LIVE',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kLiveRed,
                      border: Border.all(color: borderColor, width: 2),
                      boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(3, 3))],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BlinkingDot(),
                        SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(context, 'TIÊU ĐỀ STREAM *'),
                  const SizedBox(height: 10),
                  _neoInput(
                    context,
                    customShadow: _kLiveRed,
                    child: TextField(
                      controller: _titleCtrl,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLength: 80,
                      decoration: InputDecoration(
                        hintText: 'VD: Kéo Rank Tới Sáng — Valorant...',
                        hintStyle: TextStyle(
                          color: textColor.withValues(alpha: 0.35),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
                        prefixIcon: const Icon(CupertinoIcons.pen, color: _kAccent, size: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _sectionLabel(context, 'TÊN GAME'),
                  const SizedBox(height: 10),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _selectedGame),
                    optionsBuilder: (TextEditingValue v) async {
                      if (v.text.isEmpty) return _kGames;
                      final query = v.text.trim();
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
                          final fetched = results.map((e) => e['name'] as String).toList();
                          final local = _kGames.where((g) => g.toLowerCase().contains(query.toLowerCase())).toList();
                          return {...local, ...fetched}.toList();
                        }
                      } catch (e) {
                        debugPrint('RAWG error: $e');
                      }
                      return _kGames.where((g) => g.toLowerCase().contains(query.toLowerCase()));
                    },
                    onSelected: (String sel) => setState(() => _selectedGame = sel),
                    fieldViewBuilder: (context, controller, focusNode, onDone) {
                      return _neoInput(
                        context,
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onEditingComplete: onDone,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                          onChanged: (val) => _selectedGame = val,
                          decoration: InputDecoration(
                            hintText: 'Tìm hoặc nhập tên game...',
                            hintStyle: TextStyle(
                              color: textColor.withValues(alpha: 0.35),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
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
                            width: MediaQuery.of(context).size.width - 32,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: cardColor,
                              border: Border.all(color: borderColor, width: 3),
                              boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(4, 4))],
                            ),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, __) => Container(height: 1, color: borderColor.withValues(alpha: 0.1)),
                              itemBuilder: (context, i) {
                                final option = options.elementAt(i);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Tips box ─────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border.all(color: borderColor, width: 3),
                      boxShadow: const [BoxShadow(color: _kAccent, offset: Offset(4, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(CupertinoIcons.lightbulb_fill, color: _kAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'MẸO STREAM HAY',
                              style: TextStyle(
                                color: _kAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _tip(context, 'Đặt tiêu đề rõ ràng, hấp dẫn để thu hút người xem'),
                        _tip(context, 'Kiểm tra kết nối mạng trước khi bắt đầu'),
                        _tip(context, 'Nói chuyện với viewer để tăng tương tác'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Start button ─────────────────────────────────────────────
                  GestureDetector(
                    onTap: _isStarting ? null : _startLive,
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isStarting ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300) : _kLiveRed,
                        border: Border.all(color: borderColor, width: 3),
                        boxShadow: _isStarting ? null : [BoxShadow(color: shadowColor, offset: const Offset(5, 5))],
                      ),
                      child: Center(
                        child: _isStarting
                            ? CircularProgressIndicator(color: isDark ? Colors.white : Colors.black, strokeWidth: 3)
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.play_circle_fill, size: 26, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text(
                                    'BẮT ĐẦU LIVE',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
        fontWeight: FontWeight.w900,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _tip(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('▸  ', style: TextStyle(color: _kAccent, fontWeight: FontWeight.w900)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Blinking dot ────────────────────────────────────────────────────────────
class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: _c.value,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
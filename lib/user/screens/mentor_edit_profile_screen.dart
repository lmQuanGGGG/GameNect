// lib/user/screens/mentor_edit_profile_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/models/mentor_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/theme_helper.dart';

const _kAccent = Color(0xFFFF6E40);

class MentorEditProfileScreen extends StatefulWidget {
  final MentorModel mentor;
  const MentorEditProfileScreen({super.key, required this.mentor});

  @override
  State<MentorEditProfileScreen> createState() =>
      _MentorEditProfileScreenState();
}

class _MentorEditProfileScreenState extends State<MentorEditProfileScreen> {
  late final TextEditingController _bioCtrl;
  late final TextEditingController _achCtrl;
  late List<String> _selectedGames;
  bool _isSaving = false;

  final List<String> _hotGames = [
    'League of Legends',
    'Arena of Valor',
    'Free Fire',
    'Genshin Impact',
    'PUBG Mobile',
    'Valorant',
    'Call of Duty: Mobile',
    'FIFA Online 4',
    'Minecraft',
    'Mobile Legends',
    'Dota 2',
    'CS:GO',
    'Fortnite',
  ];

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: widget.mentor.bio);
    _achCtrl = TextEditingController(text: widget.mentor.achievements);
    _selectedGames = List.from(widget.mentor.games);
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _achCtrl.dispose();
    super.dispose();
  }

  Future<List<String>> _searchGamesAsync(String query) async {
    if (query.isEmpty) return _hotGames;
    try {
      final apiKey = dotenv.env['RAWG_API_KEY'] ?? '';
      final res = await http.get(Uri.parse(
        'https://api.rawg.io/api/games?key=$apiKey&search=$query&page_size=10',
      ));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['results'] as List)
            .map((e) => e['name'] as String)
            .toList();
      }
    } catch (_) {}
    return _hotGames
        .where((g) => g.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<void> _save() async {
    if (_bioCtrl.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bio tối thiểu 20 ký tự'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedGames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chọn ít nhất 1 game'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirestoreService().updateMentorProfile(
        mentorId: uid,
        bio: _bioCtrl.text.trim(),
        achievements: _achCtrl.text.trim(),
        games: _selectedGames,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã lưu hồ sơ!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Glass container — respects theme
  Widget _glass({required Widget child, double radius = 16}) {
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.07),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
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
          'Chỉnh sửa hồ sơ Mentor',
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: _kAccent, strokeWidth: 2),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(
                      color: _kAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ambient orbs
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kAccent.withValues(
                    alpha: isDark ? 0.07 : 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBF360C).withValues(
                    alpha: isDark ? 0.08 : 0.04),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bio
                _sectionLabel('📝 Giới thiệu bản thân'),
                const SizedBox(height: 8),
                _glass(
                  child: TextField(
                    controller: _bioCtrl,
                    maxLines: 5,
                    maxLength: 500,
                    style: TextStyle(color: context.textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Kể về bản thân, phong cách chơi, kinh nghiệm...',
                      hintStyle: TextStyle(
                          color: context.textTertiaryColor, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      counterStyle:
                          TextStyle(color: context.textTertiaryColor),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Games
                _sectionLabel('🎮 Game chuyên môn'),
                const SizedBox(height: 8),
                _glass(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textTheme: TextTheme(
                        titleMedium: TextStyle(color: context.textColor),
                      ),
                    ),
                    child: DropdownSearch<String>.multiSelection(
                      items: (filter, props) => _searchGamesAsync(filter),
                      selectedItems: _selectedGames,
                      compareFn: (i, s) => i == s,
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          hintText: 'Chọn game chuyên môn...',
                          hintStyle:
                              TextStyle(color: context.textTertiaryColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          prefixIcon:
                              const Icon(Icons.sports_esports, color: _kAccent),
                        ),
                      ),
                      popupProps: PopupPropsMultiSelection.dialog(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          style: TextStyle(color: context.textColor),
                          decoration: InputDecoration(
                            hintText: 'Tìm game...',
                            hintStyle: TextStyle(
                                color: context.textTertiaryColor),
                            prefixIcon:
                                const Icon(Icons.search, color: _kAccent),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.black.withValues(alpha: 0.08)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.black.withValues(alpha: 0.08)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: _kAccent, width: 1.5),
                            ),
                          ),
                        ),
                        dialogProps: DialogProps(
                          backgroundColor: context.dialogBgColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                          ),
                        ),
                        itemBuilder: (context, item, isSelected, isDisabled) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      color: isSelected
                                          ? _kAccent
                                          : context.textColor,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle,
                                      color: _kAccent, size: 18),
                              ],
                            ),
                          );
                        },
                      ),
                      onChanged: (items) =>
                          setState(() => _selectedGames = items),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Achievements
                _sectionLabel('🏆 Thành tích / Kinh nghiệm'),
                const SizedBox(height: 8),
                _glass(
                  child: TextField(
                    controller: _achCtrl,
                    maxLines: 4,
                    maxLength: 300,
                    style: TextStyle(color: context.textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Rank cao nhất, giải thưởng, số năm kinh nghiệm...',
                      hintStyle: TextStyle(
                          color: context.textTertiaryColor, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      counterStyle:
                          TextStyle(color: context.textTertiaryColor),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Đang lưu...' : 'Lưu hồ sơ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: TextStyle(
          color: context.textColor,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      );
}

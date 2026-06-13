// lib/user/screens/mentor_edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/models/mentor_model.dart';
import '../../../core/services/firestore_service.dart';

const _kAccent = Color(0xFFFF6E40);
const _kDarkBg = Color(0xFF121214);
const _kLightBg = Color(0xFFF4F4F0);
const _kDarkCard = Color(0xFF2A2A32);
const _kLightCard = Colors.white;

class MentorEditProfileScreen extends StatefulWidget {
  final MentorModel mentor;
  const MentorEditProfileScreen({super.key, required this.mentor});

  @override
  State<MentorEditProfileScreen> createState() => _MentorEditProfileScreenState();
}

class _MentorEditProfileScreenState extends State<MentorEditProfileScreen> {
  late final TextEditingController _bioCtrl;
  late final TextEditingController _achCtrl;
  late List<String> _selectedGames;
  bool _isSaving = false;

  final List<String> _hotGames = [
    'League of Legends', 'Arena of Valor', 'Free Fire', 'Genshin Impact',
    'PUBG Mobile', 'Valorant', 'Call of Duty: Mobile', 'FIFA Online 4',
    'Minecraft', 'Mobile Legends', 'Dota 2', 'CS:GO', 'Fortnite',
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
      final res = await http.get(Uri.parse('https://api.rawg.io/api/games?key=$apiKey&search=$query&page_size=10'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['results'] as List).map((e) => e['name'] as String).toList();
      }
    } catch (_) {}
    return _hotGames.where((g) => g.toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<void> _save() async {
    if (_bioCtrl.text.trim().length < 20) {
      _showError('Bio tối thiểu 20 ký tự');
      return;
    }
    if (_selectedGames.isEmpty) {
      _showError('Chọn ít nhất 1 game chuyên môn');
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
          content: Text('ĐÃ LƯU HỒ SƠ!', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(side: BorderSide(color: Colors.white, width: 2)),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
        backgroundColor: const Color(0xFFFF2D55),
        shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.white, width: 2)),
      ),
    );
  }

  // Helper cho khối nhập liệu
  Widget _neoInputBox(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? _kDarkCard : _kLightCard;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(4, 4))],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _kDarkBg : _kLightBg;
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? _kDarkCard : _kLightCard;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Neo App Bar ───────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(bottom: BorderSide(color: borderColor, width: 3)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _kAccent,
                        border: Border.all(color: borderColor, width: 3),
                        boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(3, 3))],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'SỬA HỒ SƠ',
                      style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSaving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _kAccent,
                        border: Border.all(color: borderColor, width: 3),
                        boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(3, 3))],
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                          : const Text('LƯU', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Nội dung form ─────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Bio ---
                  _sectionLabel(context, 'GIỚI THIỆU BẢN THÂN *'),
                  const SizedBox(height: 10),
                  _neoInputBox(
                    context,
                    child: TextField(
                      controller: _bioCtrl,
                      maxLines: 5,
                      maxLength: 500,
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Kể về bản thân, phong cách chơi, kinh nghiệm (tối thiểu 20 ký tự)...',
                        hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 13, fontWeight: FontWeight.w600),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: TextStyle(color: textColor.withValues(alpha: 0.5), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // --- Games ---
                  _sectionLabel(context, 'GAME CHUYÊN MÔN *'),
                  const SizedBox(height: 10),
                  _neoInputBox(
                    context,
                    child: DropdownSearch<String>.multiSelection(
                      items: (filter, props) => _searchGamesAsync(filter),
                      selectedItems: _selectedGames,
                      compareFn: (i, s) => i == s,
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          hintText: 'Nhấn để chọn game...',
                          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontWeight: FontWeight.w600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          prefixIcon: const Icon(CupertinoIcons.gamecontroller_fill, color: _kAccent),
                        ),
                      ),
                      popupProps: PopupPropsMultiSelection.dialog(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm tên game...',
                            hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontWeight: FontWeight.w600),
                            prefixIcon: const Icon(CupertinoIcons.search, color: _kAccent),
                            filled: true,
                            fillColor: bgColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: borderColor, width: 2)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: borderColor, width: 2)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: _kAccent, width: 3)),
                          ),
                        ),
                        dialogProps: DialogProps(
                          backgroundColor: cardColor,
                          shape: RoundedRectangleBorder(side: BorderSide(color: borderColor, width: 3)),
                        ),
                        itemBuilder: (context, item, isSelected, isDisabled) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.1), width: 1))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.toUpperCase(),
                                    style: TextStyle(color: isSelected ? _kAccent : textColor, fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                if (isSelected) const Icon(Icons.check_box_rounded, color: _kAccent, size: 22),
                              ],
                            ),
                          );
                        },
                      ),
                      onChanged: (items) => setState(() => _selectedGames = items),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // --- Achievements ---
                  _sectionLabel(context, 'THÀNH TÍCH / KINH NGHIỆM'),
                  const SizedBox(height: 10),
                  _neoInputBox(
                    context,
                    child: TextField(
                      controller: _achCtrl,
                      maxLines: 4,
                      maxLength: 300,
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'VD: Rank Thách đấu, Vô địch giải đấu sinh viên...\n(Mỗi thành tích xuống dòng)',
                        hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 13, fontWeight: FontWeight.w600),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: TextStyle(color: textColor.withValues(alpha: 0.5), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // --- Nút Save to (nếu cần ở dưới cùng) ---
                  GestureDetector(
                    onTap: _isSaving ? null : _save,
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isSaving ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300) : _kAccent,
                        border: Border.all(color: borderColor, width: 3),
                        boxShadow: _isSaving ? null : [BoxShadow(color: shadowColor, offset: const Offset(4, 4))],
                      ),
                      child: Center(
                        child: _isStartingOrSaving()
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

  Widget _isStartingOrSaving() {
      if(_isSaving) return CircularProgressIndicator(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, strokeWidth: 3);
      return const Text('LƯU HỒ SƠ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2));
  }

  Widget _sectionLabel(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
        fontWeight: FontWeight.w900,
        fontSize: 13,
        letterSpacing: 1.5,
      ),
    );
  }
}
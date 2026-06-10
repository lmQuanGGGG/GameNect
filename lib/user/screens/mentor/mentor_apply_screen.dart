import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as dev;
import '../../../core/providers/mentor_provider.dart';
import '../../../core/theme/theme_helper.dart';

// Design tokens
const _kAccent = Color(0xFFFF6E40);

/// Màn hình đăng ký trở thành Mentor — Hỗ trợ Light/Dark Theme
class MentorApplyScreen extends StatefulWidget {
  const MentorApplyScreen({super.key});

  @override
  State<MentorApplyScreen> createState() => _MentorApplyScreenState();
}

class _MentorApplyScreenState extends State<MentorApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioCtrl = TextEditingController();
  final _achCtrl = TextEditingController();
  List<String> _selectedGames = [];
  bool _isSubmitting = false;

  final List<String> _hotGames = [
    "League of Legends", "Arena of Valor", "Free Fire", "Genshin Impact",
    "PUBG Mobile", "Valorant", "Call of Duty: Mobile", "FIFA Online 4",
    "Minecraft", "Mobile Legends",
  ];

  Future<List<String>> _searchGamesAsync(String query) async {
    final apiKey = dotenv.env['RAWG_API_KEY'] ?? '754a38d2419a4aee8924fd13b8193b0f';
    if (query.isEmpty) {
      return _hotGames;
    }
    try {
      final response = await http.get(Uri.parse('https://api.rawg.io/api/games?key=$apiKey&search=$query&page_size=10'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final games = data['results'] as List;
        return games.map((game) => game['name'] as String).toList();
      }
    } catch (e) {
      dev.log('Error search games in mentor apply', name: 'MentorApply', error: e);
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        context.read<MentorProvider>().loadMyMentorProfile(userId);
      }
    });
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _achCtrl.dispose();
    super.dispose();
  }

  Widget _buildGlassContainer({required Widget child, double radius = 24}) {
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGames.isEmpty) {
      _showSnack('Vui lòng chọn ít nhất 1 game chuyên môn', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final ok = await context.read<MentorProvider>().applyForMentor(
      userId,
      games: _selectedGames,
      bio: _bioCtrl.text.trim(),
      achievements: _achCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      _showSuccessDialog();
    } else {
      _showSnack('Gửi đơn thất bại. Vui lòng thử lại.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.cardBorderColor),
        ),
        title: Row(children: [
          const Icon(Icons.check_circle, color: _kAccent),
          const SizedBox(width: 8),
          Text('Đã gửi đơn!', style: TextStyle(color: context.textColor)),
        ]),
        content: Text(
          'Đơn đăng ký Mentor của bạn đã được gửi.\nAdmin sẽ xem xét và phản hồi sớm nhất có thể.',
          style: TextStyle(color: context.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('OK', style: TextStyle(color: _kAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Consumer<MentorProvider>(
      builder: (context, provider, _) {
        final mentor = provider.myMentorProfile;

        return Scaffold(
          backgroundColor: context.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Đăng ký Mentor',
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: context.textColor),
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
                top: -60, right: -60,
                child: Container(
                  width: 280, height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kAccent.withValues(alpha: isDark ? 0.08 : 0.04),
                  ),
                ),
              ),
              Positioned(
                bottom: -80, left: -80,
                child: Container(
                  width: 320, height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFBF360C).withValues(alpha: isDark ? 0.1 : 0.05),
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: _buildContent(mentor, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(dynamic mentor, MentorProvider provider) {
    final isDark = context.isDarkMode;
    
    // Đang pending
    if (mentor?.status == 'pending') {
      return _buildStatusView(
        icon: Icons.hourglass_top_rounded,
        iconColor: Colors.amber,
        title: 'Đơn đang chờ duyệt',
        subtitle: 'Admin đang xem xét đơn đăng ký của bạn.\nVui lòng chờ phản hồi.',
      );
    }

    // Approved
    if (mentor?.status == 'approved') {
      return _buildStatusView(
        icon: Icons.verified_rounded,
        iconColor: _kAccent,
        title: 'Bạn đã là Mentor! ⭐',
        subtitle: 'Chúc mừng! Hồ sơ Mentor của bạn đã được phê duyệt.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildGlassContainer(
              radius: 20,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.school_rounded, size: 56, color: _kAccent),
                    const SizedBox(height: 12),
                    Text(
                      'Trở thành Mentor',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chia sẻ kiến thức gaming của bạn,\nhướng dẫn người chơi qua livestream và nhận gift từ người hâm mộ.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textSecondaryColor, fontSize: 14),
                    ),

                    // Lý do từ chối (nếu có)
                    if (mentor?.status == 'rejected' && mentor?.rejectReason != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Đơn trước đã bị từ chối:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(mentor!.rejectReason!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Game selection
            _buildSectionLabel('🎮 Game chuyên môn'),
            const SizedBox(height: 8),
            _buildGlassContainer(
              radius: 16,
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
                      hintText: "Chọn game chuyên môn...",
                      hintStyle: TextStyle(color: context.textTertiaryColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      prefixIcon: const Icon(Icons.sports_esports, color: _kAccent),
                    ),
                  ),
                  popupProps: PopupPropsMultiSelection.dialog(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      style: TextStyle(color: context.textColor),
                      decoration: InputDecoration(
                        hintText: "Gõ tên game (ví dụ: league...)",
                        hintStyle: TextStyle(color: context.textTertiaryColor),
                        prefixIcon: const Icon(Icons.search, color: _kAccent),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.cardBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.cardBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _kAccent, width: 1.5),
                        ),
                      ),
                    ),
                    dialogProps: DialogProps(
                      backgroundColor: context.cardBgColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: context.cardBorderColor, width: 1.5),
                      ),
                    ),
                    itemBuilder: (context, item, isSelected, isDisabled) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  color: isSelected ? _kAccent : context.textColor,
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: _kAccent, size: 18),
                          ],
                        ),
                      );
                    },
                  ),
                  onChanged: (results) {
                    setState(() => _selectedGames = results);
                  },
                  validator: (values) =>
                      values == null || values.isEmpty ? "Chọn ít nhất 1 game" : null,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Bio
            _buildSectionLabel('📝 Giới thiệu bản thân'),
            const SizedBox(height: 8),
            _buildGlassContainer(
              radius: 16,
              child: TextFormField(
                controller: _bioCtrl,
                maxLines: 4,
                style: TextStyle(color: context.textColor),
                decoration: InputDecoration(
                  hintText: 'Hãy kể về bản thân, phong cách chơi, kinh nghiệm...',
                  hintStyle: TextStyle(color: context.textTertiaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 20) {
                    return 'Tối thiểu 20 ký tự';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 20),

            // Achievements
            _buildSectionLabel('🏆 Thành tích / Kinh nghiệm'),
            const SizedBox(height: 8),
            _buildGlassContainer(
              radius: 16,
              child: TextFormField(
                controller: _achCtrl,
                maxLines: 4,
                style: TextStyle(color: context.textColor),
                decoration: InputDecoration(
                  hintText: 'Rank cao nhất đạt được, giải thưởng, số năm kinh nghiệm...',
                  hintStyle: TextStyle(color: context.textTertiaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 10) {
                    return 'Tối thiểu 10 ký tự';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white, // Cố định chữ trắng trên nền màu chủ đạo
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Gửi đơn đăng ký',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: context.textColor,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    );
  }

  Widget _buildStatusView({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: _buildGlassContainer(
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 72, color: iconColor),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(color: context.textSecondaryColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

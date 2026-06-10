import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/theme/theme_helper.dart';
import '../mentor/all_mentor_media_screen.dart';

class DiscoverMentorPostsPage extends StatelessWidget {
  const DiscoverMentorPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Orbs
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF9C27B0).withValues(alpha: 0.15 * context.bgOrbOpacityMultiplier),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF9C27B0).withValues(alpha: 0.2 * context.bgOrbOpacityMultiplier), blurRadius: kIsWeb ? 40 : 100),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.2,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE040FB).withValues(alpha: 0.1 * context.bgOrbOpacityMultiplier),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.15 * context.bgOrbOpacityMultiplier), blurRadius: kIsWeb ? 40 : 120),
                ],
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: kIsWeb
                    ? _buildCardContent(context, isWeb: true)
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: _buildCardContent(context, isWeb: false),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, {required bool isWeb}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.cardBgColor,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: context.cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE040FB).withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_mosaic_rounded, size: 70, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            'Mentor Posts',
            style: TextStyle(
              color: context.textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Khám phá hình ảnh và video độc quyền\ntừ các Mentor xịn xò',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondaryColor, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllMentorMediaScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE040FB), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6)),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Khám phá ngay',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard_double_arrow_up_rounded, color: context.textTertiaryColor, size: 24),
              const SizedBox(width: 8),
              Text('Vuốt lên để xem tiếp', style: TextStyle(color: context.textTertiaryColor, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

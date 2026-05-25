import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/theme/theme_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab Item data class
// ─────────────────────────────────────────────────────────────────────────────
class TabItemData {
  final IconData icon;
  final String label;
  const TabItemData({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// LiquidGlassTabBar — Floating Pill 3D Glassmorphism
// ─────────────────────────────────────────────────────────────────────────────
class LiquidGlassTabBar extends StatelessWidget {
  final int currentIndex;
  final Map<String, int> badges;
  final List<TabItemData> tabs;
  final List<AnimationController> itemControllers;
  final List<Animation<double>> itemScales;
  final List<Animation<double>> itemGlows;
  final ValueChanged<int> onTap;

  const LiquidGlassTabBar({
    super.key,
    required this.currentIndex,
    required this.badges,
    required this.tabs,
    required this.itemControllers,
    required this.itemScales,
    required this.itemGlows,
    required this.onTap,
  });

  int _badgeFor(int index) {
    switch (index) {
      case 1:
        return badges['moments'] ?? 0;
      case 2:
        return badges['likes'] ?? 0;
      case 3:
        return badges['messages'] ?? 0;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 16),
      child: _buildPill(context),
    );
  }

  Widget _buildPill(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        // ── Bóng đổ cực nhẹ để giữ độ trong suốt cao nhất ──
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.03 : 0.05),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFFFF6E40).withValues(alpha: isDark ? 0.08 : 0.12),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          // Giảm blur để thấy rõ nền bên dưới hơn
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                // Gradient cực mỏng, gần như trong suốt hoàn toàn
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.02),
                        Colors.white.withValues(alpha: 0.00),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.90),
                        Colors.white.withValues(alpha: 0.70),
                        Colors.white.withValues(alpha: 0.60),
                      ],
              ),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  tabs.length,
                  (i) => _TabItemWidget(
                    item: tabs[i],
                    isActive: i == currentIndex,
                    badge: _badgeFor(i),
                    scaleAnim: itemScales[i],
                    glowAnim: itemGlows[i],
                    onTap: () => onTap(i),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual Tab Item Widget
// ─────────────────────────────────────────────────────────────────────────────
class _TabItemWidget extends StatelessWidget {
  final TabItemData item;
  final bool isActive;
  final int badge;
  final Animation<double> scaleAnim;
  final Animation<double> glowAnim;
  final VoidCallback onTap;

  const _TabItemWidget({
    required this.item,
    required this.isActive,
    required this.badge,
    required this.scaleAnim,
    required this.glowAnim,
    required this.onTap,
  });

  static const _activeColor = Color(0xFFFF6E40); // Deep Orange Accent
  static const _activeDark = Color(0xFFE64A19);  // Deep Orange Dark
  static const _inactiveColor = Color(0xFFB0BEC5);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60, // Fixed width
        height: 72,
        child: AnimatedBuilder(
          animation: scaleAnim,
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: isActive ? scaleAnim.value : 1.0,
                  child: _buildIconContainer(context),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: isActive ? 9.5 : 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? _activeColor
                        : (context.isDarkMode ? _inactiveColor : const Color(0xFF7A8A99)).withValues(alpha: 0.85),
                    letterSpacing: isActive ? 0.3 : 0.0,
                  ),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIconContainer(BuildContext context) {
    if (isActive) {
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          _buildActiveIcon(),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: _buildBadge(badge),
            ),
        ],
      );
    } else {
      return _buildInactiveIcon(context);
    }
  }

  Widget _buildActiveIcon() {
    return AnimatedBuilder(
      animation: glowAnim,
      builder: (context, _) {
        final glow = glowAnim.value;
        return Container(
          width: 44,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.35, 1.0],
              colors: [
                Color(0xFFFFE0B2), // Cam nhạt tinh khiết
                Color(0xFFFF6E40), // Cam rực (Deep Orange)
                Color(0xFFBF360C), // Cam tối — độ sâu
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6E40).withValues(alpha: 0.55 * glow),
                blurRadius: 20,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFFFF6E40).withValues(alpha: 0.40 * glow),
                blurRadius: 8,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.30 * glow),
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 3,
                left: 5,
                child: Container(
                  width: 14,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.60),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Icon(
                  item.icon,
                  size: 20,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Color(0xFFBF360C), // Bóng cam đậm
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInactiveIcon(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 44,
          height: 36,
          child: Center(
            child: Icon(
              item.icon,
              size: 22,
              color: (context.isDarkMode ? _inactiveColor : const Color(0xFF7A8A99)).withValues(alpha: 0.80),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: 0,
            top: -4,
            child: _buildBadge(badge),
          ),
      ],
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3D71), Color(0xFFCC0033)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3D71).withValues(alpha: 0.50),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

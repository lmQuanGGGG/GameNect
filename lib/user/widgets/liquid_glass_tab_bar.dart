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
    return Container(
      height: 72,
      // Wrap everything in a Stack to create a "Hollow Shadow" for Neo-Brutalism + Glass
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hollow Shadow (just a border, no fill)
          Positioned.fill(
            top: 4,
            left: 4,
            bottom: -4,
            right: -4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: context.textColor, width: 3),
              ),
            ),
          ),
          // Actual Tab Bar
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: (context.isDarkMode ? Colors.black : Colors.white).withValues(alpha: context.isDarkMode ? 0.1 : 0.3),
                    border: Border.all(
                      color: context.textColor,
                      width: 3,
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
          ),
        ],
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
                    fontSize: isActive ? 10 : 9,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                    color: isActive
                        ? context.textColor
                        : context.textSecondaryColor,
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
          _buildActiveIcon(context),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: _buildBadge(badge, context),
            ),
        ],
      );
    } else {
      return _buildInactiveIcon(context);
    }
  }

  Widget _buildActiveIcon(BuildContext context) {
    return Container(
      width: 44,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6E40),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.textColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: context.textColor,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          item.icon,
          size: 20,
          color: context.scaffoldBackgroundColor,
        ),
      ),
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
              color: context.textSecondaryColor,
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: 0,
            top: -4,
            child: _buildBadge(badge, context),
          ),
      ],
    );
  }

  Widget _buildBadge(int count, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFFF3D71),
        border: Border.all(color: context.textColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: context.textColor,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

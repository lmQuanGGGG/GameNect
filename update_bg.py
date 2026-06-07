import re

filepath = '/Users/wang04/Downloads/GAMENECT/gamenect_new/lib/core/widgets/app_background.dart'

new_bg = """import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/theme_helper.dart';

class AppBackground extends StatefulWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Orbs with Animation
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  top: 50 + 20 * _controller.value,
                  right: -50 - 20 * _controller.value,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF6E40).withValues(alpha: 0.15 * context.bgOrbOpacityMultiplier),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6E40).withValues(alpha: 0.12 * context.bgOrbOpacityMultiplier),
                          blurRadius: kIsWeb ? 60 : 120,
                          spreadRadius: kIsWeb ? 30 : 50,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80 + 30 * _controller.value,
                  left: -80 - 10 * _controller.value,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFBF360C).withValues(alpha: 0.15 * context.bgOrbOpacityMultiplier),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBF360C).withValues(alpha: 0.12 * context.bgOrbOpacityMultiplier),
                          blurRadius: kIsWeb ? 60 : 140,
                          spreadRadius: kIsWeb ? 30 : 60,
                        ),
                      ],
                    ),
                  ),
                ),
                // Third orb for a more premium look
                Positioned(
                  top: MediaQuery.of(context).size.height / 2 - 150,
                  left: MediaQuery.of(context).size.width / 2 - 150 + 50 * (1 - _controller.value),
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.10 * context.bgOrbOpacityMultiplier),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.08 * context.bgOrbOpacityMultiplier),
                          blurRadius: kIsWeb ? 50 : 100,
                          spreadRadius: kIsWeb ? 20 : 40,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),
        ),
        // Noise texture overlay for a premium glassmorphism feel
        Positioned.fill(
          child: Opacity(
            opacity: 0.03,
            child: Image.network(
              'https://www.transparenttextures.com/patterns/stardust.png',
              repeat: ImageRepeat.repeat,
            ),
          ),
        ),
        // Main content
        widget.child,
      ],
    );
  }
}
"""
with open(filepath, 'w') as f:
    f.write(new_bg)


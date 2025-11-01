import 'package:flutter/material.dart';
import 'dart:ui';

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: size * 0.48),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
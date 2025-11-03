import 'package:flutter/material.dart';
import 'dart:ui';

// Widget nút action cho màn hình preview media
// Có 2 loại: primary (màu cam) cho nút chính và secondary (trong suốt) cho nút phụ
class PreviewButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const PreviewButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          // Blur effect cho glassmorphism
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              // Nút primary dùng màu cam, secondary dùng nền trong suốt
              color: isPrimary
                  ? Colors.deepOrange
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                // Viền cam cho primary, viền trắng cho secondary
                color: isPrimary
                    ? Colors.deepOrange.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon bên trái
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                // Label text
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
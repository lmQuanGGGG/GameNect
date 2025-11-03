import 'package:flutter/material.dart';
import 'dart:ui';

// Widget hiển thị indicator khi đang quay video
// Hiển thị chấm đỏ nhấp nháy và thời gian đã quay
class RecordingIndicator extends StatelessWidget {
  final int seconds;

  const RecordingIndicator({
    super.key,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        // Blur background để tạo glassmorphism effect
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            // Nền đỏ trong suốt để biết đang quay
            color: Colors.red.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chấm tròn trắng đại diện cho recording
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              // Hiển thị thời gian đã quay / tổng thời gian tối đa (15s)
              Text(
                '${seconds}s / 15s',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'dart:ui';

class ZoomPresetButton extends StatelessWidget {
  final String label;
  final double zoom;
  final double currentZoom;
  final Function(double) onZoomChanged;

  const ZoomPresetButton({
    super.key,
    required this.label,
    required this.zoom,
    required this.currentZoom,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = (currentZoom - zoom).abs() < 0.3;
    
    return GestureDetector(
      onTap: () => onZoomChanged(zoom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: isActive ? 0.4 : 0.2),
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
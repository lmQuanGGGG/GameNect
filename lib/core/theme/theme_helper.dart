import 'package:flutter/material.dart';

extension ThemeHelper on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // Scaffold Background
  Color get scaffoldBackgroundColor => isDarkMode ? const Color(0xFF101012) : const Color(0xFFF5F5F7);

  // Text Colors
  Color get textColor => isDarkMode ? Colors.white : const Color(0xFF1C1C1E);
  Color get textSecondaryColor => isDarkMode ? Colors.white70 : const Color(0xFF3A3A3C);
  Color get textTertiaryColor => isDarkMode ? Colors.white54 : const Color(0xFF8E8E93);

  // Card & Panel Container Colors
  Color get cardBgColor => isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white;
  Color get cardBorderColor => isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

  // App Bar Colors
  Color get appBarBgColor => isDarkMode ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.3);

  // Dialog / Popup Colors
  Color get dialogBgColor => isDarkMode ? const Color(0xFF1E1E22) : Colors.white;
  Color get textDialogColor => isDarkMode ? Colors.white : Colors.black87;
  Color get textDialogSecondaryColor => isDarkMode ? Colors.white70 : Colors.black54;

  // Orbs opacity multiplier
  double get bgOrbOpacityMultiplier => isDarkMode ? 1.0 : 0.6;
}

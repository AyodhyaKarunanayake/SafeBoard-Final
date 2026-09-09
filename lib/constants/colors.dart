import 'package:flutter/material.dart';

class AppColors {
  // Primary Theme Colors
  static const Color primaryNavy = Color(0xFF1B2859);
  static const Color emergencyRed = Color(0xFFB71C1C);
  static const Color backgroundLight = Color(0xFFF8F9FE);
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Priority Zone (Pink)
  static const Color priorityBg = Color(0xFFFBEAF0);
  static const Color priorityText = Color(0xFF72243E);
  static const Color priorityAccent = Color(0xFFC2185B);

  // General Zone (Blue)
  static const Color generalBg = Color(0xFFE6F1FB);
  static const Color generalText = Color(0xFF0C447C);
  static const Color generalAccent = Color(0xFF1565C0);

  // Standing Limit Zone (Amber)
  static const Color standingBg = Color(0xFFFAEEDA);
  static const Color standingText = Color(0xFF633806);
  static const Color standingAccent = Color(0xFFEF9F27);

  // Helper method for Zone colors
  static Color getZoneBg(String zone) {
    switch (zone.toLowerCase()) {
      case 'priority':
      case 'p':
        return priorityBg;
      case 'general':
      case 'g':
        return generalBg;
      case 'standing':
      case 's':
        return standingBg;
      default:
        return generalBg;
    }
  }

  static Color getZoneText(String zone) {
    switch (zone.toLowerCase()) {
      case 'priority':
      case 'p':
        return priorityText;
      case 'general':
      case 'g':
        return generalText;
      case 'standing':
      case 's':
        return standingText;
      default:
        return generalText;
    }
  }

  static Color getZoneAccent(String zone) {
    switch (zone.toLowerCase()) {
      case 'priority':
      case 'p':
        return priorityAccent;
      case 'general':
      case 'g':
        return generalAccent;
      case 'standing':
      case 's':
        return standingAccent;
      default:
        return generalAccent;
    }
  }
}

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

  // Limited Zone (Amber) - rows 7-13, still a real booked seat, just
  // further back. Shares the amber family with Standing below (same "back
  // of the bus" area on the seat diagram).
  static const Color limitedBg = Color(0xFFFAEEDA);
  static const Color limitedText = Color(0xFF633806);
  static const Color limitedAccent = Color(0xFFEF9F27);

  // Standing (Amber) - no seat, a headcount-only spot in the aisle. Used
  // for the "Standing Area" zone label/pill elsewhere in the app.
  static const Color standingBg = Color(0xFFFAEEDA);
  static const Color standingText = Color(0xFF633806);
  static const Color standingAccent = Color(0xFFEF9F27);

  // The standing *icon* itself (in the seat diagram) uses its own distinct
  // color, separate from the amber Limited/Standing zone color, so a
  // passenger can tell "this dot is a person standing" from "this card is
  // a seat" at a glance.
  static const Color standingIconBg = Color(0xFFE1F3EF);
  static const Color standingIconAccent = Color(0xFF0D9488);

  // Helper method for Zone colors
  static Color getZoneBg(String zone) {
    switch (zone.toLowerCase()) {
      case 'priority':
      case 'p':
        return priorityBg;
      case 'general':
      case 'g':
        return generalBg;
      case 'limited':
      case 'l':
        return limitedBg;
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
      case 'limited':
      case 'l':
        return limitedText;
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
      case 'limited':
      case 'l':
        return limitedAccent;
      case 'standing':
      case 's':
        return standingAccent;
      default:
        return generalAccent;
    }
  }
}

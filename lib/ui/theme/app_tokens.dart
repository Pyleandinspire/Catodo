import 'package:flutter/widgets.dart';

class AppTokens {
  AppTokens._();
  static const double sp4 = 4, sp6 = 6, sp8 = 8, sp12 = 12, sp16 = 16, sp20 = 20, sp24 = 24, sp32 = 32, sp40 = 40, sp48 = 48;
  static const double rSm = 8, rMd = 12, rLg = 14, rXl = 20, rPill = 999;
  static const double bw1 = 1, bw2 = 2;
  static const double eFlat = 0, eLow = 1, eMid = 2, eHigh = 4;
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animMid = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 500);
}

class AppSemanticColors {
  AppSemanticColors._();
  static const priorityHigh = Color(0xFFEF4444);
  static const priorityMid = Color(0xFFF59E0B);
  static const priorityLow = Color(0xFF60A5FA);
  static const priorityNone = Color(0xFF94A3B8);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const overdue = Color(0xFFDC2626);

  static Color forPriority(int p) {
    switch (p) { case 3: return priorityHigh; case 2: return priorityMid; case 1: return priorityLow; default: return priorityNone; }
  }
  static String labelForPriority(int p) {
    switch (p) { case 3: return '高'; case 2: return '中'; case 1: return '低'; default: return '无'; }
  }
}

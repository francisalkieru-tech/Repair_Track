import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF1E88E5);
  static const Color accent = Color(0xFF00ACC1);

  static const Color pending = Color(0xFFFFA726);
  static const Color accepted = Color(0xFF42A5F5);
  static const Color inProcess = Color(0xFF7E57C2);
  static const Color waitingParts = Color(0xFFEF5350);
  static const Color completed = Color(0xFF66BB6A);

  static const Color background = Color(0xFFF5F5F5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF212121);
  static const Color textGray = Color(0xFF757575);
  static const Color textLightGray = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE0E0E0);

  static const Color dark = Color(0xFF111827);
  static const Color darkGradient2 = Color(0xFF1F2937);
  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkGradient2, dark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF16A34A);

  static const double fontTitle = 24;
  static const double fontSubtitle = 15;
  static const double fontBody = 16;
  static const double fontLabel = 14;
  static const double fontCaption = 12;
}

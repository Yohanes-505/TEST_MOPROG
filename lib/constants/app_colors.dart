import 'package:flutter/material.dart';

/// Central color palette for Meetcha.
class AppColors {
  AppColors._();

  // Core palette
  static const Color tan = Color(0xFF9E7C5F);
  static const Color brown = Color(0xFF6F5840);

  static const Color matcha = Color(0xFF658C5E);
  static const Color matchaDeep = Color(0xFF4F6B48);
  static const Color sage = Color(0xFF91A287);
  static const Color matchaSoft = Color(0xFFDDE6D5);

  static const Color cream = Color(0xFFFFF0D6);

  // Main text
  static const Color ink = Color(0xFF293329);

  // Legacy aliases
  // Tetap dipertahankan karena beberapa screen lama masih memakainya.
  static const Color lime = matcha;
  static const Color green = sage;
  static const Color sageLight = sage;
  static const Color mist = Color(0xFFD8DED3);

  // Brand / primary
  static const Color primary = matcha;
  static const Color onPrimary = Colors.white;

  static const Color primaryDeep = matchaDeep;
  static const Color primarySoft = matchaSoft;
  static const Color primaryBorder = Color(0xFFC6D5BD);

  // Backgrounds
  static const Color background = Color(0xFFFFFBF3);
  static const Color surfaceMuted = Color(0xFFF3F5EF);

  // Text
  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF687065);

  // Borders
  static const Color border = Color(0xFFD8DED3);
  static const Color borderSoft = Color(0xFFEAEFE7);

  // Semantic
  static const Color success = matchaDeep;
  static const Color successSoft = matchaSoft;

  static const Color warning = Color(0xFFB7791F);
  static const Color warningSoft = Color(0xFFFFF4E0);
  static const Color warningBorder = Color(0xFFF5D9A8);

  static const Color error = Color(0xFFC62828);
  static const Color errorSoft = Color(0xFFFDECEC);
}
import 'package:flutter/material.dart';

/// Palet Meetcha. Lima warna inti dari palet desain:
/// tan 9E7C5F, brown 6F5840, sage 658C5E, sage light 91A287, cream FFF0D6.
/// Warna lain (ink, soft, border) adalah turunan dari kelimanya
/// supaya kontras teks tetap terbaca.
class AppColors {
  AppColors._();

  // Warna inti (palet desain)
  static const Color tan = Color(0xFF9E7C5F);
  static const Color brown = Color(0xFF6F5840);
  static const Color sage = Color(0xFF658C5E);
  static const Color sageLight = Color(0xFF91A287);
  static const Color cream = Color(0xFFFFF0D6);

  // Alias nama lama supaya file yang belum diperbarui tetap bisa dikompilasi.
  static const Color lime = sageLight;
  static const Color green = sage;

  /// Cokelat tua turunan `brown` — latar gelap (welcome) dan teks utama.
  static const Color espresso = Color(0xFF3B2818);
  static const Color ink = espresso;

  /// Cokelat muda turunan `tan` — garis pemisah & border netral.
  static const Color mist = Color(0xFFDCCBB5);

  /// Latar tombol utama, chip terpilih, slider aktif.
  static const Color primary = sageLight;

  static const Color ink = Color(0xFF293329);

  /// Sage tua turunan `sage` — untuk ikon, teks, dan border di atas latar terang.
  static const Color primaryDeep = Color(0xFF517049);

  /// Latar lembut bernuansa sage.
  static const Color primarySoft = Color(0xFFEAF0E5);

  /// Border tipis bernuansa sage.
  static const Color primaryBorder = Color(0xFFCBD7C3);

  /// Latar halaman: cream yang dilembutkan. `cream` murni dipakai untuk
  /// permukaan yang perlu menonjol (chip, kartu, area muted).
  static const Color background = Color(0xFFFFF9EE);
  static const Color surfaceMuted = cream;

  // Text
  static const Color textPrimary = ink;
  static const Color textSecondary = brown;

  /// Garis pemisah & border netral (hangat).
  static const Color border = mist;
  static const Color borderSoft = Color(0xFFF0E4D2);

  // Semantic
  static const Color success = matchaDeep;
  static const Color successSoft = matchaSoft;

  static const Color warning = Color(0xFFB7791F);
  static const Color warningSoft = Color(0xFFFFF4E0);
  static const Color warningBorder = Color(0xFFF5D9A8);

  static const Color error = Color(0xFFC62828);
  static const Color errorSoft = Color(0xFFFDECEC);
}
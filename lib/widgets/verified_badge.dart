import 'package:Meetcha/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// centang kecil di samping nama untuk user yang sudah verifikasi wajah
class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Wajah terverifikasi',
      child: Icon(
        Icons.verified_rounded,
        size: size,
        color: AppColors.matcha,
      ),
    );
  }
}
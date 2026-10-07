import 'package:Meetcha/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Avatar bulat dengan fallback ikon kalau user belum punya foto valid.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;

  const UserAvatar({super.key, required this.photoUrl, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;

    if (url == null || !url.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceMuted,
        child: Icon(Icons.person, size: radius, color: AppColors.textSecondary),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceMuted,
      backgroundImage: NetworkImage(url),
      // Kalau gambar gagal dimuat, biarkan latar polos (tanpa crash).
      onBackgroundImageError: (exception, stackTrace) {},
    );
  }
}

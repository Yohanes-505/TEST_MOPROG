import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/controllers/profile_controller.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/screens/chat_screen.dart';
import 'package:bumble/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Ini buat pop-up "It's a match"
/// Selesai pas user close atau lanjut ke chat.
Future<void> showMatchDialog(ProfileModel other) async {
  await Get.dialog<void>(_MatchDialog(other: other));
}

class _MatchDialog extends StatelessWidget {
  final ProfileModel other;

  const _MatchDialog({required this.other});

  @override
  Widget build(BuildContext context) {
    final myPhoto = ProfileController.to.me?.photoUrl;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "It's a Match!",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDeep,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Kamu dan ${other.name} saling menyukai.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ringedAvatar(myPhoto),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.favorite,
                      color: AppColors.primaryDeep, size: 28),
                ),
                _ringedAvatar(other.photoUrl),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Get.back<void>();
                  Get.to(() => ChatScreen(matchProfile: other));
                },
                child: const Text(
                  'Kirim Pesan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Get.back<void>(),
              child: const Text(
                'Nanti saja',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ringedAvatar(String? photoUrl) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
      ),
      child: UserAvatar(photoUrl: photoUrl, radius: 40),
    );
  }
}

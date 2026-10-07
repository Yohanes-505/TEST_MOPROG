import 'package:bumble/authentication/login_screen.dart';
import 'package:bumble/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Layar pembuka Meetcha — latar cream (FFF0D6) dengan simbol logo cokelat
/// dan wordmark "MEETCHA" beserta tagline, semuanya berupa gambar.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),

              // Simbol: dua kartu profil dengan orbit
              Image.asset(
                "images/logo_mark.png",
                width: 230,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 28),

              // Wordmark + tagline "Real people. Better connections."
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Image.asset(
                  "images/logo_wordmark.png",
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),

                  const Spacer(flex: 2),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Get.to(() => const LoginScreen()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brown,
                    foregroundColor: AppColors.cream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Thoughtful matches. Real conversations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
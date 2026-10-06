import 'package:bumble/authentication/login_screen.dart';
import 'package:bumble/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo
                  Container(
                    width: 132,
                    height: 132,
                    decoration: const BoxDecoration(
                      color: AppColors.matchaSoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        AppColors.matchaDeep,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'images/logo.png',
                        width: 88,
                        height: 88,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 34),

                  // Small brand cue
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.matchaSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'MEETCHA',
                      style: TextStyle(
                        color: AppColors.matchaDeep,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'A better match\nis brewing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'Discover thoughtful connections, one match at a time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Get.to(() => const LoginScreen()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
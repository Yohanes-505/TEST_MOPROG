import 'dart:async';

import 'package:bumble/services/supabase_service.dart';
import 'package:bumble/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bumble/profile/profile_setup_screen.dart';
import 'package:bumble/controllers/profile_controller.dart';
import 'package:bumble/services/notification_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool isPasswordHidden = true;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> handleSignUp() async {
    if (isLoading) return;
    FocusScope.of(context).unfocus();

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      Get.snackbar('Error', 'Please fill in all fields', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      Get.snackbar('Error', 'Please enter a valid email address', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (password.length < 6) {
      Get.snackbar('Error', 'Password must be at least 6 characters', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (password != confirmPassword) {
      Get.snackbar('Error', 'Passwords do not match', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Nama, email, dan passwordnya disimpan ke metadata biar informasinya tidak hilang walau belum konfirmasi e-mailnya
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      final user = response.user;
      if (user == null) {
        Get.snackbar('Error', 'Sign up failed. Please try again.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      
      if (user.identities != null && user.identities!.isEmpty) {
        Get.snackbar('Error', 'This email is already registered. Please log in instead.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      if (response.session == null) {
        Get.snackbar(
          'Verify your email',
          'We sent a confirmation link to your email. Please verify your email before logging in.',
          snackPosition: SnackPosition.BOTTOM,
        );
        Get.back(); // ini buat balik ke Login Screen
        return;
      }

      try {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'name': name,
        });
      } catch (e) {
        debugPrint('SIGNUP PROFILE UPSERT ERROR: $e');
      }

      unawaited(saveCurrentFcmToken());

      await ProfileController.to.loadProfile();

      Get.snackbar('Success', 'Account created successfully!', snackPosition: SnackPosition.BOTTOM);
      Get.offAll(() => const ProfileSetupScreen());
    } on AuthException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      debugPrint('SIGNUP ERROR: $e');
      Get.snackbar('Error', 'Something went wrong. Please try again.', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  InputDecoration _inputDecoration({
  required String hintText,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: AppColors.textSecondary,
    ),
    prefixIcon: Icon(
      icon,
      color: AppColors.textSecondary,
    ),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.surfaceMuted,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 17,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: AppColors.border,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: AppColors.border,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: AppColors.primary,
        width: 1.5,
      ),
    ),
  );
}

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.matchaSoft,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.matchaDeep,
                      size: 22,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'Create your account',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Start with the basics. Your profile comes next.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 30),

                // Name
                const Text(
                  'Name',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 9),

                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hintText: 'Enter your name',
                    icon: Icons.person_outline_rounded,
                  ),
                ),

                const SizedBox(height: 20),

                // Email
                const Text(
                  'Email',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 9),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hintText: 'Enter your email',
                    icon: Icons.mail_outline_rounded,
                  ),
                ),

                const SizedBox(height: 20),

                // Password
                const Text(
                  'Password',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 9),

                TextField(
                  controller: passwordController,
                  obscureText: isPasswordHidden,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hintText: 'Create a password',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordHidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(
                          () => isPasswordHidden = !isPasswordHidden,
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Use at least 6 characters.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 20),

                // Confirm Password
                const Text(
                  'Confirm password',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 9),

                TextField(
                  controller: confirmPasswordController,
                  obscureText: isPasswordHidden,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!isLoading) {
                      handleSignUp();
                    }
                  },
                  decoration: _inputDecoration(
                    hintText: 'Re-enter your password',
                    icon: Icons.lock_outline_rounded,
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor: AppColors.sage,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.onPrimary,
                              strokeWidth: 2.4,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: AppColors.matchaDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}}
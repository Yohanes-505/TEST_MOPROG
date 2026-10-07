import 'dart:async';

import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/controllers/profile_controller.dart';
import 'package:bumble/profile/profile_setup_screen.dart';
import 'package:bumble/services/notification_service.dart';
import 'package:bumble/services/supabase_service.dart';
import 'package:bumble/services/session_timeout_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isPasswordHidden = true;
  bool isConfirmPasswordHidden = true;
  bool isLoading = false;

  late final AnimationController _introController;

  static final RegExp _emailRegex =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> handleSignUp() async {
    if (isLoading) return;

    FocusScope.of(context).unfocus();

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      Get.snackbar(
        'Error',
        'Please fill in all fields',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      Get.snackbar(
        'Error',
        'Please enter a valid email address',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (password.length < 6) {
      Get.snackbar(
        'Error',
        'Password must be at least 6 characters',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (password != confirmPassword) {
      Get.snackbar(
        'Error',
        'Passwords do not match',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Nama disimpan ke metadata agar tetap tersedia
      // meskipun pengguna masih harus verifikasi email.
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
        },
      );

      final user = response.user;

      if (user == null) {
        Get.snackbar(
          'Error',
          'Sign up failed. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Supabase dapat mengembalikan user dengan identities kosong
      // ketika email sebelumnya sudah pernah terdaftar.
      if (user.identities != null && user.identities!.isEmpty) {
        Get.snackbar(
          'Error',
          'This email is already registered. Please log in instead.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Jika email confirmation aktif, session belum tersedia.
      if (response.session == null) {
        Get.snackbar(
          'Verify your email',
          'We sent a confirmation link to your email. '
              'Please verify your email before logging in.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );

        Get.back();
        return;
      }

      await SessionTimeoutService.touch();

      // Simpan data awal profil.
      try {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'name': name,
        });
      } catch (e) {
        debugPrint('SIGNUP PROFILE UPSERT ERROR: $e');
      }

      // FCM hanya dijalankan di mobile.
      // Chrome digunakan untuk development UI.
      if (!kIsWeb) {
        unawaited(saveCurrentFcmToken());
      }

      await ProfileController.to.loadProfile();

      if (!mounted) return;

      Get.snackbar(
        'Success',
        'Account created successfully!',
        snackPosition: SnackPosition.BOTTOM,
      );

      Get.offAll(
        () => const ProfileSetupScreen(),
      );
    } on AuthException catch (e) {
      Get.snackbar(
        'Error',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('SIGNUP ERROR: $e');

      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _reveal({
    required Widget child,
    required double start,
    required double end,
    Offset begin = const Offset(0, 0.05),
  }) {
    final animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(
        start,
        end,
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
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
      fillColor: Colors.white.withValues(alpha: 0.58),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppColors.matcha,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _visibilityIcon({
    required bool hidden,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      splashRadius: 20,
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: animation,
              child: child,
            ),
          );
        },
        child: Icon(
          hidden
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          key: ValueKey(hidden),
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          // Background decoration - top left
          Positioned(
            top: -90,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(
                  alpha: 0.15,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Background decoration - bottom right
          Positioned(
            bottom: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: AppColors.matchaSoft.withValues(
                  alpha: 0.48,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    20,
                    24,
                    32,
                  ),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // =========================
                        // BACK BUTTON
                        // =========================
                        _reveal(
                          start: 0.00,
                          end: 0.22,
                          child: _PressScale(
                            onTap: () => Get.back(),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.matchaSoft,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brown.withValues(
                                      alpha: 0.06,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.matchaDeep,
                                size: 22,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // =========================
                        // HEADER
                        // =========================
                        _reveal(
                          start: 0.06,
                          end: 0.32,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create your account',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 30,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.7,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Start with the basics. '
                                'Your profile comes next.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // =========================
                        // NAME
                        // =========================
                        _reveal(
                          start: 0.14,
                          end: 0.40,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Name'),

                              const SizedBox(height: 9),

                              TextField(
                                controller: nameController,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                textCapitalization:
                                    TextCapitalization.words,
                                autofillHints: const [
                                  AutofillHints.name,
                                ],
                                decoration: _inputDecoration(
                                  hintText: 'Enter your name',
                                  icon:
                                      Icons.person_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // =========================
                        // EMAIL
                        // =========================
                        _reveal(
                          start: 0.22,
                          end: 0.48,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Email'),

                              const SizedBox(height: 9),

                              TextField(
                                controller: emailController,
                                keyboardType:
                                    TextInputType.emailAddress,
                                textInputAction:
                                    TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.email,
                                ],
                                decoration: _inputDecoration(
                                  hintText: 'Enter your email',
                                  icon:
                                      Icons.mail_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // =========================
                        // PASSWORD
                        // =========================
                        _reveal(
                          start: 0.30,
                          end: 0.56,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Password'),

                              const SizedBox(height: 9),

                              TextField(
                                controller: passwordController,
                                obscureText: isPasswordHidden,
                                textInputAction:
                                    TextInputAction.next,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                decoration: _inputDecoration(
                                  hintText: 'Create a password',
                                  icon:
                                      Icons.lock_outline_rounded,
                                  suffixIcon: _visibilityIcon(
                                    hidden:
                                        isPasswordHidden,
                                    onPressed: () {
                                      setState(() {
                                        isPasswordHidden =
                                            !isPasswordHidden;
                                      });
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Padding(
                                padding: EdgeInsets.only(left: 2),
                                child: Text(
                                  'Use at least 6 characters.',
                                  style: TextStyle(
                                    color:
                                        AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // =========================
                        // CONFIRM PASSWORD
                        // =========================
                        _reveal(
                          start: 0.38,
                          end: 0.64,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Confirm password'),

                              const SizedBox(height: 9),

                              TextField(
                                controller:
                                    confirmPasswordController,
                                obscureText:
                                    isConfirmPasswordHidden,
                                textInputAction:
                                    TextInputAction.done,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                onSubmitted: (_) {
                                  if (!isLoading) {
                                    handleSignUp();
                                  }
                                },
                                decoration: _inputDecoration(
                                  hintText:
                                      'Re-enter your password',
                                  icon:
                                      Icons.lock_outline_rounded,
                                  suffixIcon: _visibilityIcon(
                                    hidden:
                                        isConfirmPasswordHidden,
                                    onPressed: () {
                                      setState(() {
                                        isConfirmPasswordHidden =
                                            !isConfirmPasswordHidden;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // =========================
                        // CREATE ACCOUNT BUTTON
                        // =========================
                        _reveal(
                          start: 0.48,
                          end: 0.76,
                          child: _PressScale(
                            onTap:
                                isLoading ? null : handleSignUp,
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              width: double.infinity,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isLoading
                                    ? AppColors.primary.withValues(
                                        alpha: 0.58,
                                      )
                                    : AppColors.primary,
                                borderRadius:
                                    BorderRadius.circular(20),
                                boxShadow: isLoading
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: AppColors
                                              .matchaDeep
                                              .withValues(
                                            alpha: 0.16,
                                          ),
                                          blurRadius: 20,
                                          offset:
                                              const Offset(0, 7),
                                        ),
                                      ],
                              ),
                              child: AnimatedSwitcher(
                                duration:
                                    const Duration(milliseconds: 220),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder:
                                    (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: isLoading
                                    ? const SizedBox(
                                        key:
                                            ValueKey('loading'),
                                        width: 22,
                                        height: 22,
                                        child:
                                            CircularProgressIndicator(
                                          color:
                                              AppColors.onPrimary,
                                          strokeWidth: 2.3,
                                        ),
                                      )
                                    : const Text(
                                        'Create Account',
                                        key: ValueKey(
                                          'create-account',
                                        ),
                                        style: TextStyle(
                                          color:
                                              AppColors.onPrimary,
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // =========================
                        // LOGIN LINK
                        // =========================
                        _reveal(
                          start: 0.58,
                          end: 0.86,
                          child: Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment:
                                  WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account?',
                                  style: TextStyle(
                                    color:
                                        AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Get.back(),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                      color:
                                          AppColors.matchaDeep,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// IOS-LIKE PRESS FEEDBACK
// ============================================================

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressScale({
    required this.child,
    this.onTap,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) {
                _setPressed(true);
              },
        onTapCancel: widget.onTap == null
            ? null
            : () {
                _setPressed(false);
              },
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                _setPressed(false);
                widget.onTap?.call();
              },
        child: widget.child,
      ),
    );
  }
}
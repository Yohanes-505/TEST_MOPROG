import 'dart:async';

import 'package:Meetcha/authentication/forgot_password_screen.dart';
import 'package:Meetcha/authentication/signup_screen.dart';
import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/home/main_shell.dart';
import 'package:Meetcha/profile/profile_setup_screen.dart';
import 'package:Meetcha/services/notification_service.dart';
import 'package:Meetcha/services/profile_service.dart';
import 'package:Meetcha/services/supabase_service.dart';
import 'package:Meetcha/services/session_timeout_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordHidden = true;
  bool isLoading = false;

  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter both email and password',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (response.user != null) {
        await SessionTimeoutService.touch();

        // FCM token hanya disimpan dari mobile.
        if (!kIsWeb) {
          unawaited(saveCurrentFcmToken());
        }

        final complete = await isProfileComplete(response.user!.id);

        if (!mounted) return;

        Get.offAll(
          () => complete
              ? const MainShell()
              : const ProfileSetupScreen(),
        );
      } else {
        Get.snackbar(
          'Error',
          'Login failed',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } on AuthException catch (e) {
      Get.snackbar(
        'Error',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');

      Get.snackbar(
        'Error',
        'An unexpected error occurred',
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
    Offset begin = const Offset(0, 0.06),
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
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
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
                color: AppColors.sage.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Background decoration - bottom right
          Positioned(
            bottom: -100,
            right: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.matchaSoft.withValues(alpha: 0.48),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // =========================
                      // BACK BUTTON
                      // =========================
                      _reveal(
                        start: 0.00,
                        end: 0.28,
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

                      const SizedBox(height: 34),

                      // =========================
                      // HEADER
                      // =========================
                      _reveal(
                        start: 0.08,
                        end: 0.40,
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back',
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
                              'Sign in and pick up where you left off.',
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

                      const SizedBox(height: 32),

                      // =========================
                      // EMAIL
                      // =========================
                      _reveal(
                        start: 0.18,
                        end: 0.52,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                              autofillHints: const [
                                AutofillHints.email,
                              ],
                              decoration: _inputDecoration(
                                hint: 'Enter your email',
                                icon: Icons.mail_outline_rounded,
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
                        start: 0.28,
                        end: 0.62,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                              textInputAction: TextInputAction.done,
                              enableSuggestions: false,
                              autocorrect: false,
                              autofillHints: const [
                                AutofillHints.password,
                              ],
                              onSubmitted: (_) {
                                if (!isLoading) {
                                  handleLogin();
                                }
                              },
                              decoration: _inputDecoration(
                                hint: 'Enter your password',
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  splashRadius: 20,
                                  onPressed: () {
                                    setState(
                                      () => isPasswordHidden =
                                          !isPasswordHidden,
                                    );
                                  },
                                  icon: AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    transitionBuilder: (
                                      child,
                                      animation,
                                    ) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      isPasswordHidden
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      key: ValueKey(isPasswordHidden),
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Get.to(
                                    () => const ForgotPasswordScreen(),
                                    transition: Transition.cupertino,
                                    duration: const Duration(
                                      milliseconds: 300,
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: AppColors.matchaDeep,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =========================
                      // LOGIN BUTTON
                      // =========================
                      _reveal(
                        start: 0.42,
                        end: 0.78,
                        child: _PressScale(
                          onTap: isLoading ? null : handleLogin,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: double.infinity,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isLoading
                                  ? AppColors.brown.withValues(alpha: 0.55)
                                  : AppColors.brown,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isLoading
                                  ? []
                                  : [
                                      BoxShadow(
                                        color:
                                            AppColors.brown.withValues(
                                          alpha: 0.14,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (
                                child,
                                animation,
                              ) {
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
                                      key: ValueKey('loading'),
                                      width: 22,
                                      height: 22,
                                      child:
                                          CircularProgressIndicator(
                                        color: AppColors.cream,
                                        strokeWidth: 2.3,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      key: ValueKey('login'),
                                      style: TextStyle(
                                        color: AppColors.cream,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // =========================
                      // SIGN UP
                      // =========================
                      _reveal(
                        start: 0.56,
                        end: 0.90,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account?",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Get.to(
                                  () => const SignUpScreen(),
                                  transition: Transition.cupertino,
                                  duration: const Duration(
                                    milliseconds: 300,
                                  ),
                                );
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: AppColors.matchaDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
      scale: _pressed ? 0.975 : 1,
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
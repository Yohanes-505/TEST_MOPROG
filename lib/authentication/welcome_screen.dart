import 'dart:math' as math;

import 'package:bumble/authentication/login_screen.dart';
import 'package:bumble/authentication/signup_screen.dart';
import 'package:bumble/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    // Very subtle floating animation for hero objects
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _introController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Widget _reveal({
    required Widget child,
    required double start,
    required double end,
    Offset begin = const Offset(0, 0.08),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          // Background base
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.cream,
                    Color(0xFFFFF7E7),
                    AppColors.cream,
                  ],
                ),
              ),
            ),
          ),

          // Soft organic decoration - top left
          Positioned(
            top: -105,
            left: -95,
            child: Container(
              width: 245,
              height: 245,
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Soft decoration - right
          Positioned(
            top: 125,
            right: -150,
            child: Container(
              width: 345,
              height: 345,
              decoration: BoxDecoration(
                color: AppColors.matchaSoft.withValues(alpha: 0.62),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Warm glow behind hero
          Positioned(
            left: -90,
            right: -90,
            top: 370,
            child: Container(
              height: 310,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.tan.withValues(alpha: 0.10),
                    AppColors.cream.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                  child: Column(
                    children: [
                      // =========================
                      // BRAND
                      // =========================

                      _reveal(
                        start: 0.0,
                        end: 0.35,
                        child: Column(
                          children: [
                            Image.asset(
                              'images/logo_mark.png',
                              width: 68,
                              height: 68,
                              fit: BoxFit.contain,
                            ),

                            const SizedBox(height: 2),

                            const Text(
                              'MEETCHA',
                              style: TextStyle(
                                color: AppColors.brown,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =========================
                      // HEADLINE
                      // =========================

                      _reveal(
                        start: 0.12,
                        end: 0.50,
                        child: const Text(
                          'Date for\nsomething real',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.brown,
                            fontSize: 39,
                            height: 1.01,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // =========================
                      // RIBBON
                      // =========================

                      _reveal(
                        start: 0.25,
                        end: 0.62,
                        child: Transform.rotate(
                          angle: -0.025,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.matcha,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brown.withValues(
                                    alpha: 0.10,
                                  ),
                                  blurRadius: 22,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Text(
                              'for serious daters',
                              style: TextStyle(
                                color: AppColors.cream,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // =========================
                      // HERO SCENE
                      // =========================

                      Expanded(
                        child: _reveal(
                          start: 0.35,
                          end: 0.78,
                          begin: const Offset(0, 0.12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return AnimatedBuilder(
                                animation: _floatController,
                                builder: (context, child) {
                                  final wave = math.sin(
                                    _floatController.value * math.pi * 2,
                                  );

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Large soft surface / table
                                      Positioned(
                                        left: -55,
                                        right: -55,
                                        bottom: 4,
                                        child: Transform.rotate(
                                          angle: 0.045,
                                          child: Container(
                                            height: 115,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0.46,
                                                  ),
                                                  AppColors.sage.withValues(
                                                    alpha: 0.18,
                                                  ),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(80),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Croissant plate
                                      Positioned(
                                        left: -6,
                                        bottom: 74,
                                        child: Transform.rotate(
                                          angle: -0.13,
                                          child: Container(
                                            width: 188,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.60,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.brown
                                                      .withValues(alpha: 0.10),
                                                  blurRadius: 18,
                                                  offset:
                                                      const Offset(0, 10),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Croissant
                                      Positioned(
                                        left: -2,
                                        bottom: 77 + (wave * 2),
                                        child: Transform.rotate(
                                          angle: -0.10,
                                          child: Image.asset(
                                            'images/croissant.png',
                                            width: 182,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),

                                      // Cup floor shadow
                                      Positioned(
                                        right: 2,
                                        bottom: 39,
                                        child: Transform.scale(
                                          scaleX: 1.2,
                                          child: Container(
                                            width: 175,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: AppColors.brown.withValues(
                                                alpha: 0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Matcha cup
                                      Positioned(
                                        right: -6,
                                        bottom: 47 - (wave * 4),
                                        child: Transform.rotate(
                                          angle: 0.02,
                                          child: Image.asset(
                                            'images/matcha_hero.png',
                                            width: 238,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),

                                      // Steam
                                      Positioned(
                                        right: 54,
                                        bottom: 204 - (wave * 4),
                                        child: SizedBox(
                                          width: 100,
                                          height: 90,
                                          child: CustomPaint(
                                            painter: _SteamPainter(),
                                          ),
                                        ),
                                      ),

                                      // Floating leaf 1
                                      Positioned(
                                        left: 165,
                                        top: 40 + (wave * 5),
                                        child: Transform.rotate(
                                          angle: -0.6,
                                          child: Container(
                                            width: 38,
                                            height: 15,
                                            decoration: BoxDecoration(
                                              color: AppColors.matcha,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(30),
                                                bottomRight:
                                                    Radius.circular(30),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Sparkle
                                      Positioned(
                                        left: 15,
                                        top: 40,
                                        child: Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 23,
                                          color: AppColors.tan.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),

                                      // Heart doodle
                                      Positioned(
                                        right: 4,
                                        top: 26,
                                        child: Transform.rotate(
                                          angle: 0.16,
                                          child: const Icon(
                                            Icons.favorite_border_rounded,
                                            size: 31,
                                            color: AppColors.brown,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // =========================
                      // ACTIONS
                      // =========================

                      _reveal(
                        start: 0.60,
                        end: 0.90,
                        child: _PressButton(
                          label: "I'm new here",
                          filled: true,
                          onTap: () {
                            Get.to(
                              () => const SignUpScreen(),
                              transition: Transition.cupertino,
                              duration: const Duration(milliseconds: 320),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      _reveal(
                        start: 0.67,
                        end: 0.95,
                        child: _PressButton(
                          label: "I've been here before",
                          filled: false,
                          onTap: () {
                            Get.to(
                              () => const LoginScreen(),
                              transition: Transition.cupertino,
                              duration: const Duration(milliseconds: 320),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      // =========================
                      // LEGAL
                      // =========================

                      _reveal(
                        start: 0.74,
                        end: 1.0,
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: 'By continuing you agree to our\n',
                              ),
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: AppColors.brown,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: AppColors.brown,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
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
// PRESSABLE IOS-LIKE BUTTON
// ============================================================

class _PressButton extends StatefulWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _PressButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
        },
        onTapCancel: () {
          setState(() => _pressed = false);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled
                ? AppColors.brown
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: widget.filled
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brown.withValues(
                  alpha: widget.filled ? 0.13 : 0.06,
                ),
                blurRadius: widget.filled ? 20 : 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.filled
                  ? AppColors.cream
                  : AppColors.brown,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LIGHT STEAM
// ============================================================

class _SteamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final first = Path()
      ..moveTo(size.width * 0.32, size.height)
      ..cubicTo(
        size.width * 0.10,
        size.height * 0.70,
        size.width * 0.55,
        size.height * 0.48,
        size.width * 0.30,
        0,
      );

    final second = Path()
      ..moveTo(size.width * 0.64, size.height)
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.72,
        size.width * 0.42,
        size.height * 0.45,
        size.width * 0.70,
        0,
      );

    canvas.drawPath(first, paint);
    canvas.drawPath(second, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
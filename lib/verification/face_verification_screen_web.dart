import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/home/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FaceVerificationScreen extends StatefulWidget {
  final bool fromOnboarding;

  const FaceVerificationScreen({
    super.key,
    this.fromOnboarding = false,
  });

  @override
  State<FaceVerificationScreen> createState() =>
      _FaceVerificationScreenState();
}

class _FaceVerificationScreenState
    extends State<FaceVerificationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  Widget _reveal({
    required Widget child,
    required double start,
    required double end,
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
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  void _continue() {
    if (widget.fromOnboarding) {
      Get.offAll(() => const MainShell());
    } else {
      Get.back(result: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
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

          Positioned(
            bottom: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    20,
                    24,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.fromOnboarding)
                        _reveal(
                          start: 0.0,
                          end: 0.30,
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
                        )
                      else
                        const SizedBox(height: 44),

                      const SizedBox(height: 28),

                      _reveal(
                        start: 0.08,
                        end: 0.42,
                        child: const Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verifikasi Wajah',
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
                              'Fitur verifikasi wajah tersedia '
                              'di aplikasi mobile Meetcha.',
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

                      Expanded(
                        child: Center(
                          child: _reveal(
                            start: 0.20,
                            end: 0.62,
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: 0.62,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brown.withValues(
                                      alpha: 0.06,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.face_retouching_natural_rounded,
                                  size: 94,
                                  color: AppColors.matchaDeep,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      _reveal(
                        start: 0.36,
                        end: 0.72,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.matchaSoft.withValues(
                              alpha: 0.55,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.primaryBorder,
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.phone_iphone_rounded,
                                color: AppColors.matchaDeep,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Buka Meetcha melalui Android atau iOS '
                                  'untuk mengambil selfie dan melakukan '
                                  'pencocokan wajah.',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      _reveal(
                        start: 0.48,
                        end: 0.88,
                        child: _PressScale(
                          onTap: _continue,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.brown,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brown.withValues(
                                    alpha: 0.14,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.fromOnboarding
                                  ? 'Continue to Meetcha'
                                  : 'Back to Profile',
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
            : (_) => _setPressed(true),
        onTapCancel: widget.onTap == null
            ? null
            : () => _setPressed(false),
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
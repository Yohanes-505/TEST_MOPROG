import 'dart:io';

import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/home/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'face_verification_service.dart';

/// [fromOnboarding] = true, dipakai setelah ProfileSetup: ada tombol "Skip for now" dan setelah selesai/skip menuju MainShell.
/// [fromOnboarding] = false, dipakai dari tab Profile: selesai => Get.back(result: true).
class FaceVerificationScreen extends StatefulWidget {
  final bool fromOnboarding;
  const FaceVerificationScreen({super.key, this.fromOnboarding = false});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  final _service = FaceVerificationService.instance;

  late final AnimationController _intro;

  File? _image;
  FaceCheckResult? _result;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _reveal({
    required Widget child,
    required double start,
    required double end,
  }) {
    final a = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(a),
        child: child,
      ),
    );
  }

  void _finish({required bool verified}) {
    if (widget.fromOnboarding) {
      Get.offAll(() => const MainShell());
    } else {
      Get.back(result: verified);
    }
  }

  Future<void> _takeSelfie() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
      maxWidth: 1080,
    );
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _result = null;
      _busy = true;
    });

    try {
      final res = await _service.analyze(_image!);
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = FaceCheckResult(
          passed: false, message: 'Could not process the photo: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_image == null || _result == null || !_result!.passed) return;
    setState(() => _busy = true);
    try {
      await _service.submit(_image!, _result!);
      if (!mounted) return;
      Get.snackbar('Verified', 'Your face has been verified.',
          snackPosition: SnackPosition.BOTTOM);
      _finish(verified: true);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', 'Could not submit verification: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color get _ringColor {
    if (_result == null) return AppColors.border;
    return _result!.passed ? AppColors.matcha : Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final passed = _result?.passed ?? false;

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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // back
                      SizedBox(
                        height: 44,
                        child: widget.fromOnboarding
                            ? null
                            : _reveal(
                                start: 0,
                                end: 0.25,
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
                                          color: AppColors.brown
                                              .withValues(alpha: 0.06),
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
                      ),
                      const SizedBox(height: 22),

                      _reveal(
                        start: 0.06,
                        end: 0.35,
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verify your face',
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
                              'Take a quick selfie so we can match it with your '
                              'profile photo. Verified profiles build more trust.',
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

                      // Foto placeholder
                      Expanded(
                        child: _reveal(
                          start: 0.2,
                          end: 0.6,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 230,
                              height: 230,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: _ringColor, width: 3),
                                color: Colors.white.withValues(alpha: 0.58),
                              ),
                              child: ClipOval(
                                child: _image == null
                                    ? const Icon(
                                        Icons.face_retouching_natural,
                                        size: 96,
                                        color: AppColors.textSecondary,
                                      )
                                    : Image.file(
                                        _image!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // status n tips
                      _reveal(
                        start: 0.4,
                        end: 0.75,
                        child: SizedBox(
                          width: double.infinity,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _busy
                                ? const Padding(
                                    key: ValueKey('busy'),
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: AppColors.matcha,
                                          strokeWidth: 2.4,
                                        ),
                                      ),
                                    ),
                                  )
                                : _result != null
                                    ? Padding(
                                        key: const ValueKey('result'),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              passed
                                                  ? Icons.check_circle_rounded
                                                  : Icons.error_outline_rounded,
                                              size: 20,
                                              color: passed
                                                  ? AppColors.matchaDeep
                                                  : Colors.redAccent,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                _result!.message,
                                                style: TextStyle(
                                                  color: passed
                                                      ? AppColors.matchaDeep
                                                      : Colors.redAccent,
                                                  fontSize: 14,
                                                  height: 1.4,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const Padding(
                                        key: ValueKey('tips'),
                                        padding:
                                            EdgeInsets.symmetric(vertical: 12),
                                        child: Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _TipChip('Face the camera'),
                                            _TipChip('Smile wide'),
                                            _TipChip('Good lighting'),
                                            _TipChip('Only you in frame'),
                                          ],
                                        ),
                                      ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // tombol ambil selfie
                      _reveal(
                        start: 0.5,
                        end: 0.85,
                        child: _PressScale(
                          onTap: _busy ? null : _takeSelfie,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.brown.withValues(alpha: 0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.camera_alt_rounded,
                                    color: AppColors.brown, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _image == null ? 'Take selfie' : 'Retake selfie',
                                  style: const TextStyle(
                                    color: AppColors.brown,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Tombol kirim
                      _reveal(
                        start: 0.58,
                        end: 0.92,
                        child: _PressScale(
                          onTap: (!_busy && passed) ? _submit : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: double.infinity,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (!_busy && passed)
                                  ? AppColors.brown
                                  : AppColors.brown.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: (!_busy && passed)
                                  ? [
                                      BoxShadow(
                                        color: AppColors.brown
                                            .withValues(alpha: 0.14),
                                        blurRadius: 20,
                                        offset: const Offset(0, 7),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: const Text(
                              'Submit verification',
                              style: TextStyle(
                                color: AppColors.cream,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (widget.fromOnboarding)
                        Center(
                          child: TextButton(
                            onPressed:
                                _busy ? null : () => _finish(verified: false),
                            child: const Text(
                              'Skip for now',
                              style: TextStyle(
                                color: AppColors.matchaDeep,
                                fontWeight: FontWeight.w700,
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

class _TipChip extends StatelessWidget {
  final String label;
  const _TipChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.matchaSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.matchaDeep,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressScale({required this.child, this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (!mounted) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _set(true),
        onTapCancel: widget.onTap == null ? null : () => _set(false),
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                _set(false);
                widget.onTap?.call();
              },
        child: widget.child,
      ),
    );
  }
}
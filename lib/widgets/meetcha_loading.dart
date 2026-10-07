// Simpan sebagai: lib/widgets/meetcha_loading.dart
//
// Animasi loading: dua kartu profil mengorbit di sepanjang cincin miring,
// bergantian lewat depan/belakang (efek 3D), sparkle berkedip, dan seluruh
// grup melayang pelan. Digambar dengan CustomPainter, jadi TIDAK butuh
// asset gambar/Lottie.
//
// Pemakaian:
//   const MeetchaLoadingScreen()                 // halaman penuh
//   const MeetchaLoading(size: 160)              // widget kecil (mis. di dialog)
import 'dart:math' as math;

import 'package:bumble/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Halaman loading penuh dengan latar krem.
class MeetchaLoadingScreen extends StatelessWidget {
  const MeetchaLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(child: MeetchaLoading()),
    );
  }
}

class MeetchaLoading extends StatefulWidget {
  final double size;

  /// Durasi satu putaran orbit penuh.
  final Duration period;

  const MeetchaLoading({
    super.key,
    this.size = 220,
    this.period = const Duration(milliseconds: 3200),
  });

  @override
  State<MeetchaLoading> createState() => _MeetchaLoadingState();
}

class _MeetchaLoadingState extends State<MeetchaLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            size: Size.square(widget.size),
            painter: _OrbitPainter(_controller.value),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  /// Progres animasi 0..1 (satu putaran penuh).
  final double t;
  _OrbitPainter(this.t);

  // ---- Palet (disamakan dengan screenshot) ----
  static const _brown = Color(0xFF8A624C);
  static const _green = Color(0xFF8FA98A);
  static const _ring = Color(0xFFC7C3AE);
  static const _silhouette = Color(0xFF3B2416);
  static const _tan = Color(0xFFD9B58C);
  static const _sparkle = Color(0xFFEADFC4);

  // ---- Geometri dalam ruang desain 200 x 200 ----
  static const double _rx = 62; // radius orbit horizontal
  static const double _ry = 22; // radius orbit vertikal (kemiringan 3D)
  static const double _tilt = -0.26; // kemiringan cincin (radian)
  static const double _cardW = 40;
  static const double _cardH = 52;

  static const _sparkles = <_Sparkle>[
    _Sparkle(Offset(-8, -62), 9, 0.00),
    _Sparkle(Offset(20, -8), 6, 0.35),
    _Sparkle(Offset(-52, 46), 5, 0.65),
    _Sparkle(Offset(58, 52), 4, 0.85),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 200);
    canvas.translate(100, 100);

    // Melayang pelan naik-turun.
    final bob = math.sin(t * 2 * math.pi) * 3;
    canvas.translate(0, bob);

    _paintSparkles(canvas);

    // Susunan lapisan: cincin belakang -> kartu belakang ->
    // cincin depan -> kartu depan. Di sinilah efek "mengorbit" terjadi.
    final angleA = t * 2 * math.pi;
    final angleB = angleA + math.pi;
    final cards = [
      _CardState(angleA, _brown),
      _CardState(angleB, _green),
    ]..sort((a, b) => a.depth.compareTo(b.depth)); // belakang dulu

    canvas.save();
    canvas.rotate(_tilt);
    _paintRingHalf(canvas, front: false);
    canvas.restore();

    _paintCard(canvas, cards.first);

    canvas.save();
    canvas.rotate(_tilt);
    _paintRingHalf(canvas, front: true);
    canvas.restore();

    _paintCard(canvas, cards.last);

    canvas.restore();
  }

  void _paintRingHalf(Canvas canvas, {required bool front}) {
    final rect =
        Rect.fromCenter(center: Offset.zero, width: _rx * 2, height: _ry * 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = front ? 3.2 : 2.4
      ..color = _ring.withValues(alpha: front ? 0.95 : 0.55);
    // Sudut 0..pi = setengah bawah (depan), pi..2pi = setengah atas (belakang).
    canvas.drawArc(rect, front ? 0 : math.pi, math.pi, false, paint);
  }

  void _paintCard(Canvas canvas, _CardState card) {
    // Posisi pada elips, lalu diputar mengikuti kemiringan cincin.
    final local = Offset(_rx * math.cos(card.angle), _ry * math.sin(card.angle));
    final cosT = math.cos(_tilt);
    final sinT = math.sin(_tilt);
    final pos = Offset(
      local.dx * cosT - local.dy * sinT,
      local.dx * sinT + local.dy * cosT,
    );

    final depth01 = (card.depth + 1) / 2; // 0 = paling belakang, 1 = paling depan
    final scale = 0.86 + 0.28 * depth01;
    final alpha = 0.82 + 0.18 * depth01;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(card.color == _brown ? -0.26 : 0.26);
    canvas.scale(scale);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: _cardW, height: _cardH),
      const Radius.circular(8),
    );

    // Bayangan lembut.
    canvas.drawRRect(
      body.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      body,
      Paint()..color = card.color.withValues(alpha: alpha),
    );

    // Siluet orang: lingkaran krem di belakang kepala + kepala + bahu.
    canvas.drawCircle(
      const Offset(0, -2),
      12,
      Paint()..color = _tan.withValues(alpha: 0.9 * alpha),
    );
    canvas.drawCircle(
      const Offset(0, -7),
      6.5,
      Paint()..color = _silhouette.withValues(alpha: alpha),
    );
    final shoulders = Path()
      ..moveTo(-13, 20)
      ..quadraticBezierTo(-13, 3, 0, 3)
      ..quadraticBezierTo(13, 3, 13, 20)
      ..close();
    canvas.drawPath(
      shoulders,
      Paint()..color = _silhouette.withValues(alpha: alpha),
    );

    canvas.restore();
  }

  void _paintSparkles(Canvas canvas) {
    for (final s in _sparkles) {
      // Berkedip dua kali per putaran, tiap sparkle beda fase.
      final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * (t * 2 + s.phase));
      final r = s.radius * (0.7 + 0.5 * pulse);
      canvas.drawPath(
        _star(s.offset, r),
        Paint()..color = _sparkle.withValues(alpha: 0.25 + 0.75 * pulse),
      );
    }
  }

  Path _star(Offset c, double r) {
    const k = 0.18;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * k, c.dy - r * k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * k, c.dy + r * k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * k, c.dy + r * k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * k, c.dy - r * k, c.dx, c.dy - r)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => oldDelegate.t != t;
}

class _CardState {
  final double angle;
  final Color color;
  _CardState(this.angle, this.color);

  /// -1 = paling belakang, +1 = paling depan.
  double get depth => math.sin(angle);
}

class _Sparkle {
  final Offset offset;
  final double radius;
  final double phase;
  const _Sparkle(this.offset, this.radius, this.phase);
}
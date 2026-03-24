import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/eyelike_theme.dart';

/// Animated “iris” rings — signature EyeLike visual (not a stock Material widget).
class IrisPulse extends StatefulWidget {
  const IrisPulse({super.key, this.size = 120});

  final double size;

  @override
  State<IrisPulse> createState() => _IrisPulseState();
}

class _IrisPulseState extends State<IrisPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _IrisPainter(_c.value),
        );
      },
    );
  }
}

class _IrisPainter extends CustomPainter {
  _IrisPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < 5; i++) {
      final phase = (t + i * 0.18) % 1.0;
      final radius = r * (0.25 + phase * 0.72);
      final a = (1 - phase).clamp(0.0, 1.0);
      final mix = i.isEven ? EyelikeColors.cyan : EyelikeColors.magenta;
      ringPaint.color = mix.withValues(alpha: 0.15 + 0.55 * a);
      canvas.drawCircle(c, radius, ringPaint);
    }

    final pupil = Paint()
      ..shader = RadialGradient(
        colors: [
          EyelikeColors.cyan.withValues(alpha: 0.95),
          EyelikeColors.magenta.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.35));

    canvas.drawCircle(c, r * 0.32, pupil);

    // Chromatic offset arc
    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = EyelikeColors.amber.withValues(alpha: 0.55);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.55),
      -math.pi / 2 + t * math.pi * 2,
      math.pi * 1.1,
      false,
      sweep,
    );
  }

  @override
  bool shouldRepaint(covariant _IrisPainter oldDelegate) => oldDelegate.t != t;
}

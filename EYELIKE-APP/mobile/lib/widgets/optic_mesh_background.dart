import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/eyelike_theme.dart';

/// Subtle moving grid + vignette so screens don’t look like default Flutter templates.
class OpticMeshBackground extends StatefulWidget {
  const OpticMeshBackground({super.key, required this.child});

  final Widget child;

  @override
  State<OpticMeshBackground> createState() => _OpticMeshBackgroundState();
}

class _OpticMeshBackgroundState extends State<OpticMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return CustomPaint(
              painter: _MeshPainter(_c.value),
              size: Size.infinite,
            );
          },
        ),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.25),
              radius: 1.15,
              colors: [
                EyelikeColors.magenta.withValues(alpha: 0.08),
                Colors.transparent,
                EyelikeColors.voidBlack,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const step = 42.0;
    final shift = t * step;

    for (double x = -shift % step; x < size.width + step; x += step) {
      paint.color = EyelikeColors.cyan.withValues(alpha: 0.04);
      canvas.drawLine(Offset(x, 0), Offset(x + 18, size.height), paint);
    }
    for (double y = shift % step; y < size.height + step; y += step) {
      paint.color = EyelikeColors.magenta.withValues(alpha: 0.035);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 12), paint);
    }

    final hud = Paint()
      ..color = EyelikeColors.cyan.withValues(alpha: 0.2)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const len = 28.0;
    for (final origin in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final flipX = origin.dx > size.width / 2 ? -1.0 : 1.0;
      final flipY = origin.dy > size.height / 2 ? -1.0 : 1.0;
      canvas.drawLine(origin, origin + Offset(len * flipX, 0), hud);
      canvas.drawLine(origin, origin + Offset(0, len * flipY), hud);
    }

    final bandY = size.height * (0.25 + 0.5 * math.sin(t * math.pi * 2));
    final band = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          EyelikeColors.cyan.withValues(alpha: 0.045),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, bandY - 40, size.width, 80));
    canvas.drawRect(Rect.fromLTWH(0, bandY - 40, size.width, 80), band);
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) => oldDelegate.t != t;
}

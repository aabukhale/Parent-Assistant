import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';

/// Circular progress with a centred label. Animates to its value unless the
/// user asked for reduced motion.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 8,
    this.color,
    this.track,
    this.center,
    this.semanticsLabel,
  });

  /// 0..1
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? track;
  final Widget? center;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      value: '${(clamped * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: clamped),
          duration: AppMotion.resolve(
            context,
            const Duration(milliseconds: 500),
          ),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => CustomPaint(
            painter: _RingPainter(
              value: v,
              stroke: stroke,
              color: color ?? c.accent.foreground,
              track: track ?? c.surfaceStrong,
            ),
            child: child,
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);
    if (value <= 0) return;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

/// Rounded linear progress bar.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.color,
    this.track,
    this.semanticsLabel,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? track;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      value: '${(clamped * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: track ?? c.surfaceStrong),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: clamped),
                duration: AppMotion.resolve(
                  context,
                  const Duration(milliseconds: 450),
                ),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color ?? c.accent.foreground,
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

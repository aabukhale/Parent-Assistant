import 'package:flutter/material.dart';

import '../theme/mamily_colors.dart';

/// Mamily's mark: a warm coral tile with an "M" heart-house shape.
class MamilyBrandMark extends StatelessWidget {
  const MamilyBrandMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mamily',
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.3),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE5533D), Color(0xFFC2331F)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD43A26).withValues(alpha: 0.25),
              blurRadius: size * 0.25,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        child: CustomPaint(painter: _MarkPainter()),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // A roof-shaped "M".
    final path = Path()
      ..moveTo(w * 0.24, h * 0.72)
      ..lineTo(w * 0.24, h * 0.40)
      ..lineTo(w * 0.50, h * 0.60)
      ..lineTo(w * 0.76, h * 0.40)
      ..lineTo(w * 0.76, h * 0.72);
    canvas.drawPath(path, p);
    // A small sun-dot above, for warmth.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.27),
      w * 0.07,
      Paint()..color = MamilyPalette.sunshine,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

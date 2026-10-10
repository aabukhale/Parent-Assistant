import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';

/// A quick, non-blocking celebration: a burst of confetti and a message that
/// fades out on its own. With reduced motion it is a calm badge instead. It
/// is always announced to screen readers.
class Celebration {
  const Celebration._();

  static void show(
    BuildContext context, {
    required String message,
    String emoji = '🎉',
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationLayer(
        message: message,
        emoji: emoji,
        reduceMotion: reduceMotion,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _CelebrationLayer extends StatefulWidget {
  const _CelebrationLayer({
    required this.message,
    required this.emoji,
    required this.reduceMotion,
    required this.onDone,
  });

  final String message;
  final String emoji;
  final bool reduceMotion;
  final VoidCallback onDone;

  @override
  State<_CelebrationLayer> createState() => _CelebrationLayerState();
}

class _CelebrationLayerState extends State<_CelebrationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.reduceMotion
        ? const Duration(milliseconds: 1400)
        : AppMotion.celebrate + const Duration(milliseconds: 600),
  )..forward().whenComplete(widget.onDone);

  final _rng = math.Random();
  late final List<_Piece> _pieces = List.generate(
    widget.reduceMotion ? 0 : 36,
    (_) => _Piece(
      angle: _rng.nextDouble() * math.pi * 2,
      speed: 0.4 + _rng.nextDouble() * 0.6,
      color: [
        MamilyPalette.sunshine,
        MamilyPalette.sky,
        MamilyPalette.mint,
        MamilyPalette.grape,
        MamilyPalette.decorCoral,
        MamilyPalette.bubblegum,
      ][_rng.nextInt(6)],
      size: 6 + _rng.nextDouble() * 6,
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
          return Stack(
            children: [
              if (!widget.reduceMotion)
                Positioned.fill(
                  child: CustomPaint(painter: _ConfettiPainter(_pieces, t)),
                ),
              Center(
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: widget.reduceMotion
                        ? 1
                        : (0.85 +
                              0.15 *
                                  Curves.elasticOut.transform(
                                    math.min(1, t * 2.2),
                                  )),
                    child: Material(
                      color: c.surface,
                      elevation: 6,
                      shadowColor: Colors.black26,
                      borderRadius: AppRadii.xlAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                          vertical: AppSpacing.xl,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.emoji,
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: context.type.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
  });

  final double angle;
  final double speed;
  final Color color;
  final double size;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.55;
    for (final p in pieces) {
      final d = radius * p.speed * Curves.easeOutCubic.transform(t.clamp(0, 1));
      final gravity = 140 * t * t;
      final pos =
          center +
          Offset(math.cos(p.angle) * d, math.sin(p.angle) * d + gravity);
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.angle + t * 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

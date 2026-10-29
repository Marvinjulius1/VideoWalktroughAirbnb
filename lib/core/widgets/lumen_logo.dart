import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/theme.dart';

/// Eigenes Lumen-Zeichen: ein Lichtkreis mit einem offenen Bogen –
/// „Licht an, Bild an“. Bewusst schlicht und ohne Bezug zu anderen Apps.
class LumenLogo extends StatelessWidget {
  const LumenLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    return Semantics(
      label: 'Lumen',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _LumenMarkPainter(
          accent: l.accent,
          ring: l.palette.textPrimary,
        ),
      ),
    );
  }
}

class _LumenMarkPainter extends CustomPainter {
  _LumenMarkPainter({required this.accent, required this.ring});

  final Color accent;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final stroke = size.width * 0.09;

    // Offener Ring (Bogen von 300°).
    final arc = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - stroke),
      -math.pi / 2 + math.pi / 6,
      math.pi * 2 - math.pi / 3,
      false,
      arc,
    );

    // Leuchtender Kern.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [accent, accent.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.62));
    canvas.drawCircle(c, r * 0.62, glow);
    canvas.drawCircle(c, r * 0.24, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_LumenMarkPainter old) =>
      old.accent != accent || old.ring != ring;
}

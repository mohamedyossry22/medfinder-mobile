import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/fmt.dart';
import 'common.dart';

/// حلقة العد التنازلي للطلب (6 ساعات): نفس حلقة الويب
class CountdownRing extends StatelessWidget {
  const CountdownRing({super.key, required this.expiresAt, required this.now});
  final DateTime expiresAt, now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = isDark(context);
    final h = hoursLeft(expiresAt, now);
    return Semantics(
      label: 'متبقي $h ساعة',
      excludeSemantics: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: CustomPaint(
          painter: _RingPainter(remainingFrac(expiresAt, now), dark ? const Color(0xFF12322C) : const Color(0xFFE3F6F1), cs.primary),
          child: Center(child: Text('${h}س', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.frac, this.track, this.color);
  final double frac;
  final Color track, color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.shortestSide - 5) / 2;
    final c = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    p.color = track;
    canvas.drawCircle(c, r, p);
    if (frac > 0) {
      p.color = color;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * frac, false, p);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.frac != frac || o.track != track || o.color != color;
}

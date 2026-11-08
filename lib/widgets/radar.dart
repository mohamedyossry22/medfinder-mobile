import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class RadarPin {
  final String id, status;
  final double distanceKm;
  const RadarPin(this.id, this.status, this.distanceKm);
}

/// رادار: دواير متوسعة من موقع المستخدم، ودبابيس الصيدليات بالبُعد الحقيقي ولون حالة الرد.
class RadarView extends StatefulWidget {
  const RadarView({super.key, required this.radiusKm, required this.pins, this.animate = true, this.size = 230});
  final double radiusKm, size;
  final List<RadarPin> pins;
  final bool animate;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations; // احترام إعداد تقليل الحركة
    if (widget.animate && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didUpdateWidget(covariant RadarView old) {
    super.didUpdateWidget(old);
    if (!widget.animate) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'رادار الصيدليات في نطاق ${widget.radiusKm.toStringAsFixed(0)} كم',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _RadarPainter(_c.value, widget.pins, widget.radiusKm, dark),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.pins, this.radiusKm, this.dark);
  final double t, radiusKm;
  final List<RadarPin> pins;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.width / 2 - 8;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = kPrimary.withAlpha(dark ? 90 : 70);
    for (final f in [1 / 3, 2 / 3, 1.0]) {
      canvas.drawCircle(c, R * f, ring);
    }
    canvas.drawCircle(c, R, Paint()..color = kPrimary.withAlpha(dark ? 28 : 18));

    // نبضة
    final pulse = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = kPrimary.withAlpha(((1 - t) * 160).round());
    canvas.drawCircle(c, R * t, pulse);

    // دبابيس (زاوية بالـ golden angle، وبُعد بنسبة المسافة للنطاق)
    for (var i = 0; i < pins.length; i++) {
      final p = pins[i];
      final a = i * 2.399963;
      final r = R * (p.distanceKm / (radiusKm <= 0 ? 1 : radiusKm)).clamp(0.18, 0.96);
      final o = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(o, 9, Paint()..color = dark ? const Color(0xFF0E1513) : Colors.white);
      canvas.drawCircle(o, 6.5, Paint()..color = pinColor(p.status));
    }

    canvas.drawCircle(c, 9, Paint()..color = dark ? const Color(0xFF0E1513) : Colors.white);
    canvas.drawCircle(c, 6, Paint()..color = kPrimary);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t || old.pins != pins;
}

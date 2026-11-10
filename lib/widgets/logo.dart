import 'package:flutter/material.dart';
import '../core/theme.dart';

/// لوجو MedFinder: دبوس موقع فيه علامة طبية. نفس تصميم لوجو الويب.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.showName = false, this.stacked = false, this.onDark = false});
  final double size;
  final bool showName, stacked, onDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mark = SizedBox(width: size, height: size, child: CustomPaint(painter: _LogoPainter(onDark)));
    if (!showName) return Semantics(label: 'MedFinder', child: mark);

    final base = onDark ? Colors.white : cs.onSurface;
    final accent = onDark ? Colors.white : cs.primary;
    final fs = size * (stacked ? 0.36 : 0.52);
    final text = Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Med', style: TextStyle(fontWeight: FontWeight.w400, color: base)),
        TextSpan(text: 'Finder', style: TextStyle(fontWeight: FontWeight.w800, color: accent)),
      ]),
      textDirection: TextDirection.ltr,
      style: TextStyle(fontSize: fs, letterSpacing: 0.2),
    );
    return Semantics(
      label: 'MedFinder',
      excludeSemantics: true,
      child: stacked
          ? Column(mainAxisSize: MainAxisSize.min, children: [mark, SizedBox(height: size * 0.15), text])
          : Row(mainAxisSize: MainAxisSize.min, children: [mark, SizedBox(width: size * 0.25), text]),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.onDark);
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64);
    final bg = onDark ? Colors.white : kPrimary;
    final pinColor = onDark ? kPrimary : Colors.white;
    final cross = onDark ? Colors.white : kPrimary;

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 64, 64), const Radius.circular(16)), Paint()..color = bg);

    final pin = Path()
      ..moveTo(32, 10)
      ..arcToPoint(const Offset(16, 26), radius: const Radius.circular(16), clockwise: false)
      ..cubicTo(16, 38, 32, 54, 32, 54)
      ..cubicTo(32, 54, 48, 38, 48, 26)
      ..arcToPoint(const Offset(32, 10), radius: const Radius.circular(16), clockwise: false)
      ..close();
    canvas.drawPath(pin, Paint()..color = pinColor);

    final plus = Path()
      ..moveTo(29, 18)
      ..lineTo(35, 18)
      ..lineTo(35, 23)
      ..lineTo(40, 23)
      ..lineTo(40, 29)
      ..lineTo(35, 29)
      ..lineTo(35, 34)
      ..lineTo(29, 34)
      ..lineTo(29, 29)
      ..lineTo(24, 29)
      ..lineTo(24, 23)
      ..lineTo(29, 23)
      ..close();
    canvas.drawPath(plus, Paint()..color = cross);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.onDark != onDark;
}

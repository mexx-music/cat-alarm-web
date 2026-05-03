import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/starfield.dart';

class ClockView extends StatelessWidget {
  final int hour;
  final int minute;
  final void Function(int, int) onTimeChanged;
  const ClockView({
    super.key,
    required this.hour,
    required this.minute,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: Starfield()),
        LayoutBuilder(
          builder: (context, c) {
            final size = math.min(c.maxWidth, c.maxHeight) - 24;
            final center = Offset(c.maxWidth / 2, c.maxHeight / 2);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                final local = d.localPosition - center;
                final ang = ((math.atan2(local.dy, local.dx) - math.pi / 2) +
                        2 * math.pi) %
                    (2 * math.pi);
                final m = ((ang / (2 * math.pi)) * 60).round() % 60;
                final h = ((ang / (2 * math.pi)) * 12).round() % 12;
                onTimeChanged(h, m);
              },
              child: Center(
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _ClockPainter(hour: hour, minute: minute),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ClockPainter extends CustomPainter {
  final int hour, minute;
  _ClockPainter({required this.hour, required this.minute});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    // Grundfläche
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = const Color(0xFFFFFFFF).withAlpha((0.8 * 255).round());
    canvas.drawCircle(center, r, ring);

    // Zahlen
    final tp = TextPainter(
        textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    for (int i = 1; i <= 12; i++) {
      final ang = -math.pi / 2 + (i * 2 * math.pi / 12);
      final pos = center + Offset(math.cos(ang), math.sin(ang)) * (r - 40);
      tp.text = TextSpan(
        text: '$i',
        style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // Zeiger
    final angMin = -math.pi / 2 + (minute * 2 * math.pi / 60);
    final angHour =
        -math.pi / 2 + (((hour % 12) + minute / 60) * 2 * math.pi / 12);
    _drawHand(canvas, center, r * 0.78, angMin, 6, Colors.white70);
    _drawHand(canvas, center, r * 0.55, angHour, 8, Colors.white);
  }

  void _drawHand(
      Canvas c, Offset ctr, double len, double ang, double width, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final tip = ctr + Offset(math.cos(ang), math.sin(ang)) * len;
    c.drawLine(ctr, tip, paint);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) =>
      old.hour != hour || old.minute != minute;
}

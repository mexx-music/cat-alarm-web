// lib/widgets/clock_view.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'starfield.dart'; // liegt im selben Ordner

class ClockView extends StatefulWidget {
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onTimeChanged;

  const ClockView({
    super.key,
    required this.hour,
    required this.minute,
    required this.onTimeChanged,
  });

  @override
  State<ClockView> createState() => _ClockViewState();
}

class _ClockViewState extends State<ClockView> {
  bool _dragHour = false, _dragMinute = false;
  double? _dragOffsetMinute, _dragOffsetHour;
  int? _prevMinute;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = math.min(c.maxWidth, c.maxHeight) - 24;
      final center = Offset(c.maxWidth / 2, c.maxHeight / 2);
      final radius = size / 2;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _onPanStart(d, center, radius),
        onPanUpdate: (d) => _onPanUpdate(d, center, radius),
        onPanEnd: _onPanEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(0.25))),
            Center(
              child: CustomPaint(
                size: Size.square(size),
                painter: _ClockPainter(
                  hour: widget.hour,
                  minute: widget.minute,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // === Drag-Logik (wie in deiner funktionierenden Version) ===
  void _onPanStart(DragStartDetails d, Offset center, double radius) {
    final local = d.localPosition - center;
    final touchAngle =
        ((math.atan2(local.dy, local.dx) - math.pi / 2) + 2 * math.pi) %
            (2 * math.pi);

    final mAng = (widget.minute / 60 * 2 * math.pi) % (2 * math.pi);
    final hAng =
        (((widget.hour % 12) + widget.minute / 60) * 2 * math.pi / 12) %
            (2 * math.pi);

    final mTip = center +
        Offset(math.cos(mAng - math.pi / 2), math.sin(mAng - math.pi / 2)) *
            (radius * 0.78);
    final hTip = center +
        Offset(math.cos(hAng - math.pi / 2), math.sin(hAng - math.pi / 2)) *
            (radius * 0.58);
    const mHit = 56.0;
    const hHit = 64.0;

    final dm = (d.localPosition - mTip).distance;
    final dh = (d.localPosition - hTip).distance;

    _dragMinute = dm <= mHit && dm <= dh;
    _dragHour = !_dragMinute && dh <= hHit;

    if (_dragMinute) {
      _dragOffsetMinute = (mAng - touchAngle) % (2 * math.pi);
      _prevMinute = widget.minute;
    } else if (_dragHour) {
      _dragOffsetHour = (hAng - touchAngle) % (2 * math.pi);
    }
  }

  void _onPanUpdate(DragUpdateDetails d, Offset center, double radius) {
    final local = d.localPosition - center;
    var touchAngle =
        ((math.atan2(local.dy, local.dx) - math.pi / 2) + 2 * math.pi) %
            (2 * math.pi);

    int newHour = widget.hour;
    int newMinute = widget.minute;

    if (_dragMinute && _dragOffsetMinute != null) {
      final angle = (touchAngle + _dragOffsetMinute!) % (2 * math.pi);
      final norm = angle % (2 * math.pi);
      final m = ((norm / (2 * math.pi)) * 60).round() % 60;

      if (_prevMinute != null) {
        if (_prevMinute == 59 && m == 0) newHour = (newHour + 1) % 24;
        if (_prevMinute == 0 && m == 59) newHour = (newHour - 1 + 24) % 24;
      }
      newMinute = m;
      _prevMinute = m;
    } else if (_dragHour && _dragOffsetHour != null) {
      final angle = (touchAngle + _dragOffsetHour!) % (2 * math.pi);
      final norm = angle % (2 * math.pi);
      final h = ((norm / (2 * math.pi)) * 12).round() % 12;
      int hh = h == 0 ? 12 : h;
      if (newHour >= 12) {
        newHour = (hh % 12) + 12; // PM beibehalten
      } else {
        newHour = hh % 12;        // AM beibehalten
      }
    }

    if (newHour != widget.hour || newMinute != widget.minute) {
      widget.onTimeChanged(newHour, newMinute);
    }
  }

  void _onPanEnd(DragEndDetails d) {
    _dragHour = _dragMinute = false;
    _dragOffsetMinute = null;
    _dragOffsetHour = null;
    _prevMinute = null;
  }
}

class _ClockPainter extends CustomPainter {
  final int hour, minute;
  _ClockPainter({required this.hour, required this.minute});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    // Zifferblatt
    final face = Paint()..color = Colors.black.withOpacity(0.15);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white.withOpacity(0.85);

    canvas.drawCircle(center, r, face);
    canvas.drawCircle(center, r, ring);

    // Ticks + Zahlen
    final tick = Paint()..color = Colors.white..strokeWidth = 2;
    final tick5 = Paint()..color = Colors.white..strokeWidth = 4;
    final tp = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);

    for (int i = 0; i < 60; i++) {
      final ang = -math.pi/2 + i*2*math.pi/60;
      final inner = center + Offset(math.cos(ang), math.sin(ang)) * (r - (i%5==0?22:12));
      final outer = center + Offset(math.cos(ang), math.sin(ang)) * r;
      canvas.drawLine(inner, outer, i%5==0 ? tick5 : tick);

      if (i % 5 == 0) {
        final num = (i ~/ 5 == 0) ? 12 : i ~/ 5;
        final pos = center + Offset(math.cos(ang), math.sin(ang)) * (r - 44);
        tp.text = TextSpan(
          text: '$num',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        );
        tp.layout();
        tp.paint(canvas, pos - Offset(tp.width/2, tp.height/2));
      }
    }

    // Winkel
    final angMin = -math.pi / 2 + (minute * 2 * math.pi / 60);
    final angHour = -math.pi / 2 + (((hour % 12) + minute / 60) * 2 * math.pi / 12);

    // Minutenzeiger (lang, halbtransparent)
    _drawCatHand(canvas, center, r * 0.78, angMin, width: 9, faded: true);
    // Stundenzeiger (kurz, normal)
    _drawCatHand(canvas, center, r * 0.58, angHour, width: 11, faded: false);

    // Nabe
    canvas.drawCircle(center, 11, Paint()..color = Colors.black.withOpacity(0.9));
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
  }

  void _drawCatHand(Canvas c, Offset ctr, double len, double ang,
      {required double width, required bool faded}) {
    final shaft = Paint()
      ..color = Colors.white.withOpacity(faded ? 0.6 : 0.95)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final tip = ctr + Offset(math.cos(ang), math.sin(ang)) * len;
    c.drawLine(ctr, tip, shaft);

    // Katzenkopf-Emoji an der Spitze
    final tp = TextPainter(
      text: TextSpan(
        text: '🐱',
        style: TextStyle(fontSize: 44, color: Colors.white.withOpacity(faded ? 0.6 : 1)),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(c, tip - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ClockPainter o) => o.hour != hour || o.minute != minute;
}

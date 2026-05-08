// lib/widgets/clock_view.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ClockView extends StatefulWidget {
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onTimeChanged;
  final DateTime? now;

  const ClockView({
    super.key,
    required this.hour,
    required this.minute,
    required this.onTimeChanged,
    this.now,
  });

  @override
  State<ClockView> createState() => _ClockViewState();
}

class _ClockViewState extends State<ClockView> {
  bool _dragHour = false, _dragMinute = false;
  bool _isDragging = false;
  double? _dragOffsetMinute, _dragOffsetHour;
  int? _prevMinute;
  bool _showAlarmTime = false;
  Timer? _revertTimer;

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }

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
            AnimatedOpacity(
              opacity: _isDragging ? 0.0 : 0.34,
              duration: const Duration(milliseconds: 300),
              child: Align(
                alignment: const Alignment(0, 0.2),
                child: Image.asset(
                  'assets/images/catclock.png',
                  width: size * 0.65,
                  height: size * 0.65,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Center(
              child: CustomPaint(
                size: Size.square(size),
                painter: _ClockPainter(
                  hour: widget.hour,
                  minute: widget.minute,
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: _showAlarmTime
                  ? _buildAlarmTimeOverlay()
                  : widget.now != null
                      ? SizedBox(
                          width: 80,
                          height: 80,
                          child: CustomPaint(
                            painter: _MiniClockPainter(widget.now!),
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAlarmTimeOverlay() {
    final h = widget.hour.toString().padLeft(2, '0');
    final m = widget.minute.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withAlpha(195),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$h:$m',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // === Drag-Logik (wie in deiner funktionierenden Version) ===
  void _onPanStart(DragStartDetails d, Offset center, double radius) {
    final local = d.localPosition - center;
    final touchAngle =
        ((math.atan2(local.dy, local.dx) - math.pi / 2) + 2 * math.pi) %
            (2 * math.pi);

    final mAng = (widget.minute / 60 * 2 * math.pi) % (2 * math.pi);
    final hAng =
        ((widget.hour % 12) * 2 * math.pi / 12) % (2 * math.pi);

    final mTip = center +
        Offset(math.cos(mAng - math.pi / 2), math.sin(mAng - math.pi / 2)) *
            (radius * 0.78);
    final hTip = center +
        Offset(math.cos(hAng - math.pi / 2), math.sin(hAng - math.pi / 2)) *
            (radius * 0.78);
    const mHit = 56.0;
    const hHit = 64.0;

    final dm = (d.localPosition - mTip).distance;
    final dh = (d.localPosition - hTip).distance;

    _dragHour = dh <= hHit && dh <= dm;
    _dragMinute = !_dragHour && dm <= mHit;

    if (_dragMinute) {
      _dragOffsetMinute = (mAng - touchAngle) % (2 * math.pi);
      _prevMinute = widget.minute;
    } else if (_dragHour) {
      _dragOffsetHour = (hAng - touchAngle) % (2 * math.pi);
    }

    if (_dragMinute || _dragHour) {
      _revertTimer?.cancel();
      setState(() { _showAlarmTime = true; _isDragging = true; });
    }
  }

  void _onPanUpdate(DragUpdateDetails d, Offset center, double radius) {
    final local = d.localPosition - center;
    final touchAngle =
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
      final int hh = h == 0 ? 12 : h;
      if (newHour >= 12) {
        newHour = (hh % 12) + 12; // PM beibehalten
      } else {
        newHour = hh % 12; // AM beibehalten
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
    _revertTimer?.cancel();
    setState(() => _isDragging = false);
    _revertTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showAlarmTime = false);
    });
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
    final face = Paint()
      ..color = const Color(0xFF000000).withAlpha((0.15 * 255).round());
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = const Color(0xFFFFFFFF).withAlpha((0.85 * 255).round());

    canvas.drawCircle(center, r, face);
    canvas.drawCircle(center, r, ring);

    // Ticks + Zahlen
    final tick = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    final tick5 = Paint()
      ..color = Colors.white
      ..strokeWidth = 4;
    final tp = TextPainter(
        textAlign: TextAlign.center, textDirection: TextDirection.ltr);

    for (int i = 0; i < 60; i++) {
      final ang = -math.pi / 2 + i * 2 * math.pi / 60;
      final inner = center +
          Offset(math.cos(ang), math.sin(ang)) * (r - (i % 5 == 0 ? 22 : 12));
      final outer = center + Offset(math.cos(ang), math.sin(ang)) * r;
      canvas.drawLine(inner, outer, i % 5 == 0 ? tick5 : tick);

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
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Winkel
    final angMin = -math.pi / 2 + (minute * 2 * math.pi / 60);
    final angHour =
        -math.pi / 2 + ((hour % 12) * 2 * math.pi / 12);

    // Minutenzeiger (cyan, Pfote)
    _drawCatHand(canvas, center, r * 0.78, angMin,
        width: 3, faded: true, innerLen: r * 0.25,
        markerColor: const Color(0xFF0097A7).withAlpha(210),
        emoji: '🐾', emojiSize: 26);
    // Stundenzeiger (gold, Katze)
    _drawCatHand(canvas, center, r * 0.78, angHour,
        width: 5, faded: false, innerLen: r * 0.25,
        markerColor: const Color(0xFFFFB300).withAlpha(230),
        emoji: '🐱', emojiSize: 34);

    // Nabe
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..color = const Color(0xFF000000).withAlpha((0.9 * 255).round()));
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFFFFFFFF));
  }

  void _drawCatHand(Canvas c, Offset ctr, double len, double ang,
      {required double width,
       required bool faded,
       double innerLen = 0.0,
       required Color markerColor,
       required String emoji,
       required double emojiSize}) {
    final shaft = Paint()
      ..color = const Color(0xFFFFFFFF)
          .withAlpha(((faded ? 0.6 : 0.95) * 255).round())
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final dir = Offset(math.cos(ang), math.sin(ang));
    final start = ctr + dir * innerLen;
    final tip = ctr + dir * len;
    c.drawLine(start, tip, shaft);

    // Farbiger Kreis als Hintergrund
    final circleR = emojiSize * 0.58;
    c.drawCircle(tip, circleR, Paint()..color = markerColor);
    c.drawCircle(
      tip, circleR,
      Paint()
        ..color = Colors.white.withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Emoji
    final tp2 = TextPainter(
        text: TextSpan(text: emoji, style: TextStyle(fontSize: emojiSize)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp2.layout();
    tp2.paint(c, tip - Offset(tp2.width / 2, tp2.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ClockPainter o) =>
      o.hour != hour || o.minute != minute;
}

class _MiniClockPainter extends CustomPainter {
  final DateTime now;
  _MiniClockPainter(this.now);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    canvas.drawCircle(
        center, r, Paint()..color = const Color(0xFF000000).withAlpha(100));
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFFFFF).withAlpha(180));

    // Hour hand
    final hAngle = -math.pi / 2 +
        ((now.hour % 12) + now.minute / 60) * 2 * math.pi / 12;
    _hand(canvas, center, r * 0.5, hAngle, 3, 200);

    // Minute hand
    final mAngle = -math.pi / 2 + now.minute * 2 * math.pi / 60;
    _hand(canvas, center, r * 0.7, mAngle, 2, 200);

    // Second hand
    final sAngle = -math.pi / 2 + now.second * 2 * math.pi / 60;
    _hand(canvas, center, r * 0.72, sAngle, 1, 220);

    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  void _hand(Canvas c, Offset center, double len, double angle, double width,
      int alpha) {
    c.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * len,
        Paint()
          ..color = Colors.white.withAlpha(alpha)
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _MiniClockPainter o) =>
      o.now.second != now.second ||
      o.now.minute != now.minute ||
      o.now.hour != now.hour;
}

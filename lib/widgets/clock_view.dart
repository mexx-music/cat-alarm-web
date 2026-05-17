// lib/widgets/clock_view.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ClockView extends StatefulWidget {
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onTimeChanged;
  final DateTime? now;

  /// Wenn false, wird das große Sleepcat-Bild im Zifferblatt NICHT gerendert
  /// (z. B. iPad-Hochformat, wo der Vordergrund-Background bereits eine
  /// Katze zeigt). iPhone-Aufrufe ohne Wert behalten true → Verhalten
  /// unverändert.
  final bool showCatImage;

  /// Skalierungsfaktor für die kleine Live-Mini-Uhr in der Mitte.
  /// 1.0 = bisherige Größe (iPhone). Werte < 1 verkleinern sie ohne die
  /// äußere Uhr zu verändern.
  final double miniClockScale;

  const ClockView({
    super.key,
    required this.hour,
    required this.minute,
    required this.onTimeChanged,
    this.now,
    this.showCatImage = true,
    this.miniClockScale = 1.0,
  });

  @override
  State<ClockView> createState() => _ClockViewState();
}

class _ClockViewState extends State<ClockView> {
  bool _dragHour = false, _dragMinute = false;
  bool _isDragging = false;
  double? _dragOffsetMinute, _dragOffsetHour;
  int? _prevMinute;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxW = c.maxWidth.isFinite ? c.maxWidth : 0.0;
      final maxH = c.maxHeight.isFinite ? c.maxHeight : 0.0;
      final size = math.max(0.0, math.min(maxW, maxH) - 24);
      if (size <= 0) {
        return const SizedBox.shrink();
      }
      final center = Offset(maxW / 2, maxH / 2);
      final radius = size / 2;
      final catSize = math.max(0.0, size * 0.72);
      final miniSize = math.min(80.0, size * 0.32) * widget.miniClockScale;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _onPanStart(d, center, radius),
        onPanUpdate: (d) => _onPanUpdate(d, center, radius),
        onPanEnd: _onPanEnd,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.showCatImage)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _isDragging ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Align(
                      alignment: const Alignment(0, 0.15),
                      child: SizedBox(
                        width: catSize,
                        height: catSize,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (Rect bounds) {
                            return const RadialGradient(
                              center: Alignment.center,
                              radius: 0.5,
                              colors: <Color>[
                                Color(0xFFFFFFFF),
                                Color(0xFFFFFFFF),
                                Color(0x00FFFFFF),
                              ],
                              stops: <double>[0.0, 0.62, 1.0],
                            ).createShader(bounds);
                          },
                          child: Image.asset(
                            'assets/images/sleepcat.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _ClockPainter(
                    hour: widget.hour,
                    minute: widget.minute,
                  ),
                ),
              ),
              if (widget.now != null && miniSize > 0)
                SizedBox(
                  width: miniSize,
                  height: miniSize,
                  child: CustomPaint(
                    painter: _MiniClockPainter(widget.now!),
                  ),
                ),
            ],
          ),
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
      setState(() => _isDragging = true);
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
    setState(() => _isDragging = false);
  }
}

class _ClockPainter extends CustomPainter {
  final int hour, minute;
  _ClockPainter({required this.hour, required this.minute});

  // Warm cozy palette
  static const Color _gold = Color(0xFFE8C28A);
  static const Color _goldSoft = Color(0xFFC9A36A);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    // Zifferblatt (sehr dezent, transluzent)
    final face = Paint()
      ..color = const Color(0xFF1A1530).withAlpha(45);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _gold.withAlpha(110);
    final ringGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = _gold.withAlpha(28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(center, r, face);
    canvas.drawCircle(center, r, ringGlow);
    canvas.drawCircle(center, r, ring);

    // Ticks + Zahlen (warm gold, dünne Linien)
    final tick = Paint()
      ..color = _goldSoft.withAlpha(110)
      ..strokeWidth = 1;
    final tick5 = Paint()
      ..color = _gold.withAlpha(190)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final tp = TextPainter(
        textAlign: TextAlign.center, textDirection: TextDirection.ltr);

    for (int i = 0; i < 60; i++) {
      final ang = -math.pi / 2 + i * 2 * math.pi / 60;
      final inner = center +
          Offset(math.cos(ang), math.sin(ang)) * (r - (i % 5 == 0 ? 16 : 8));
      final outer =
          center + Offset(math.cos(ang), math.sin(ang)) * (r - 2);
      canvas.drawLine(inner, outer, i % 5 == 0 ? tick5 : tick);

      if (i % 5 == 0) {
        final num = (i ~/ 5 == 0) ? 12 : i ~/ 5;
        final pos = center + Offset(math.cos(ang), math.sin(ang)) * (r - 38);
        tp.text = TextSpan(
          text: '$num',
          style: const TextStyle(
            color: _gold,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
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

    // Minutenzeiger (sehr dezent)
    _drawCatHand(canvas, center, r * 0.74, angMin,
        width: 1.6,
        innerLen: r * 0.18,
        shaftColor: _goldSoft.withAlpha(150),
        markerColor: _goldSoft.withAlpha(180),
        emoji: '🐾',
        emojiSize: 20);
    // Stundenzeiger (warm gold, Katzenkopf)
    _drawCatHand(canvas, center, r * 0.62, angHour,
        width: 2.4,
        innerLen: r * 0.18,
        shaftColor: _gold.withAlpha(220),
        markerColor: _gold.withAlpha(235),
        emoji: '🐱',
        emojiSize: 28);

    // Nabe
    canvas.drawCircle(center, 6, Paint()..color = _gold);
    canvas.drawCircle(center, 2.5, Paint()..color = const Color(0xFF1A1530));
  }

  void _drawCatHand(Canvas c, Offset ctr, double len, double ang,
      {required double width,
       double innerLen = 0.0,
       required Color shaftColor,
       required Color markerColor,
       required String emoji,
       required double emojiSize}) {
    final shaft = Paint()
      ..color = shaftColor
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final dir = Offset(math.cos(ang), math.sin(ang));
    final start = ctr + dir * innerLen;
    final tip = ctr + dir * len;
    c.drawLine(start, tip, shaft);

    // Warm glow
    final circleR = emojiSize * 0.55;
    c.drawCircle(
        tip,
        circleR + 4,
        Paint()
          ..color = markerColor.withAlpha(60)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    c.drawCircle(tip, circleR, Paint()..color = markerColor);

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

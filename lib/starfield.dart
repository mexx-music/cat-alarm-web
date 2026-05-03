import 'dart:math';
import 'package:flutter/material.dart';

class Starfield extends StatefulWidget {
  final double backgroundBrightness;
  const Starfield({super.key, this.backgroundBrightness = 0.18});

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;
  static const int starCount = 260; // dichter, aber nicht zu hell
  static const int seed = 42;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _stars = _generateStars(starCount, seed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _StarfieldPainter(
              _stars, _controller.value, widget.backgroundBrightness),
        ),
      ),
    );
  }

  List<_Star> _generateStars(int count, int seed) {
    final rng = Random(seed);
    return List.generate(count, (_) {
      return _Star(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        radius: rng.nextDouble() * 0.8 + 0.3, // kleinere Punkte
        twinklePhase: rng.nextDouble(),
        // use withAlpha to avoid deprecated withOpacity
        color: const Color(0xFFFFFFFF)
            .withAlpha(((0.8 + rng.nextDouble() * 0.2) * 255).round()),
      );
    });
  }
}

class _Star {
  final double dx, dy;
  final double radius;
  final double twinklePhase;
  final Color color;
  const _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.twinklePhase,
    required this.color,
  });
}

class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  final double backgroundBrightness;
  const _StarfieldPainter(this.stars, this.t, this.backgroundBrightness);

  @override
  void paint(Canvas canvas, Size size) {
    // Hintergrund: dunkler Sternenhimmel
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(
              const Color(0xFF040507), Colors.white, backgroundBrightness)!,
          Color.lerp(const Color(0xFF0B0E12), Colors.white,
              backgroundBrightness * 0.7)!,
        ],
        radius: 1.2,
        center: Alignment.topCenter,
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Sterne
    final paint = Paint()..isAntiAlias = true;
    for (final s in stars) {
      final phase = (t + s.twinklePhase) % 1.0;
      final brightness = 0.6 + 0.4 * sin(phase * 2 * pi);
      // set alpha according to brightness (preserve base color hue)
      paint.color = s.color.withAlpha((brightness * 255).round());
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter old) => old.t != t;
}

/// Hinweis: Das Starfield sollte als erstes Widget im Stack platziert werden, z.B.:
/// Stack(
///   children: [
///     Positioned.fill(child: Starfield()),
///     ...weitere Widgets...
///   ],
/// )

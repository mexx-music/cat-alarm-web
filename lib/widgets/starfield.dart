import 'package:flutter/material.dart';

class Starfield extends StatelessWidget {
  const Starfield({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy: schwarzer Hintergrund mit ein paar weißen Punkten
    return CustomPaint(
      painter: _StarfieldPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = UniqueKey().hashCode;
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < 40; i++) {
      final x = (size.width * (i * 37 % 100) / 100).clamp(0.0, size.width);
      final y = (size.height * (i * 53 % 100) / 100).clamp(0.0, size.height);
      canvas.drawCircle(Offset(x, y), 1.5 + (i % 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

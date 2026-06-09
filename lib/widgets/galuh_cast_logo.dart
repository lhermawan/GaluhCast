import 'package:flutter/material.dart';

class GaluhCastLogo extends StatelessWidget {
  const GaluhCastLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo GaluhCast',
      child: CustomPaint(
        size: Size.square(size),
        painter: const _GaluhCastLogoPainter(),
      ),
    );
  }
}

class _GaluhCastLogoPainter extends CustomPainter {
  const _GaluhCastLogoPainter();

  static const _teal = Color(0xFF18A999);
  static const _deep = Color(0xFF101416);
  static const _gold = Color(0xFFFFC857);
  static const _red = Color(0xFFE84A5F);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.width * 0.24;
    final badge = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_teal, Color(0xFF0E6F68), _deep],
        stops: [0, 0.56, 1],
      ).createShader(rect);
    canvas.drawRRect(badge, background);

    final highlight = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final highlightPath = Path()
      ..moveTo(size.width * 0.12, 0)
      ..lineTo(size.width * 0.72, 0)
      ..lineTo(size.width * 0.36, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(highlightPath, highlight);

    final cameraPaint = Paint()..color = Colors.white;
    final cameraBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.33,
        size.width * 0.44,
        size.height * 0.34,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(cameraBody, cameraPaint);

    final cameraNose = Path()
      ..moveTo(size.width * 0.66, size.height * 0.42)
      ..lineTo(size.width * 0.82, size.height * 0.34)
      ..lineTo(size.width * 0.82, size.height * 0.66)
      ..lineTo(size.width * 0.66, size.height * 0.58)
      ..close();
    canvas.drawPath(cameraNose, cameraPaint);

    final lensPaint = Paint()..color = _deep.withValues(alpha: 0.88);
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.50),
      size.width * 0.105,
      lensPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.50),
      size.width * 0.042,
      Paint()..color = _teal,
    );

    final liveDot = Paint()..color = _red;
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.39),
      size.width * 0.042,
      liveDot,
    );

    final wavePaint = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    final waveCenter = Offset(size.width * 0.50, size.height * 0.50);
    for (final scale in [0.72, 0.93]) {
      canvas.drawArc(
        Rect.fromCircle(center: waveCenter, radius: size.width * scale),
        -0.76,
        1.52,
        false,
        wavePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

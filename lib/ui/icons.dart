import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The preview draws its glyphs as inline SVG. Each one is a painter here, so
/// the stroke width, the round caps and the accent colour follow the same
/// rules the stylesheet set on the `<svg>` elements.
class GlyphPainter extends CustomPainter {
  const GlyphPainter({
    required this.kind,
    required this.color,
    this.strokeWidth = 1.8,
  });

  final String kind;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Rect rect = Offset.zero & size;

    switch (kind) {
      case 'aether':
        _aether(canvas, paint, size);
      case 'psiphon':
        _psiphon(canvas, paint, size);
      case 'tor':
        canvas.drawCircle(rect.center, size.width * 8 / 24, paint);
        canvas.drawCircle(rect.center, size.width * 4.5 / 24, paint);
        canvas.drawLine(
          Offset(rect.center.dx, size.height * 5 / 24),
          Offset(rect.center.dx, 0),
          paint,
        );
      case 'dns':
        _dns(canvas, paint, size);
      case 'power':
        canvas.drawLine(
          Offset(size.width / 2, size.height * 3 / 24),
          Offset(size.width / 2, size.height * 12 / 24),
          paint,
        );
        canvas.drawArc(
          rect.inflate(-size.width * 4 / 24),
          _deg(-55),
          _deg(290),
          false,
          paint,
        );
      case 'home':
        canvas.drawPath(_home(size), paint);
      case 'settings':
        canvas.drawCircle(rect.center, size.width * 4 / 24, paint);
        for (int i = 0; i < 8; i++) {
          final double angle = _deg(i * 45.0);
          canvas.drawLine(
            _onCircle(rect.center, size.width * 7 / 24, angle),
            _onCircle(rect.center, size.width * 10 / 24, angle),
            paint,
          );
        }
      case 'about':
      case 'rewards':
        final Path box = Path()
          ..moveTo(size.width * 4 / 24, size.height * 10 / 24)
          ..lineTo(size.width * 20 / 24, size.height * 10 / 24)
          ..lineTo(size.width * 18 / 24, size.height * 20 / 24)
          ..lineTo(size.width * 6 / 24, size.height * 20 / 24)
          ..close();
        canvas.drawPath(box, paint);
        canvas.drawLine(
          Offset(size.width * 4 / 24, size.height * 13 / 24),
          Offset(size.width * 20 / 24, size.height * 13 / 24),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 12 / 24, size.height * 10 / 24),
          Offset(size.width * 12 / 24, size.height * 20 / 24),
          paint,
        );
        canvas.drawCircle(rect.center, size.width * 9 / 24, paint);
        canvas.drawLine(
          Offset(rect.center.dx, size.height * 10.5 / 24),
          Offset(rect.center.dx, size.height * 16 / 24),
          paint,
        );
        canvas.drawCircle(
          Offset(rect.center.dx, size.height * 7.5 / 24),
          1.4,
          paint..style = PaintingStyle.fill,
        );
      case 'sun':
        canvas.drawCircle(rect.center, size.width * 4.2 / 24, paint);
        for (int i = 0; i < 8; i++) {
          final double angle = _deg(i * 45.0);
          canvas.drawLine(
            _onCircle(rect.center, size.width * 7 / 24, angle),
            _onCircle(rect.center, size.width * 9.5 / 24, angle),
            paint,
          );
        }
      case 'moon':
        final Path big = Path()..addOval(rect);
        final Path cut = Path()
          ..addOval(Rect.fromCircle(
            center: Offset(size.width * 0.66, size.height * 0.34),
            radius: size.width * 0.42,
          ));
        canvas.drawPath(
          Path.combine(PathOperation.difference, big, cut),
          paint..style = PaintingStyle.fill,
        );
      case 'reset':
        canvas.drawPath(_reset(size), paint);
      default:
        break;
    }
  }

  /// The preview's path in its own 1573x1370 space: a chevron, the "A" of
  /// Aether without its crossbar. The stylesheet says `fill:none` on the
  /// glyph, so it is stroked rather than filled with the `#000000` the inline
  /// path carried -- a black shape on a dark card would be invisible.
  void _aether(Canvas canvas, Paint paint, Size size) {
    final double sx = size.width / 1573;
    final double sy = size.height / 1370;
    final Path path = Path()
      ..moveTo(787 * sx, 0)
      ..lineTo(0, 1367 * sy)
      ..lineTo(244 * sx, 1367 * sy)
      ..lineTo(786 * sx, 661 * sy)
      ..lineTo(1328 * sx, 1367 * sy)
      ..lineTo(1572 * sx, 1367 * sy)
      ..close();
    canvas.drawPath(path, paint..strokeWidth = size.width * 0.09);
  }

  /// The DNS engine's glyph, drawn here rather than taken from WhiteDNS so
  /// the tile matches the other engine glyphs' stroke language: a globe with
  /// the tunnel's signal wave across its equator, and an antenna dot above it
  /// -- a query leaving the device.
  void _dns(Canvas canvas, Paint paint, Size size) {
    final Rect rect = Offset.zero & size;
    final Offset c = rect.center;
    final double r = size.width * 8.5 / 24;

    paint..style = PaintingStyle.stroke;

    // antenna: stem and tip
    canvas.drawLine(
      Offset(c.dx, c.dy - r),
      Offset(c.dx, size.height * 3 / 24),
      paint,
    );
    canvas.drawCircle(
      Offset(c.dx, size.height * 2.6 / 24),
      paint.strokeWidth * 0.85,
      paint..style = PaintingStyle.fill,
    );
    paint..style = PaintingStyle.stroke;

    // globe
    canvas.drawCircle(c, r, paint);

    // the lower rim, shortened so the wave reads as inside the globe
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      0.35,
      2.45,
      false,
      paint,
    );

    // the tunnel's sine wave across the equator
    final Path wave = Path()..moveTo(c.dx - r, c.dy);
    for (int i = 0; i < 4; i++) {
      final double x0 = c.dx - r + r * 2 * i / 4;
      final double x1 = c.dx - r + r * 2 * (i + 1) / 4;
      wave.quadraticBezierTo(
        (x0 + x1) / 2,
        c.dy + (i.isEven ? -0.55 : 0.55) * r * 0.5,
        x1,
        c.dy,
      );
    }
    canvas.drawPath(wave, paint);
  }

  void _psiphon(Canvas canvas, Paint paint, Size size) {
    final Path path = Path()
      ..moveTo(size.width * 5 / 24, size.height * 5 / 24)
      ..lineTo(size.width * 5 / 24, size.height * 10 / 24)
      ..arcToPoint(
        Offset(size.width * 19 / 24, size.height * 10 / 24),
        radius: Radius.circular(size.width * 7 / 24),
        clockwise: false,
      )
      ..lineTo(size.width * 19 / 24, size.height * 5 / 24)
      ..moveTo(size.width * 12 / 24, size.height * 3 / 24)
      ..lineTo(size.width * 12 / 24, size.height * 21 / 24)
      ..moveTo(size.width * 8 / 24, size.height * 21 / 24)
      ..lineTo(size.width * 16 / 24, size.height * 21 / 24);
    canvas.drawPath(path, paint);
  }

  Path _home(Size size) => Path()
    ..moveTo(size.width * 3 / 24, size.height * 10.5 / 24)
    ..lineTo(size.width * 12 / 24, size.height * 3 / 24)
    ..lineTo(size.width * 21 / 24, size.height * 10.5 / 24)
    ..moveTo(size.width * 5 / 24, size.height * 9.5 / 24)
    ..lineTo(size.width * 5 / 24, size.height * 21 / 24)
    ..lineTo(size.width * 19 / 24, size.height * 21 / 24)
    ..lineTo(size.width * 19 / 24, size.height * 9.5 / 24)
    ..moveTo(size.width * 9 / 24, size.height * 21 / 24)
    ..lineTo(size.width * 9 / 24, size.height * 15 / 24)
    ..lineTo(size.width * 15 / 24, size.height * 15 / 24)
    ..lineTo(size.width * 15 / 24, size.height * 21 / 24);

  Path _reset(Size size) => Path()
    ..addArc(
      rectOf(size).inflate(-size.width * 3 / 24),
      _deg(140),
      _deg(270),
    )
    ..moveTo(size.width * 3 / 24, size.height * 5 / 24)
    ..lineTo(size.width * 3 / 24, size.height * 11 / 24)
    ..lineTo(size.width * 9 / 24, size.height * 11 / 24);

  static Rect rectOf(Size size) => Offset.zero & size;

  static double _deg(double degrees) => degrees * math.pi / 180;

  static Offset _onCircle(Offset center, double radius, double angle) =>
      Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));

  @override
  bool shouldRepaint(GlyphPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Draw one of the preview's glyphs.
class Glyph extends StatelessWidget {
  const Glyph({
    super.key,
    required this.kind,
    required this.color,
    this.size = 20,
    this.strokeWidth = 1.8,
  });

  final String kind;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: GlyphPainter(
            kind: kind,
            color: color,
            strokeWidth: strokeWidth,
          ),
        ),
      );
}

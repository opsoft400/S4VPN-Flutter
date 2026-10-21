import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/s4_theme.dart';

/// The neon snow drifting behind everything, as the preview draws it.
///
/// One glowing sprite, stamped once per flake per frame, is what makes this
/// cheap enough to run under the rest of the UI: a radial gradient built once
/// per theme change rather than a shader per particle. The flake set is sized
/// from the area so a phone gets a light fall and a desktop does not get a
/// blizzard.
class SnowField extends StatefulWidget {
  const SnowField({super.key});

  @override
  State<SnowField> createState() => _SnowFieldState();
}

class _Flake {
  _Flake(this.x, this.y, this.radius, this.speed, this.sway, this.phase, this.frequency, this.opacity);

  double x;
  double y;
  double radius;
  double speed;
  double sway;
  double phase;
  double frequency;
  double opacity;
}

class _SnowPainter extends CustomPainter {
  _SnowPainter({
    required this.sprite,
    required this.flakes,
    required this.time,
  });

  final ui.Image sprite;
  final List<_Flake> flakes;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..filterQuality = FilterQuality.low;
    for (final _Flake flake in flakes) {
      final double x = flake.x + math.sin(time * flake.frequency + flake.phase) * flake.sway;
      final double r = flake.radius;
      paint.color = Color.fromRGBO(255, 255, 255, flake.opacity);
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromCenter(center: Offset(x, flake.y), width: r * 2, height: r * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SnowPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.flakes != flakes;
}

class _SnowFieldState extends State<SnowField> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _random = math.Random();
  ui.Image? _sprite;
  final List<_Flake> _flakes = <_Flake>[];
  Size _size = Size.zero;
  Duration _elapsed = Duration.zero;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _buildSprite(paletteOf(context));
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final double dt =
        ((elapsed - _elapsed).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _elapsed = elapsed;
    if (!_reduceMotion) {
      for (final _Flake flake in _flakes) {
        flake.y += flake.speed * dt;
        if (flake.y > _size.height + 12) {
          flake
            ..y = -4 - _random.nextDouble() * 26
            ..x = _random.nextDouble() * _size.width;
        }
      }
    }
    setState(() {});
  }

  void _buildSprite(S4Palette palette) {
    const int side = 64;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Rect rect = Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble());
    final RadialGradient gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.5,
      colors: <Color>[
        palette.snowCore,
        palette.snowCore.withValues(alpha: 0.95),
        palette.snowEdge.withValues(alpha: 0.35),
        palette.snowEdge.withValues(alpha: 0),
      ],
      stops: const <double>[0, 0.18, 0.45, 1],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    final ui.Image image = recorder.endRecording().toImageSync(side, side);
    if (_sprite != null) _sprite!.dispose();
    _sprite = image;
  }

  void _resize(Size size) {
    if (size == _size) return;
    _size = size;
    final int count = (math.min(90, math.max(40, size.width * size.height / 4200))).round();
    _flakes.clear();
    for (int i = 0; i < count; i++) {
      _flakes.add(_make(initial: true));
    }
  }

  _Flake _make({required bool initial}) {
    final double z = _random.nextDouble();
    return _Flake(
      _random.nextDouble() * math.max(1, _size.width),
      initial ? _random.nextDouble() * math.max(1, _size.height) : -_random.nextDouble() * 26 - 4,
      2.5 + z * 7,
      14 + z * 46,
      6 + _random.nextDouble() * 20,
      _random.nextDouble() * 6.28,
      0.4 + _random.nextDouble() * 0.7,
      0.35 + z * 0.6,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sprite?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        if (_sprite == null) _buildSprite(paletteOf(context));
        _resize(size);
        if (_reduceMotion || _sprite == null) return const SizedBox.shrink();
        return IgnorePointer(
          child: CustomPaint(
            size: size,
            painter: _SnowPainter(
              sprite: _sprite!,
              flakes: _flakes,
              time: _elapsed.inMicroseconds / 1e6,
            ),
          ),
        );
      },
    );
  }
}

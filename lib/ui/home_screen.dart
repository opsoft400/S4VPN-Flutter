import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/engine_mode.dart';
import '../engine/plan.dart';
import '../state/app_state.dart';
import '../theme/s4_theme.dart';
import 'app_scope.dart';
import 'icons.dart';

/// The home screen: the engine picker, the power button, the route, and the
/// numbers underneath.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final S4Palette palette = paletteOf(context);
    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _EnginePicker(palette: palette),
              const SizedBox(height: 6),
              SizedBox(height: 250, child: _Orb(palette: palette)),
              const SizedBox(height: 14),
              _Status(palette: palette),
              const SizedBox(height: 12),
              _BalanceLine(palette: palette),
              _Steps(palette: palette),
              const SizedBox(height: 12),
              _RouteStrip(palette: palette),
              const SizedBox(height: 14),
              _MadeBy(palette: palette),
              if (state.config.boolOf('stats')) ...<Widget>[
                const SizedBox(height: 10),
                _Readout(palette: palette),
              ],
              const SizedBox(height: 12),
              const _Proxies(),
            ],
          ),
        );
      },
    );
  }
}

class _EnginePicker extends StatelessWidget {
  const _EnginePicker({required this.palette});

  final S4Palette palette;

  static const List<String> _order = <String>['aether', 'psiphon', 'tor', 'white', 's4', 'dns'];

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String current = state.engine.id;
    final bool locked = state.state != ConnState.idle;
    return Row(
      children: <Widget>[
        for (final String id in _order)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _EngineButton(
                id: id,
                selected: id == current,
                dimmed: locked && id != current,
                palette: palette,
                onTap: () => state.setKey('engine', id),
              ),
            ),
          ),
      ],
    );
  }
}

class _EngineButton extends StatelessWidget {
  const _EngineButton({
    required this.id,
    required this.selected,
    required this.dimmed,
    required this.palette,
    required this.onTap,
  });

  final String id;
  final bool selected;
  final bool dimmed;
  final S4Palette palette;
  final VoidCallback onTap;

  static const Map<String, String> _labels = <String, String>{
    'aether': 'aether',
    'psiphon': 'Psiphon',
    'tor': 'Tor',
    'white': 'White',
    's4': 'S4',
    'dns': 'DNS',
    'white_aether': 'White Aether',
  };

  @override
  Widget build(BuildContext context) {
    final EngineMode mode = EngineMode.parse(id);
    final Color accent = palette.engineAccent(id);
    final Color content =
        selected ? (palette.dark ? Colors.white : palette.ink) : palette.mute;

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? accent : palette.line),
          color: selected ? palette.card : null,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: palette.dark ? 0.45 : 0.35),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 22,
                  child: Center(child: _glyph(accent, content, selected)),
                ),
                const SizedBox(height: 2),
                Text(
                  _labels[id]!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: content,
                    height: 1.15,
                  ),
                ),
                Text(
                  mode.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: content, height: 1.15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glyph(Color accent, Color content, bool selected) {
    if (id == 'white') {
      return _TileIcon(
        asset: 'assets/images/whitevpn_icon.png',
        accent: accent,
        selected: selected,
      );
    }
    if (id == 's4') {
      return _TileIcon(
        asset: 'assets/images/S4VPN.png',
        accent: accent,
        selected: selected,
      );
    }
    if (id == 'dns') {
      // An icon of this engine's own, following the stroke language of the
      // other glyphs; it is a tunnel through DNS, not a pulse through WARP.
      return SizedBox(
        width: 19,
        height: 19,
        child: CustomPaint(
          painter: GlyphPainter(
            kind: 'dns',
            color: selected ? accent : content,
            strokeWidth: selected ? 2.1 : 1.8,
          ),
        ),
      );
    }
    return Glyph(kind: id, color: selected ? accent : content, size: 19);
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({
    required this.asset,
    required this.accent,
    required this.selected,
  });

  final String asset;
  final Color accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: selected ? 1 : 0.4)),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 12),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
              const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The ring and the button in the middle of it.
///
/// Three states change what the ring does: idle draws the track alone,
/// connecting spins the dots fast and leaves the arc undone, connected spins
/// slowly and closes the arc. The arcs are the preview's `stroke-dasharray`
/// arithmetic, in Flutter's units.
class _Orb extends StatefulWidget {
  const _Orb({required this.palette});

  final S4Palette palette;

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _arc;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 26));
    _arc = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _spin.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply(AppScope.of(context));
  }

  @override
  void dispose() {
    _spin.dispose();
    _arc.dispose();
    super.dispose();
  }

  void _apply(AppState state) {
    final Duration duration = switch (state.state) {
      ConnState.idle => const Duration(seconds: 26),
      ConnState.connecting => const Duration(milliseconds: 2400),
      ConnState.connected => const Duration(seconds: 60),
    };
    // Changing the duration of a running controller is allowed; restarting it
    // on every rebuild is not, because the ring would snap back each time the
    // status line ticked. So: set the duration, and only start the ticker when
    // it is not already running.
    if (_spin.duration != duration) _spin.duration = duration;
    if (!_spin.isAnimating) _spin.repeat();

    if (state.state == ConnState.connected) {
      if (_arc.status == AnimationStatus.dismissed ||
          _arc.status == AnimationStatus.reverse) {
        _arc.forward();
      }
    } else if (_arc.status == AnimationStatus.completed ||
        _arc.status == AnimationStatus.forward) {
      _arc.reverse();
    }
  }
  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final S4Palette palette = widget.palette;
    _apply(state);

    final Color accent = switch (state.state) {
      ConnState.idle => palette.blue,
      ConnState.connecting => palette.amber,
      ConnState.connected => palette.neon,
    };

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_spin, _arc, state]),
      builder: (BuildContext context, Widget? _) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            SizedBox(
              width: 250,
              height: 250,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (BuildContext context, Widget? child) =>
                    Transform.rotate(angle: _spin.value * 6.283185, child: child),
                child: CustomPaint(
                  painter: _RingPainter(
                    track: palette.line,
                    dots: accent,
                    arc: palette.neon,
                    arcProgress: _arc.value,
                    arcVisible: state.state == ConnState.connected,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: state.busy ? null : state.togglePower,
              child: Container(
                width: 162,
                height: 162,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 1,
                    colors: <Color>[palette.powerFrom, palette.powerTo],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.8)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: state.state == ConnState.connected ? 0.65 : 0.35),
                      blurRadius: state.state == ConnState.connected ? 50 : 30,
                    ),
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 22,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Glyph(kind: 'power', color: accent, size: 44, strokeWidth: 2.4),
                    const SizedBox(height: 6),
                    Text(
                      state.tr(
                        switch (state.state) {
                          ConnState.idle => 'اتصال',
                          ConnState.connecting => 'لغو',
                          ConnState.connected => 'قطع',
                        },
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.track,
    required this.dots,
    required this.arc,
    required this.arcProgress,
    required this.arcVisible,
  });

  final Color track;
  final Color dots;
  final Color arc;
  final double arcProgress;
  final bool arcVisible;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double scale = size.width / 250;

    canvas.drawCircle(
      center,
      110 * scale,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    const List<List<double>> positions = <List<double>>[
      <double>[125, 15, 5],
      <double>[235, 125, 3.5],
      <double>[125, 235, 4.5],
      <double>[15, 125, 3],
      <double>[203, 47, 2.5],
      <double>[47, 203, 2.5],
    ];
    final Paint dotPaint = Paint()..color = dots;
    for (final List<double> p in positions) {
      canvas.drawCircle(
        Offset(p[0] * scale, p[1] * scale),
        p[2] * scale,
        dotPaint,
      );
    }

    if (!arcVisible) return;
    final Rect ring = Rect.fromCircle(center: center, radius: 102 * scale);
    canvas.drawArc(
      ring,
      -1.5707963,
      6.2831853 * arcProgress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = arc
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.arcProgress != arcProgress ||
      oldDelegate.arcVisible != arcVisible ||
      oldDelegate.dots != dots ||
      oldDelegate.track != track;
}

class _Status extends StatelessWidget {
  const _Status({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Column(
      children: <Widget>[
        Text(
          state.statusTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.2),
        ),
        const SizedBox(height: 2),
        Text(
          state.statusSub,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: palette.mute, height: 1.4),
        ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    if (state.state != ConnState.connecting) return const SizedBox(height: 4);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(4, (int index) {
        final bool done = index < state.doneSteps;
        return Container(
          width: 50,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: done ? palette.amber : palette.line,
            boxShadow: done
                ? <BoxShadow>[BoxShadow(color: palette.amber.withValues(alpha: 0.8), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }
}

class _RouteStrip extends StatelessWidget {
  const _RouteStrip({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<String> nodes = routeNodesFor(state.config);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (int i = 0; i < nodes.length; i++) ...<Widget>[
          if (i > 0)
            Text(
              '←',
              style: TextStyle(fontSize: 12, color: palette.blue),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: palette.line),
              color: palette.card,
            ),
            child: Text(
              i == 0 || i == nodes.length - 1 ? state.tr(nodes[i]) : nodes[i],
              style: TextStyle(fontSize: 12, color: palette.ink),
            ),
          ),
        ],
      ],
    );
  }
}

class _MadeBy extends StatelessWidget {
  const _MadeBy({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.9,
          color: palette.madeInk,
          shadows: palette.madeGlow.a == 0
              ? null
              : <Shadow>[Shadow(color: palette.madeGlow, blurRadius: 10)],
        ),
        children: <InlineSpan>[
          TextSpan(text: '${state.tr('ساخته شده با')} '),
          const TextSpan(
            text: '❤',
            style: TextStyle(color: Color(0xFFFF1B4D), fontSize: 13),
          ),
          TextSpan(text: ' ${state.tr('توسط')} '),
          const TextSpan(
            text: 'سافت۴۰۰',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.palette});

  final S4Palette palette;


  /// The rule between the readout columns. Flutter's directional border
  /// type is not what a decoration takes, so the side is resolved against
  /// the ambient direction instead.
  Border _divider(BuildContext context) {
    final BorderSide side = BorderSide(color: palette.line);
    return Directionality.of(context) == TextDirection.ltr
        ? Border(left: side)
        : Border(right: side);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<String> values = <String>[
      state.pingMs == null ? '—' : state.fa(state.pingMs),
      state.downRate ?? '—',
      state.upRate ?? '—',
    ];
    final List<String> labels = <String>[
      state.chrome('latency'),
      state.chrome('download'),
      state.chrome('upload'),
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        color: palette.card,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: List<Widget>.generate(3, (int index) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                decoration: index == 0
                    ? null
                    : BoxDecoration(
                        border: _divider(context),
                      ),
                child: Column(
                  children: <Widget>[
                    Text(
                      values[index],
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: palette.readoutAccents[index],
                      ),
                    ),
                    Text(
                      labels[index],
                      style: TextStyle(fontSize: 12, color: palette.mute),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Proxies extends StatelessWidget {
  const _Proxies();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final S4Palette palette = paletteOf(context);
    final List<List<String>> rows = _rows(state);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      children: <Widget>[
        for (final List<String> row in rows)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.line),
              color: palette.card,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    row[0],
                    style: TextStyle(fontSize: 13, color: palette.mute),
                  ),
                ),
                Text(
                  row[1],
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: kMonoFont,
                    fontSize: 13,
                    color: palette.ink,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: row[1]));
                    state.showToast(state.tr('آدرس کپی شد'));
                  },
                  child: Text(
                    state.tr('کپی'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.neon,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<List<String>> _rows(AppState state) {
    final Map<String, Object?> config = state.config.values;
    final String bind = (config['bind'] ?? '').toString();
    final String httpAddr = (config['httpAddr'] ?? '').toString();
    final bool httpOn = config['httpOn'] == true;
    final String engine = state.engine.id;
    final List<List<String>> rows = <List<String>>[];
    if (engine == 'white') {
      rows.add(<String>[state.tr('SOCKS5 · وایت'), bind]);
      if (httpOn) rows.add(<String>[state.tr('HTTP · وایت'), httpAddr]);
      if (config['whShare'] == true) {
        rows.add(<String>[state.tr('شبکه محلی'), '192.168.1.10:1822']);
      }
      return rows;
    }
    if (engine == 'dns') {
      final String ip = (config['dnsListenIp'] ?? '127.0.0.1').toString();
      final String port = (config['dnsListenPort'] ?? '10886').toString();
      final String httpPort = (config['dnsHttpPort'] ?? '10887').toString();
      rows.add(<String>['SOCKS5 · DNS', '$ip:$port']);
      if (config['dnsHttpEnabled'] == true) {
        rows.add(<String>['HTTP · DNS', '$ip:$httpPort']);
      }
      if (config['dnsLocalDns'] == true) {
        rows.add(<String>[
          state.tr('DNS محلی'),
          '${ip}:${config['dnsLocalDnsPort'] ?? '53'}',
        ]);
      }
      return rows;
    }

    if (engine == 'aether') {
      rows.add(<String>['SOCKS5', bind]);
    } else {
      final String way =
          engine == 'psiphon' ? (config['psWay'] ?? '').toString() : (config['torWay'] ?? '').toString();
      final String name =
          engine == 'psiphon' ? 'Psiphon' : engine == 's4' ? 'S4VPN' : 'Tor';
      if (way == 'only' || way.isEmpty) {
        rows.add(<String>['SOCKS5 · $name', bind]);
      } else {
        rows.add(<String>[state.tr('SOCKS5 · خروجی WARP'), bind]);
        rows.add(<String>[
          'SOCKS5 · خروجی $name',
          engine == 'psiphon' ? (config['psBind'] ?? '').toString() : (config['torBind'] ?? '').toString(),
        ]);
      }
    }
    if (httpOn) rows.add(<String>['HTTP · WARP', httpAddr]);
    return rows;
  }
}

/// The balance, and where to get more of it.
///
/// The line is only there when the balance cannot pay for a connection: that is
/// the one moment the user needs to know, and it is also the moment the
/// rewards tab is worth opening.
class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    if (state.isAdFree) {
      return Center(
        child: Text(
          state.tr('اتصال بدون محدودیت'),
          style: TextStyle(fontSize: 12, color: palette.teal),
        ),
      );
    }
    if (state.canConnect) {
      return Center(
        child: Text(
          '${state.tr('اتصال‌های باقی‌مانده')}: ${state.fa(state.credits)}',
          style: TextStyle(fontSize: 12, color: palette.mute),
        ),
      );
    }
    return Material(
      color: palette.amber.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => state.setTab(AppTab.rewards),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.play_circle_outline, size: 16, color: palette.amber),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  state.tr('برای اتصال یک تبلیغ ببین'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: palette.amber,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

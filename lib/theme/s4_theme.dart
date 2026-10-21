import 'package:flutter/material.dart';

/// The two palettes, token for token with the preview.
///
/// Dark is the default and White is the second mode the header toggle switches
/// to; both come from the same `:root` block in the preview, so a colour here
/// is a colour there. Nothing is invented -- if a value looks arbitrary, look
/// it up in `S4VPN-UI.html`.
class S4Palette {
  const S4Palette({
    required this.dark,
    required this.bg,
    required this.bg2,
    required this.card,
    required this.line,
    required this.ink,
    required this.mute,
    required this.blue,
    required this.teal,
    required this.neon,
    required this.purple,
    required this.red,
    required this.amber,
    required this.pageTop,
    required this.pageBottom,
    required this.bezel,
    required this.bezelRing,
    required this.bezelGlow,
    required this.logoBackground,
    required this.powerFrom,
    required this.powerTo,
    required this.segFrom,
    required this.segTo,
    required this.segInk,
    required this.fieldBackground,
    required this.switchOff,
    required this.toastBackground,
    required this.toastInk,
    required this.navBackground,
    required this.navSelectedInk,
    required this.warnBorder,
    required this.warnBackground,
    required this.warnInk,
    required this.madeInk,
    required this.madeGlow,
    required this.heartGlow,
    required this.engineAccents,
    required this.snowCore,
    required this.snowEdge,
    required this.readoutAccents,
    required this.selectedRowBorder,
    required this.selectedRowFill,
  });

  final bool dark;
  final Color bg;
  final Color bg2;
  final Color card;
  final Color line;
  final Color ink;
  final Color mute;
  final Color blue;
  final Color teal;
  final Color neon;
  final Color purple;
  final Color red;
  final Color amber;
  final Color pageTop;
  final Color pageBottom;
  final Color bezel;
  final Color bezelRing;
  final Color bezelGlow;
  final Color logoBackground;
  final Color powerFrom;
  final Color powerTo;
  final Color segFrom;
  final Color segTo;
  final Color segInk;
  final Color fieldBackground;
  final Color switchOff;
  final Color toastBackground;
  final Color toastInk;
  final Color navBackground;
  final Color navSelectedInk;
  final Color warnBorder;
  final Color warnBackground;
  final Color warnInk;
  final Color madeInk;
  final Color madeGlow;
  final Color heartGlow;

  /// Accent per engine id: aether, psiphon, tor, white, s4.
  final Map<String, Color> engineAccents;
  final Color snowCore;
  final Color snowEdge;
  final List<Color> readoutAccents;
  final Color selectedRowBorder;
  final Color selectedRowFill;

  Color engineAccent(String engine) =>
      engineAccents[engine] ?? engineAccents['aether']!;

  static S4Palette of(BuildContext context, {required bool white}) =>
      white ? whiteMode : darkMode;
}


/// A translucent wash of [rgb] at [alpha] (0..1).
Color alpha(int rgb, double alpha) =>
    Color.fromARGB((alpha * 255).round(), (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);

/// `:root` -- the dark palette.
const S4Palette darkMode = S4Palette(
  dark: true,
  bg: Color(0xFF050B1C),
  bg2: Color(0xFF08122B),
  card: Color(0x0AFFFFFF), // rgba(255,255,255,.04)
  line: Color(0x336E96FF), // rgba(110,150,255,.20)
  ink: Color(0xFFEAF1FF),
  mute: Color(0xFF8FA0C8),
  blue: Color(0xFF2F8CFF),
  teal: Color(0xFF2EE6C1),
  neon: Color(0xFF18B4FF),
  purple: Color(0xFF9B6BFF),
  red: Color(0xFFFF6B6B),
  amber: Color(0xFFFFB84D),
  pageTop: Color(0xFF02060F),
  pageBottom: Color(0xFF02060F),
  bezel: Color(0xFF0B1226),
  bezelRing: Color(0x406E96FF),
  bezelGlow: Color(0x2E2F8CFF),
  logoBackground: Color(0xFF0B1226),
  powerFrom: Color(0xFF12244F),
  powerTo: Color(0xFF091330),
  segFrom: Color(0xFF1F6FE0),
  segTo: Color(0xFF2F8CFF),
  segInk: Color(0xFFFFFFFF),
  fieldBackground: Color(0x0DFFFFFF),
  switchOff: Color(0x24FFFFFF),
  toastBackground: Color(0xFF0F1B3D),
  toastInk: Color(0xFFFFFFFF),
  navBackground: Color(0xD9050B1C),
  navSelectedInk: Color(0xFFFFFFFF),
  warnBorder: Color(0x66FFB84D),
  warnBackground: Color(0x14FFB84D),
  warnInk: Color(0xFFFFD08A),
  madeInk: Color(0xFF18B4FF),
  madeGlow: Color(0x8C18B4FF),
  heartGlow: Color(0xE6FF1B4D),
  engineAccents: <String, Color>{
    'aether': Color(0xFF18B4FF),
    'psiphon': Color(0xFF9B6BFF),
    'tor': Color(0xFFFF6FC8),
    'white': Color(0xFFF2F5F8),
    's4': Color(0xFF2FA8FF),
    'dns': Color(0xFF2EE6C1),
  },
  snowCore: Color(0xFFFFFFFF),
  snowEdge: Color(0xFF18B4FF),
  readoutAccents: <Color>[Color(0xFF18B4FF), Color(0xFF2F8CFF), Color(0xFF9B6BFF)],
  selectedRowBorder: Color(0xFF2EE6C1),
  selectedRowFill: Color(0x1A2EE6C1),
);

/// `html[data-theme="white"]` -- WhiteVPN's exported tokens.
const S4Palette whiteMode = S4Palette(
  dark: false,
  bg: Color(0xFFF1F9F5),
  bg2: Color(0xFFECF6F1),
  card: Color(0xC7FFFFFF), // rgba(255,255,255,.78)
  line: Color(0xFFB9C8C1),
  ink: Color(0xFF0A1410),
  mute: Color(0xFF495650),
  blue: Color(0xFF007E50),
  teal: Color(0xFF00A36B),
  neon: Color(0xFF007E50),
  purple: Color(0xFF6D4AE0),
  red: Color(0xFFCF4040),
  amber: Color(0xFFD08B00),
  pageTop: Color(0xFFF8FDFB),
  pageBottom: Color(0xFFECF6F1),
  bezel: Color(0xFFE0EDE7),
  bezelRing: Color(0x47007E50),
  bezelGlow: Color(0x29007E50),
  logoBackground: Color(0xFFE0EDE7),
  powerFrom: Color(0xFFFFFFFF),
  powerTo: Color(0xFFE9F5EF),
  segFrom: Color(0xFF007E50),
  segTo: Color(0xFF4BAE87),
  segInk: Color(0xFFF4FAF7),
  fieldBackground: Color(0xFFFFFFFF),
  switchOff: Color(0x2E0A1410),
  toastBackground: Color(0xFF0A1410),
  toastInk: Color(0xFFF1F9F5),
  navBackground: Color(0xEBF1F9F5),
  navSelectedInk: Color(0xFF0A1410),
  warnBorder: Color(0x73D08B00),
  warnBackground: Color(0x1AD08B00),
  warnInk: Color(0xFF7A4E00),
  madeInk: Color(0xFF0A5CD0),
  madeGlow: Color(0x00000000),
  heartGlow: Color(0xBFFFBF4D),
  engineAccents: <String, Color>{
    'aether': Color(0xFF00A36B),
    'psiphon': Color(0xFF6D4AE0),
    'tor': Color(0xFFE5207A),
    'white': Color(0xFF007E50),
    's4': Color(0xFF0A6CC4),
    'dns': Color(0xFF0B7285),
  },
  snowCore: Color(0xFFFFFFFF),
  snowEdge: Color(0xFF00A36B),
  readoutAccents: <Color>[Color(0xFF007E50), Color(0xFF1F6FE0), Color(0xFF6D4AE0)],
  selectedRowBorder: Color(0xFF007E50),
  selectedRowFill: Color(0x1A007E50),
);

/// Build the app's [ThemeData] around a palette.
///
/// Widgets read the palette through [paletteOf] rather than through
/// `Theme.of`, because the preview's layout decisions are tied to these
/// tokens, not to Material's.
ThemeData buildTheme(S4Palette palette) {
  return ThemeData(
    useMaterial3: true,
    brightness: palette.dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: palette.dark ? palette.pageTop : palette.pageTop,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.blue,
      brightness: palette.dark ? Brightness.dark : Brightness.light,
      primary: palette.blue,
      secondary: palette.neon,
      surface: palette.bg,
      error: palette.red,
    ),
    fontFamily: 'Vazirmatn',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: palette.card,
    dividerColor: palette.line,
    textTheme: ThemeData(brightness: palette.dark ? Brightness.dark : Brightness.light)
        .textTheme
        .apply(bodyColor: palette.ink, displayColor: palette.ink, fontFamily: 'Vazirmatn'),
  );
}

/// The palette in scope for the current theme.
S4Palette paletteOf(BuildContext context) {
  final Object? flag = context.dependOnInheritedWidgetOfExactType<_S4PaletteScope>();
  if (flag is _S4PaletteScope) return flag.palette;
  return darkMode;
}

class _S4PaletteScope extends InheritedWidget {
  const _S4PaletteScope({required this.palette, required super.child});

  final S4Palette palette;

  @override
  bool updateShouldNotify(_S4PaletteScope oldWidget) => palette != oldWidget.palette;
}

/// Provide the palette to everything below it.
class S4Scope extends StatelessWidget {
  const S4Scope({super.key, required this.palette, required this.child});

  final S4Palette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => _S4PaletteScope(palette: palette, child: child);
}

/// The preview's monospace face, for addresses and flags.
const String kMonoFont = 'PlexMono';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/translator.dart';
import 'state/app_state.dart';
import 'theme/s4_theme.dart';
import 'ui/about_screen.dart';
import 'ui/app_scope.dart';
import 'ui/home_screen.dart';
import 'ui/icons.dart';
import 'ui/rewards_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/snow.dart';

/// The application: the tabs behind a header, a nav bar, and a toast.
///
/// On a phone the app fills the screen. On a desktop window wider than the
/// preview's it draws the same 390x800 frame the mockup sits in, so what is
/// built can be compared against what was asked for without a second design.
class S4VpnApp extends StatefulWidget {
  const S4VpnApp({super.key, required this.state});

  final AppState state;

  @override
  State<S4VpnApp> createState() => _S4VpnAppState();
}

class _S4VpnAppState extends State<S4VpnApp> {
  @override
  void initState() {
    super.initState();
    widget.state.load();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = widget.state;
    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        final S4Palette palette = state.whiteTheme ? whiteMode : darkMode;
        return MaterialApp(
          title: 'S4VPN',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(palette),
          locale: Locale(state.language),
          supportedLocales: <Locale>[
            for (final String code in kSupportedLanguages) Locale(code),
          ],
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (BuildContext context, Widget? child) {
            return S4Scope(
              palette: palette,
              child: AppScope(
                state: state,
                child: Directionality(
                  textDirection:
                      state.isRtl ? TextDirection.rtl : TextDirection.ltr,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          home: _Shell(palette: palette),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final bool framed = media.size.width > 430;

    final Widget content = Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[palette.pageTop, palette.pageBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _Header(palette: palette),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    const Positioned.fill(child: SnowField()),
                    Positioned.fill(child: _Tabs(palette: palette)),
                  ],
                ),
              ),
              _NavBar(palette: palette),
            ],
          ),
        ),
      ),
    );

    if (!framed) {
      return Stack(
        children: <Widget>[
          content,
          if (state.toast != null)
            _Toast(palette: palette, message: state.toast!),
        ],
      );
    }

    final double height = math.min(800, media.size.height * 0.96);
    return Container(
      color: palette.dark ? const Color(0xFF02060F) : const Color(0xFFF8FDFB),
      alignment: Alignment.center,
      child: Container(
        width: 390,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(44),
          boxShadow: <BoxShadow>[
            BoxShadow(color: palette.bezel, spreadRadius: 10),
            BoxShadow(color: palette.bezelRing, spreadRadius: 11),
            BoxShadow(
              color: palette.bezelGlow,
              blurRadius: 80,
              offset: const Offset(0, 30),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(44),
          child: Stack(
            children: <Widget>[
              content,
              if (state.toast != null)
                _Toast(palette: palette, message: state.toast!),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tab strip, and the screens behind it.
///
/// The rewards tab is not always there: it is out of the navigation while a
/// code is running, and out of it while the tunnel is up. Nothing says why --
/// the tab simply is not in the list, which is the only wording the user
/// never has to read.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<AppTab> tabs = _visibleTabs(state);
    final int index = tabs.indexOf(state.tab);
    final List<Widget> screens = <Widget>[
      const HomeScreen(),
      if (state.showAdsTab) const RewardsScreen(),
      const SettingsScreen(),
      const AboutScreen(),
    ];
    return IndexedStack(
      index: index < 0 ? 0 : index,
      children: screens,
    );
  }
}

/// The tabs that are in the navigation right now.
List<AppTab> _visibleTabs(AppState state) => <AppTab>[
      AppTab.home,
      if (state.showAdsTab) AppTab.rewards,
      AppTab.settings,
      AppTab.about,
    ];

/// The icon and the label of each tab, in the same order as [_visibleTabs].
const List<String> _tabIcons = <String>['home', 'rewards', 'settings', 'about'];
const List<String> _tabLabels = <String>['home', 'rewards', 'settings', 'about'];

class _Header extends StatelessWidget {
  const _Header({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String statusText = switch (state.state) {
      ConnState.idle => state.tr('قطع'),
      ConnState.connecting => state.tr('در حال اتصال'),
      ConnState.connected => state.tr('متصل'),
    };
    final Color dotColor = switch (state.state) {
      ConnState.idle => palette.mute,
      ConnState.connecting => palette.amber,
      ConnState.connected => palette.neon,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: palette.logoBackground,
              boxShadow: <BoxShadow>[
                BoxShadow(
                    color: palette.blue.withValues(alpha: 0.4), blurRadius: 10),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/S4VPN.png',
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                  const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'S4VPN',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'Powered by SOFT400',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 11, color: palette.mute),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: palette.line),
              color: palette.card,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: state.state == ConnState.connected
                        ? <BoxShadow>[
                            BoxShadow(color: palette.neon, blurRadius: 10),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  statusText,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ThemeToggle(palette: palette),
        ],
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: state.toggleTheme,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.line),
          color: palette.card,
        ),
        child: Icon(
          state.whiteTheme
              ? Icons.dark_mode_outlined
              : Icons.light_mode_outlined,
          size: 17,
          color: palette.ink,
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<AppTab> tabs = _visibleTabs(state);
    return Container(
      decoration: BoxDecoration(
        color: palette.navBackground,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: _NavItem(
                icon: _tabIcons[i],
                label: state.chrome(_tabLabels[i]),
                selected: state.tab == tabs[i],
                palette: palette,
                onTap: () => state.setTab(tabs[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final S4Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? palette.navSelectedInk : palette.mute;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Glyph(
              kind: icon,
              color: selected ? palette.blue : color,
              size: 24,
              strokeWidth: 1.8,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.palette, required this.message});

  final S4Palette palette;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 92,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: palette.toastBackground,
              border: Border.all(color: palette.line),
            ),
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: palette.toastInk),
            ),
          ),
        ),
      ),
    );
  }
}

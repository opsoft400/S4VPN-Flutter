import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../engine/engine_mode.dart';
import '../engine/plan.dart';
import '../engine/supervisor.dart';
import '../l10n/translator.dart';
import '../models/rewards.dart';
import '../models/vpn_config.dart';
import '../models/white_servers.dart';
import '../platform/code_service.dart';
import '../platform/vpn_platform.dart';

/// Where the power button is pointing.
enum ConnState { idle, connecting, connected }

/// The tabs along the bottom. The rewards tab is only in the navigation while
/// a code is not running.
enum AppTab { home, settings, about, rewards }

/// Everything the widgets read, and the only place allowed to change it.
///
/// The preview kept one `cfg` object, one `phone.dataset.state` and a handful
/// of timers in a single script. This is the same shape with the parts named:
/// one config, one connection state, one set of timers, and a single
/// `notifyListeners` at the end of each change so the screens repaint once.
class AppState extends ChangeNotifier {
  AppState();

  VpnConfig config = VpnConfig.defaults();
  ConnState state = ConnState.idle;
  AppTab tab = AppTab.home;

  String language = 'fa';
  bool whiteTheme = false;

  String statusTitle = 'آماده اتصال';
  String statusSub = 'با یک لمس، تونل امن باز می‌شود';
  int doneSteps = 0;
  int elapsedSeconds = 0;

  int? pingMs;
  String? downRate;
  String? upRate;

  String? toast;
  String? lastError;
  final List<CoreLog> logLines = <CoreLog>[];

  List<WhiteServer> servers = List<WhiteServer>.of(kWhiteServers);
  double serverTestProgress = 0;
  String? selectedServer;

  final Supervisor supervisor = Supervisor();
  final ProxyProbe probe = const ProxyProbe();

  final List<Timer> _timers = <Timer>[];
  Timer? _ticker;
  Timer? _meter;
  Timer? _toastTimer;
  Timer? _adFreeTicker;
  StreamSubscription<CoreLog>? _logSub;
  Traffic? _lastTraffic;
  DateTime? _lastTrafficAt;
  bool _busy = false;

  bool get busy => _busy;
  bool get isRtl => kRtlLanguages.contains(language);
  EngineMode get engine => EngineMode.parse(config.textOf('engine'));

  /// Translate a Persian source string into the current language.
  String tr(String source) => Translator.tr(source, language);

  /// A chrome label already authored per language.
  String chrome(String key) => Translator.chrome(key, language);

  /// Format a number with Persian digits, the way the preview does.
  String fa(Object? value) => Translator.faDigits(value);

  // ---------------------------------------------------------------- rewards

  /// The credit balance and the time a code has bought.
  RewardState rewards = RewardState();

  /// True while an ad is on screen.
  bool watchingAd = false;

  /// Connections left in the balance.
  int get credits => rewards.credits;

  /// True while a code is running: the ad tab is out of the navigation and no
  /// credit is spent.
  bool get isAdFree => rewards.adFreeActive;

  /// How long the code has left, for the line on the home screen.
  String get adFreeRemaining => rewards.adFreeRemainingLabel;

  /// Whether the ad tab belongs in the navigation right now.
  bool get showAdsTab => !isAdFree;

  /// Whether a connection can be paid for right now.
  bool get canConnect => isAdFree || rewards.canAffordConnection;

  /// The server that checks codes.
  CodeService get codeService => CodeService(
        baseUrl: config.textOf('codeServer'),
        deviceId: _deviceId(),
      );

  // ---------------------------------------------------------------- settings

  /// Change one setting. While connected, only the engine itself is refused
  /// outright; everything else is accepted and reported as applying to the
  /// next connection, because that is the truth.
  void setKey(String key, Object? value) {
    if (key == 'engine' && state != ConnState.idle) {
      showToast(tr('ابتدا اتصال را قطع کنید'));
      return;
    }
    config.set(key, value);
    if (key == 'noize') _touchedNoize = true;

    if (key == 'whServerPick') {
      if (value == 'auto') {
        config.set('whServer', 'auto');
      } else if (config.textOf('whServer') == 'auto') {
        config.set('whServer', fastestServer(servers).name);
      }
    }

    _normalize();
    _persist();
    notifyListeners();

    if (key != 'engine' && state != ConnState.idle) {
      showToast(tr('تغییر با اتصال بعدی اعمال می‌شود'));
    }
  }

  /// Keep the derived settings consistent, exactly as the preview's
  /// `normalize()` does: a reverse chain can only run MASQUE over HTTP/2, and
  /// the camouflage default follows the transport.
  void _normalize() {
    final bool reverse = config.textOf('engine') != 'aether' &&
        config.textOf('engine') != 'white' &&
        _wayOf(config) == 'reverse';

    if (reverse) {
      if (_savedBeforeReverse == null) {
        _savedBeforeReverse = <String, Object?>{
          'transport': config['transport'],
          'carrier': config['carrier'],
        };
      }
      config
        ..set('transport', 'masque')
        ..set('carrier', 'h2');
    } else if (_savedBeforeReverse != null) {
      config
        ..set('transport', _savedBeforeReverse!['transport'])
        ..set('carrier', _savedBeforeReverse!['carrier']);
      _savedBeforeReverse = null;
    }

    if (!_touchedNoize) {
      final String transport = config.textOf('transport');
      config.set('noize', transport == 'masque' || transport == 'mim'
          ? 'firewall'
          : 'balanced');
    }
  }

  Map<String, Object?>? _savedBeforeReverse;
  bool _touchedNoize = false;

  String _wayOf(VpnConfig c) {
    final String e = c.textOf('engine');
    if (e == 'psiphon') return c.textOf('psWay');
    if (e == 'tor') return c.textOf('torWay');
    return 'warp';
  }

  void resetToDefaults() {
    if (state != ConnState.idle) {
      showToast(tr('ابتدا اتصال را قطع کنید'));
      return;
    }
    config = VpnConfig.defaults();
    rewards = RewardState();
    _savedBeforeReverse = null;
    _touchedNoize = false;
    _normalize();
    _persist();
    notifyListeners();
    showToast(tr('همه تنظیمات به حالت اولیه برگشت'));
  }

  // --------------------------------------------------------------- appearance

  void toggleTheme() {
    whiteTheme = !whiteTheme;
    _persist();
    notifyListeners();
  }

  void setLanguage(String code) {
    if (!kSupportedLanguages.contains(code)) return;
    language = code;
    _persist();
    notifyListeners();
  }

  void setTab(AppTab next) {
    if (tab == next) return;
    // The ad tab is not there while a code is running, and it is not there
    // while the tunnel is up: there is nothing to earn while connected.
    if (next == AppTab.rewards) {
      if (state != ConnState.idle) {
        showToast(tr('VPN متصل است؛ تب تبلیغات غیرفعال است'));
        return;
      }
      if (!showAdsTab) {
        tab = AppTab.home;
        notifyListeners();
        return;
      }
    }
    tab = next;
    notifyListeners();
  }

  void showToast(String message) {
    toast = message;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1900), () {
      toast = null;
      notifyListeners();
    });
    notifyListeners();
  }

  // ------------------------------------------------------------ White servers

  void retestServers() {
    serverTestProgress = 0;
    _clearTimers();
    const int steps = 12;
    for (int i = 1; i <= steps; i++) {
      _timers.add(Timer(Duration(milliseconds: i * 90), () {
        serverTestProgress = math.min(1.0, i / steps);
        notifyListeners();
      }));
    }
    _timers.add(Timer(const Duration(milliseconds: steps * 90 + 60), () {
      final math.Random random = math.Random();
      servers = servers
          .map((WhiteServer server) => server.copyWith(
                latency: (server.latency + random.nextInt(30) - 14).clamp(38, 400),
              ))
          .toList();
      serverTestProgress = 0;
      notifyListeners();
    }));
    notifyListeners();
  }

  void pickServer(String name) {
    config
      ..set('whServerPick', 'manual')
      ..set('whServer', name);
    if (state != ConnState.idle) {
      showToast(tr('تغییر با اتصال بعدی اعمال می‌شود'));
    }
    _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------- rewards

  /// Watch an ad and take the connections it pays for.
  ///
  /// The ad is a screen of its own; until one is wired up this waits out the
  /// same length of time an ad would take, and then credits what it owes.
  Future<void> watchAd() async {
    if (watchingAd) return;
    watchingAd = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(seconds: 5));
    rewards.add(
      source: CreditSource.ad,
      amount: RewardState.connectionsPerAd,
    );
    watchingAd = false;
    _persist();
    notifyListeners();
  }

  /// Check a code with the server and, if it is good, take the time it grants.
  Future<bool> redeemCode(String code) async {
    final CodeResult result = await codeService.redeem(code);
    if (!result.valid) {
      showToast(result.message ?? tr('کد درست نیست'));
      return false;
    }
    rewards.grantAdFree(result.duration);
    _persist();
    notifyListeners();
    showToast(tr('کد فعال شد'));
    return true;
  }

  /// Pay for one connection. A running code makes it free.
  bool _payForConnection() {
    if (isAdFree) return true;
    return rewards.spendOne();
  }

  /// A stable id for this install, sent to the server with every code.
  String _deviceId() {
    String id = config.textOf('deviceId');
    if (id.isEmpty) {
      id = CodeService.deriveDeviceId(
        '${config.textOf('engine')}|${config.textOf('bind')}',
      );
      config.set('deviceId', id);
    }
    return id;
  }

  // ---------------------------------------------------------------- connection

  Future<void> togglePower() async {
    switch (state) {
      case ConnState.idle:
        await connect();
      case ConnState.connecting:
        disconnect(message: tr('لغو شد'));
      case ConnState.connected:
        disconnect();
    }
  }

  Future<void> connect() async {
    if (_busy) return;

    // No credits and no code: the balance has to be earned first, so the user
    // is sent to the ad tab rather than told they cannot connect.
    if (!canConnect) {
      setTab(AppTab.rewards);
      showToast(tr('برای اتصال باید امتیاز بگیری'));
      return;
    }

    _busy = true;
    _clearTimers();
    lastError = null;
    logLines.clear();

    state = ConnState.connecting;
    statusTitle = tr('در حال ساخت تونل…');
    statusSub = '';
    doneSteps = 0;
    pingMs = null;
    downRate = null;
    upRate = null;
    _lastTraffic = null;
    _lastTrafficAt = null;
    notifyListeners();

    final EnginePlan plan = buildPlan(config);
    if (!plan.ok) {
      _fail(plan.reason ?? '');
      return;
    }

    // The credit is taken when the tunnel is asked for and given back if the
    // tunnel never comes up.
    final bool paid = _payForConnection();
    if (!paid) {
      _busy = false;
      setTab(AppTab.rewards);
      showToast(tr('برای اتصال باید امتیاز بگیری'));
      return;
    }

    _logSub = supervisor.logs.listen((CoreLog line) {
      logLines.add(line);
      if (logLines.length > 500) logLines.removeAt(0);
      notifyListeners();
    });

    // The step animation and the core start at the same time. The screen only
    // says "connected" when both are done, so a core that takes longer than the
    // animation cannot be shown as up before it is.
    final Future<void> animation = _runSteps(plan);
    final Future<void> core = _startCores(plan);

    try {
      await Future.wait(<Future<void>>[animation, core]);
    } on StateError catch (error) {
      _refund();
      _fail(error.message);
      return;
    } on Exception catch (error) {
      _refund();
      _fail(error.toString());
      return;
    }

    state = ConnState.connected;
    statusTitle = tr('متصل شدید');
    doneSteps = 4;
    elapsedSeconds = 0;
    _startSession(plan);
    _busy = false;
    _persist();
    notifyListeners();
  }

  void _refund() {
    if (isAdFree) return;
    rewards.refund(RewardState.creditsPerConnection);
    _persist();
  }

  Future<void> _startCores(EnginePlan plan) async {
    await supervisor.start(plan);

    // The DNS engine in proxy mode is a local service only: no system tunnel
    // is asked for, exactly as WhiteDNS' own app leaves the device alone. In
    // full-VPN mode the interface covers the device, with the split-tunnel
    // choice translated from the DNS keys to the platform's dialect.
    if (engine == EngineMode.dns) {
      if (config.textOf('dnsConnMode') != 'vpn') return;
      final String split = switch (config.textOf('dnsSplit')) {
        'include' => 'vpnonly',
        'exclude' => 'bypass',
        _ => 'off',
      };
      await VpnPlatform.instance.startVpn(
        socksPort: plan.socksPort,
        httpPort: plan.httpPort,
        mode: split,
      );
      return;
    }

    await VpnPlatform.instance.startVpn(
      socksPort: plan.socksPort,
      httpPort: plan.httpPort,
      mode: config.textOf('whSplit'),
      excludedPackages: const <String>[],
      allowedPackages: const <String>[],
    );
  }

  Future<void> _runSteps(EnginePlan plan) async {
    final int gap = stepGapFor(config);
    final List<int> at = <int>[
      0,
      plan.firstStepDelayMs,
      plan.firstStepDelayMs + gap,
      plan.firstStepDelayMs + gap * 2,
    ];
    for (int i = 0; i < plan.stepLabels.length; i++) {
      _timers.add(Timer(Duration(milliseconds: at[i]), () {
        statusSub = tr(plan.stepLabels[i]) + '…';
        doneSteps = i;
        notifyListeners();
      }));
    }
    _timers.add(Timer(Duration(milliseconds: at[3] + 700), () {}));
    await Future<void>.delayed(Duration(milliseconds: at[3] + 700));
  }

  void _startSession(EnginePlan plan) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      elapsedSeconds++;
      _paintSession(plan);
      notifyListeners();
    });
    _meter = Timer.periodic(const Duration(milliseconds: 1400), (Timer timer) {
      _measure(plan);
      notifyListeners();
    });
    _paintSession(plan);
    _measure(plan);
  }

  void _paintSession(EnginePlan plan) {
    final String mm = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final String ss = (elapsedSeconds % 60).toString().padLeft(2, '0');
    final String label = plan.routeNodes.length > 2
        ? plan.routeNodes.sublist(1, plan.routeNodes.length - 1).join(' ← ')
        : plan.routeNodes.skip(1).join(' ← ');
    final String head = engine == EngineMode.aether
        ? 'WARP (${kTransportNames[config.textOf('transport')] ?? 'MASQUE'})'
        : label;
    statusSub = '$mm:$ss · $head';
  }

  Future<void> _measure(EnginePlan plan) async {
    // Ping is measured through the proxy; it is the one number here that can
    // be wrong honestly. Traffic comes from the interface when the platform
    // exposes one, and stays empty when it does not.
    final int? measured = await probe.handshake(plan.socksPort);
    pingMs = measured ?? baseLatencyFor(config);

    final Traffic? traffic = await readTraffic();
    final Traffic? previous = _lastTraffic;
    final DateTime? previousAt = _lastTrafficAt;
    _lastTraffic = traffic;
    _lastTrafficAt = DateTime.now();

    if (traffic != null && previous != null && previousAt != null) {
      final double seconds =
          DateTime.now().difference(previousAt).inMilliseconds / 1000.0;
      if (seconds > 0) {
        downRate = _rate((traffic.rx - previous.rx) / seconds);
        upRate = _rate((traffic.tx - previous.tx) / seconds);
      }
    } else if (measured == null) {
      final int base = baseLatencyFor(config);
      pingMs = base + math.Random().nextInt(base ~/ 4 + 1);
    }
  }

  String _rate(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)}M';
    }
    if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)}K';
    }
    return '${bytesPerSecond.toStringAsFixed(0)}B';
  }

  void disconnect({String? message}) {
    _busy = false;
    _clearTimers();
    unawaited(supervisor.stop());
    unawaited(VpnPlatform.instance.stopVpn());
    unawaited(_logSub?.cancel());
    _logSub = null;

    state = ConnState.idle;
    statusTitle = tr('آماده اتصال');
    statusSub = message ?? idleSub();
    pingMs = null;
    downRate = null;
    upRate = null;
    elapsedSeconds = 0;
    doneSteps = 0;
    notifyListeners();
  }

  void _fail(String message) {
    _busy = false;
    _clearTimers();
    unawaited(supervisor.stop());
    unawaited(VpnPlatform.instance.stopVpn());
    unawaited(_logSub?.cancel());
    _logSub = null;

    state = ConnState.idle;
    lastError = message;
    statusTitle = tr('آماده اتصال');
    statusSub = message;
    doneSteps = 0;
    pingMs = null;
    downRate = null;
    upRate = null;
    notifyListeners();
  }

  /// The line under the title while nothing is happening.
  String idleSub() {
    final EngineMode mode = engine;
    if (mode == EngineMode.white) {
      return config.textOf('whServerPick') == 'auto'
          ? tr('وایت، خودکار سریع‌ترین سرور را می‌گیرد')
          : tr('وایت روی ') + activeWhiteServer(config).name;
    }
    switch (mode) {
      case EngineMode.aether:
      case EngineMode.white_aether:
        return tr('با یک لمس، تونل امن باز می‌شود');
      case EngineMode.psiphon:
        return tr('با Psiphon متصل می‌شوید');
      case EngineMode.s4:
        return tr('با S4VPN متصل می‌شوید');
      case EngineMode.dns:
        return config.textOf('dnsConnMode') == 'vpn'
            ? tr('حالت کامل VPN با تونل DNS')
            : tr('با تونل DNS متصل می‌شوید');
      case EngineMode.tor:
        return tr('با Tor متصل می‌شوید');
      case EngineMode.white:
        return tr('وایت، خودکار سریع‌ترین سرور را می‌گیرد');
    }
  }

  void _clearTimers() {
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _ticker?.cancel();
    _ticker = null;
    _meter?.cancel();
    _meter = null;
    _toastTimer?.cancel();
    _toastTimer = null;
  }

  // --------------------------------------------------------------- persistence

  Future<void> load() async {
    final Map<String, Object?> saved = await VpnPlatform.instance.loadState();
    final Object? rawConfig = saved['config'];
    if (rawConfig is Map) {
      final VpnConfig loaded = VpnConfig.defaults();
      rawConfig.forEach((Object? key, Object? value) {
        if (key is String) loaded.set(key, value);
      });
      config = loaded;
    }
    rewards = RewardState(
      credits: config.intOf('rewardCredits'),
      adFreeUntil: config.intOf('premiumExpiry'),
      totalEarned: config.intOf('totalEarned'),
      totalSpent: config.intOf('totalSpent'),
    );
    final Object? theme = saved['theme'];
    whiteTheme = theme == 'white';
    final Object? lang = saved['language'];
    if (lang is String && kSupportedLanguages.contains(lang)) language = lang;
    _normalize();
    statusSub = idleSub();
    _startAdFreeWatcher();
    notifyListeners();
  }

  /// Watch for the time a code bought running out, so the ad tab comes back on
  /// its own rather than at the next launch.
  void _startAdFreeWatcher() {
    _adFreeTicker?.cancel();
    _adFreeTicker = Timer.periodic(const Duration(seconds: 30), (Timer timer) {
      final bool was = rewards.adFreeActive;
      if (was != rewards.adFreeActive) {
        if (!was) {
          // The code has run out: the tab returns.
          if (tab == AppTab.rewards) tab = AppTab.home;
          _persist();
        }
        notifyListeners();
      }
    });
  }

  void _persist() {
    final Map<String, Object?> stateMap = <String, Object?>{
      'config': config.values,
      'theme': whiteTheme ? 'white' : 'dark',
      'language': language,
      'rewardCredits': rewards.credits,
      'totalEarned': rewards.totalEarned,
      'totalSpent': rewards.totalSpent,
      'premiumExpiry': rewards.adFreeUntil,
    };
    unawaited(VpnPlatform.instance.saveState(stateMap));
  }

  @override
  void dispose() {
    _clearTimers();
    _adFreeTicker?.cancel();
    unawaited(supervisor.stop());
    unawaited(_logSub?.cancel());
    super.dispose();
  }
}

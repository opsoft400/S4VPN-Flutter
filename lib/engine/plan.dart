import '../models/vpn_config.dart';
import '../models/white_servers.dart';
import 'aether_args.dart';
import 'dns_config.dart';
import 'engine_mode.dart';
import 'lantern_config.dart';
import 'mihomo_config.dart';
import 'psiphon_config.dart';

/// One core process the app is about to start.
class CoreProcess {
  const CoreProcess({
    required this.core,
    required this.args,
    this.env = const <String, String>{},
    this.files = const <String, String>{},
    required this.socksPort,
    required this.role,
  });

  final CoreId core;
  final List<String> args;
  final Map<String, String> env;

  /// Files to write next to the core before it starts: name -> contents.
  final Map<String, String> files;

  /// The local SOCKS5 port this process serves, once it is up.
  final int socksPort;

  /// What the process is for, for the log: `proxy`, `tunnel`, `hop`.
  final String role;
}

/// Everything one tap on the power button turns into.
class EnginePlan {
  const EnginePlan({
    required this.mode,
    required this.processes,
    required this.socksPort,
    required this.httpPort,
    required this.routeNodes,
    required this.stepLabels,
    required this.firstStepDelayMs,
    this.reason,
  });

  final EngineMode mode;
  final List<CoreProcess> processes;
  final int socksPort;
  final int? httpPort;

  /// Persian node names for the route strip on the home screen.
  final List<String> routeNodes;

  /// Persian labels for the four connect steps.
  final List<String> stepLabels;

  /// Milliseconds before the first step completes: the preview tunes this per
  /// engine so a fast core does not look slow and a slow one does not look
  /// stuck.
  final int firstStepDelayMs;

  /// Set when the plan cannot be built. The home screen shows it instead of
  /// pretending to connect.
  final String? reason;

  bool get ok => reason == null;
}

const Map<String, String> kTransportNames = <String, String>{
  'masque': 'MASQUE',
  'wg': 'WireGuard',
  'gool': 'WARP-in-WARP',
  'mim': 'MASQUE-in-MASQUE',
};

/// Milliseconds the preview waits for the first step, per engine and scan
/// depth. Roughly what each core actually takes to reach its first decision.
const Map<String, int> kScanFirstDelayMs = <String, int>{
  'turbo': 900,
  'balanced': 1600,
  'thorough': 2600,
  'stealth': 3400,
  'verified': 2000,
  'ironclad': 4200,
};

String _wayOf(VpnConfig c) {
  final String engine = c.textOf('engine');
  if (engine == 'psiphon') return c.textOf('psWay');
  if (engine == 'tor') return c.textOf('torWay');
  return 'warp';
}


int _portOf(String address, int fallback) {
  final int colon = address.lastIndexOf(':');
  if (colon < 0) return fallback;
  return int.tryParse(address.substring(colon + 1)) ?? fallback;
}

/// The route strip: `شما` first, `اینترنت` last, the hops in between.
List<String> routeNodesFor(VpnConfig cfg) {
  final String engine = cfg.textOf('engine');

  if (engine == 'white') {
    final WhiteServer server = activeWhiteServer(cfg);
    if (cfg.textOf('whChain') == 'warp') {
      return <String>['شما', 'WARP', server.name, 'اینترنت'];
    }
    return <String>['شما', server.name, 'اینترنت'];
  }

  final String warp = 'WARP (${kTransportNames[cfg.textOf('transport')] ?? 'MASQUE'})';
  if (engine == 'aether') return <String>['شما', warp, 'اینترنت'];

  if (engine == 'dns') {
    return <String>['شما', 'DNS · SOFT400', 'اینترنت'];
  }

  final String name =
      engine == 'psiphon' ? 'Psiphon' : engine == 's4' ? 'S4VPN' : 'Tor';
  switch (_wayOf(cfg)) {
    case 'chain':
      return <String>['شما', warp, name, 'اینترنت'];
    case 'reverse':
      return <String>['شما', name, warp, 'اینترنت'];
    case 'only':
    default:
      return <String>['شما', name, 'اینترنت'];
  }
}

WhiteServer activeWhiteServer(VpnConfig cfg) {
  final List<WhiteServer> servers = orderedWhiteServers(cfg);
  if (cfg.textOf('whServerPick') == 'auto') return fastestServer(servers);
  final String wanted = cfg.textOf('whServer');
  for (final WhiteServer server in servers) {
    if (server.name == wanted) return server;
  }
  return fastestServer(servers);
}

/// The list in the order the picker asks for. `fast` is deliberately a shuffle
/// rather than a sort: the preview's "fastest" is a re-test order, not a
/// measurement, and sorting a jittered list would flatter it.
List<WhiteServer> orderedWhiteServers(VpnConfig cfg) {
  final List<WhiteServer> servers = List<WhiteServer>.of(kWhiteServers);
  if (cfg.textOf('whSort') == 'low') {
    servers.sort((WhiteServer a, WhiteServer b) => a.latency.compareTo(b.latency));
  } else if (cfg.textOf('whSort') == 'fast') {
    servers.shuffle();
  }
  return servers;
}

/// The four labels the connect animation walks through.
List<String> stepLabelsFor(VpnConfig cfg) {
  final String engine = cfg.textOf('engine');
  final String way = _wayOf(cfg);

  if (engine == 'white') {
    final WhiteServer server = activeWhiteServer(cfg);
    if (cfg.textOf('whServerPick') == 'auto') {
      return <String>[
        'دریافت سابسکریپشن',
        'تست سرورها و انتخاب خودکار',
        'اتصال به ${server.name}',
        'راه‌اندازی پروکسی',
      ];
    }
    return <String>[
      'دریافت سابسکریپشن',
      'اتصال به ${server.name}',
      'بررسی دسترسی سرور',
      'راه‌اندازی پروکسی',
    ];
  }

  if (engine == 'aether' || engine == 'white_aether') {
    final bool forced = (cfg.textOf('peer').trim().isNotEmpty) ||
        (cfg.textOf('transport') == 'gool' &&
            cfg.textOf('wiwOuter').trim().isNotEmpty &&
            cfg.textOf('wiwInner').trim().isNotEmpty) ||
        (cfg.textOf('transport') == 'mim' &&
            cfg.textOf('mimOuter').trim().isNotEmpty &&
            cfg.textOf('mimInner').trim().isNotEmpty);
    return <String>[
      forced ? 'استفاده از آدرس تعیین‌شده' : 'جست‌وجوی آدرس‌های در دسترس',
      'دست‌دهی امن با سرور',
      cfg.boolOf('dataCheck') ? 'آزمایش مسیر داده' : 'راه‌اندازی تونل',
      'راه‌اندازی پروکسی محلی',
    ];
  }

  if (engine == 'psiphon') {
    if (way == 'only') {
      return <String>[
        'راه‌اندازی Psiphon',
        cfg.textOf('psShape') == 'cdn' ? 'اتصال از پشت CDN' : 'یافتن سرور در دسترس',
        'ساخت تونل',
        'راه‌اندازی پروکسی',
      ];
    }
    if (way == 'chain') {
      return <String>[
        'ساخت تونل WARP',
        'راه‌اندازی Psiphon داخل تونل',
        'آزمایش مسیر',
        'راه‌اندازی پروکسی‌ها',
      ];
    }
    return <String>[
      'راه‌اندازی Psiphon',
      'ساخت تونل WARP از داخل Psiphon',
      'آزمایش مسیر',
      'راه‌اندازی پروکسی‌ها',
    ];
  }

  if (engine == 's4') {
    return <String>[
      'دریافت پیکربندی S4VPN',
      'ساخت تونل',
      'آزمایش مسیر',
      'راه‌اندازی پروکسی',
    ];
  }

  if (engine == 'dns') {
    final bool vpn = cfg.textOf('dnsConnMode') == 'vpn';
    return <String>[
      'خواندن سرور و ری‌زالورها',
      cfg.boolOf('dnsAutoTune') ? 'تست موازی رزولورها (AutoTune)' : 'پویش اندازه بسته (MTU)',
      'راه‌اندازی نشست DNS',
      vpn ? 'ساخت تونل کامل دستگاه' : 'راه‌اندازی پروکسی',
    ];
  }

  final bool bridged =
      cfg.textOf('torBridges') == 'force' || cfg.textOf('torBridges') == 'custom';
  if (way == 'only') {
    return <String>[
      'دریافت دایرکتوری Tor',
      bridged ? 'یافتن پل مناسب' : 'ساخت مدار Tor',
      'بررسی دسترسی Tor',
      'راه‌اندازی پروکسی',
    ];
  }
  if (way == 'chain') {
    return <String>[
      'ساخت تونل WARP',
      'بارگذاری Tor داخل تونل',
      'بررسی دسترسی Tor',
      'راه‌اندازی پروکسی‌ها',
    ];
  }
  return <String>[
    'دریافت دایرکتوری Tor',
    bridged ? 'یافتن پل مناسب' : 'ساخت مدار Tor',
    'ساخت تونل WARP از داخل Tor',
    'راه‌اندازی پروکسی‌ها',
  ];
}

int firstDelayFor(VpnConfig cfg) {
  final String engine = cfg.textOf('engine');
  if (engine == 'white') return 1400;
  if (engine == 'psiphon') return 1500;
  if (engine == 's4') return 1600;
  if (engine == 'dns') return 2400;
  if (engine == 'tor') return 2200;
  final bool forced = cfg.textOf('peer').trim().isNotEmpty ||
      (cfg.textOf('transport') == 'gool' &&
          cfg.textOf('wiwOuter').trim().isNotEmpty &&
          cfg.textOf('wiwInner').trim().isNotEmpty) ||
      (cfg.textOf('transport') == 'mim' &&
          cfg.textOf('mimOuter').trim().isNotEmpty &&
          cfg.textOf('mimInner').trim().isNotEmpty);
  if (forced) return 300;
  if (cfg.boolOf('quick')) return 700;
  return kScanFirstDelayMs[cfg.textOf('scan')] ?? 1600;
}

/// Milliseconds between steps. Tor is slower between every stage, so its steps
/// are spaced further apart rather than shown as a longer first wait.
int stepGapFor(VpnConfig cfg) => cfg.textOf('engine') == 'tor' ? 1300 : 700;

/// Base latency the readout starts from, per engine.
int baseLatencyFor(VpnConfig cfg) {
  switch (cfg.textOf('engine')) {
    case 'tor':
      return _wayOf(cfg) == 'only' ? 320 : 380;
    case 'psiphon':
      return _wayOf(cfg) == 'only' ? 130 : 170;
    case 's4':
      return 56;
    case 'dns':
      // A DNS tunnel carries everything inside TXT queries and answers; it is
      // honest about being the slowest engine here.
      return 260;
    case 'white':
      return activeWhiteServer(cfg).latency;
    case 'aether':
    default:
      switch (cfg.textOf('transport')) {
        case 'wg':
          return 36;
        case 'gool':
          return 92;
        case 'mim':
          return 88;
        case 'masque':
        default:
          return 48;
      }
  }
}

/// Turn the settings into the processes to start, in order.
///
/// Every engine ends in the same place -- a local SOCKS5 on the address the
/// user configured -- so the platform tunnel never has to know which core is
/// behind it.
EnginePlan buildPlan(VpnConfig cfg) {
  final int bindPort = _portOf(cfg.textOf('bind'), 1819);
  final int? httpPort = cfg.boolOf('httpOn') ? _portOf(cfg.textOf('httpAddr'), 1822) : null;
  final EngineMode mode = EngineMode.parse(cfg.textOf('engine'));

  final List<CoreProcess> processes = <CoreProcess>[];
  String? reason;
  int socksPort = bindPort;
  int? dnsHttpPort;

  switch (mode) {
    case EngineMode.aether:
    case EngineMode.white_aether:
      final AetherInvocation aether = buildAetherInvocation(cfg);
      processes.add(CoreProcess(
        core: CoreId.aether,
        args: aether.args,
        env: aether.env,
        socksPort: bindPort,
        role: 'tunnel',
      ));
      break;

    case EngineMode.tor:
      processes.add(CoreProcess(
        core: CoreId.aether,
        args: buildTorArgs(cfg),
        env: buildAetherInvocation(cfg).env,
        socksPort: bindPort,
        role: 'tunnel',
      ));
      break;

    case EngineMode.psiphon:
      final PsiphonPlan psiphon = buildPsiphonPlan(cfg);
      final String way = cfg.textOf('psWay');
      socksPort = bindPort;

      if (way == 'chain') {
        // aether is the proxy the user talks to and dials out through
        // Psiphon, so Psiphon is the one that has to come up first.
        final VpnConfig warp = VpnConfig.from(cfg)
          ..set('upstream', 'socks5://127.0.0.1:${psiphon.socksPort}');
        final AetherInvocation aether = buildAetherInvocation(warp);
        processes.add(CoreProcess(
          core: CoreId.psiphon,
          args: psiphon.args,
          files: <String, String>{'psiphon.json': psiphon.configJson},
          socksPort: psiphon.socksPort,
          role: 'hop',
        ));
        processes.add(CoreProcess(
          core: CoreId.aether,
          args: aether.args,
          env: aether.env,
          socksPort: bindPort,
          role: 'tunnel',
        ));
      } else if (way == 'reverse') {
        // Psiphon is the proxy the user talks to; aether sits behind it on
        // the hop port and has no upstream of its own.
        final VpnConfig warp = VpnConfig.from(cfg)
          ..set('bind', '127.0.0.1:${psiphon.socksPort}')
          ..set('upstream', '');
        final AetherInvocation aether = buildAetherInvocation(warp);
        processes.add(CoreProcess(
          core: CoreId.aether,
          args: aether.args,
          env: aether.env,
          socksPort: psiphon.socksPort,
          role: 'hop',
        ));
        processes.add(CoreProcess(
          core: CoreId.psiphon,
          args: psiphon.args,
          files: <String, String>{'psiphon.json': psiphon.configJson},
          socksPort: bindPort,
          role: 'tunnel',
        ));
      } else {
        processes.add(CoreProcess(
          core: CoreId.psiphon,
          args: psiphon.args,
          files: <String, String>{'psiphon.json': psiphon.configJson},
          socksPort: bindPort,
          role: 'tunnel',
        ));
      }
      break;

    case EngineMode.white:
      final int? warpHop = cfg.textOf('whChain') == 'warp'
          ? whiteWarpHopPort(bindPort)
          : null;
      final MihomoPlan mihomo = buildMihomoConfig(
        cfg,
        socksPort: bindPort,
        httpPort: httpPort,
        warpHopPort: warpHop,
      );
      reason = mihomo.reason;
      if (mihomo.reason == null) {
        if (warpHop != null) {
          final VpnConfig warp = VpnConfig.from(cfg)
            ..set('bind', '127.0.0.1:$warpHop');
          final AetherInvocation aether = buildAetherInvocation(warp);
          processes.add(CoreProcess(
            core: CoreId.aether,
            args: aether.args,
            env: aether.env,
            socksPort: warpHop,
            role: 'hop',
          ));
        }
        processes.add(CoreProcess(
          core: CoreId.mihomo,
          args: <String>['-f', 'mihomo.yaml'],
          files: <String, String>{'mihomo.yaml': mihomo.yaml},
          socksPort: bindPort,
          role: 'tunnel',
        ));
      }
      break;

    case EngineMode.s4:
      final LanternPlan lantern = buildLanternPlan(cfg);
      processes.add(CoreProcess(
        core: CoreId.lantern,
        args: lantern.args,
        env: lantern.env,
        socksPort: lantern.socksPort,
        role: 'tunnel',
      ));
      socksPort = lantern.socksPort;
      break;

    case EngineMode.dns:
      final DnsPlan dns = buildDnsPlan(cfg);
      reason = dns.reason;
      if (dns.ok) {
        final CoreId dnsCore = dnsEngineOf(cfg) == 'cotten'
            ? CoreId.cottendns
            : CoreId.stormdns;
        processes.add(CoreProcess(
          core: dnsCore,
          args: dns.args,
          files: <String, String>{
            for (final DnsPlanFile file in dns.files) file.name: file.contents,
          },
          socksPort: dns.socksPort,
          role: 'tunnel',
        ));
        socksPort = dns.socksPort;
        // The DNS core opens its own HTTP bridge; the generic `--http-proxy`
        // switch is not part of this engine.
        dnsHttpPort = dns.httpPort;
      }
      break;
  }

  return EnginePlan(
    mode: mode,
    processes: processes,
    socksPort: socksPort,
    httpPort: mode == EngineMode.dns ? dnsHttpPort : httpPort,
    routeNodes: routeNodesFor(cfg),
    stepLabels: stepLabelsFor(cfg),
    firstStepDelayMs: firstDelayFor(cfg),
    reason: reason,
  );
}

import '../models/vpn_config.dart';

/// What the settings screen becomes when it is handed to the Aether 2 core.
///
/// The preview's flags are the contract; the bundled core is Aether 2.3.0, so
/// anything the preview shows that 2.0.0 does not parse is kept on the app side
/// rather than passed through. Aether rejects an unknown option outright --
/// `unknown option '--stats'` -- which would fail the whole connection, so this
/// file is deliberately a whitelist and not a mirror.
class AetherInvocation {
  const AetherInvocation(this.args, {this.env = const <String, String>{}});

  final List<String> args;
  final Map<String, String> env;
}

/// Scan modes Aether 2.3.0 accepts. `verified` exists only in the preview's
/// 2.1.0 spec; until the core grows that mode the value is answered the
/// way the default would, rather than with an option the parser refuses.
const Set<String> kSupportedScanModes = <String>{
  'turbo',
  'balanced',
  'thorough',
  'stealth',
  'ironclad',
};

String _scanMode(VpnConfig c) {
  final String value = c.textOf('scan');
  return kSupportedScanModes.contains(value) ? value : 'balanced';
}

void _put(List<String> args, String flag, String value) {
  if (value.trim().isEmpty) return;
  args
    ..add(flag)
    ..add(value.trim());
}

/// The full `aether ...` command line for the current settings.
AetherInvocation buildAetherInvocation(VpnConfig cfg) {
  final List<String> args = <String>[];
  final Map<String, String> env = <String, String>{};

  // --- connection ---
  _put(args, '--bind', cfg.textOf('bind'));
  if (cfg.boolOf('httpOn')) _put(args, '--http-proxy', cfg.textOf('httpAddr'));
  _put(args, '--upstream', cfg.textOf('upstream'));
  _put(args, '--mark', cfg.textOf('mark'));
  args.add(cfg.boolOf('quick') ? '--quick-reconnect' : '--no-quick-reconnect');

  switch (cfg.textOf('ip')) {
    case '6':
      args.add('-6');
    case 'both':
      args.add('--dual');
    case '4':
    default:
      args.add('-4');
  }

  // --- protocol ---
  switch (cfg.textOf('transport')) {
    case 'wg':
      args.add('--wg');
    case 'gool':
      args.add('--gool');
    case 'mim':
      args.add('--mim');
    case 'masque':
    default:
      args.add('--masque');
  }

  _put(args, '--scan', _scanMode(cfg));
  _put(args, '--noize', cfg.textOf('noize'));

  // --- transport specifics ---
  final String transport = cfg.textOf('transport');
  if (transport == 'masque' || transport == 'mim') {
    args.add(cfg.textOf('carrier') == 'h2' ? '--h2' : '--h3');
    if (!cfg.boolOf('quicV2')) args.add('--no-quic-v2');
    if (cfg.textOf('carrier') == 'h2') {
      _put(args, '--h2-peer', cfg.textOf('h2Peer'));
      if (cfg.boolOf('fragment')) {
        args.add('--fragment');
        _put(args, '--fragment-size', cfg.textOf('fragSize'));
        _put(args, '--fragment-delay', cfg.textOf('fragDelay'));
      }
    }
    if (cfg.boolOf('ech')) args.addAll(<String>['--ech', 'auto']);
  }

  if (transport == 'wg' || transport == 'gool') {
    _put(args, '--keepalive', cfg.textOf('keepalive'));
    if (cfg.boolOf('noRetry')) args.add('--no-profile-retry');
  }
  if (transport == 'masque' || transport == 'wg') {
    _put(args, '--peer', cfg.textOf('peer'));
  }
  if (transport == 'gool') {
    _put(args, '--wiw-outer', cfg.textOf('wiwOuter'));
    _put(args, '--wiw-inner', cfg.textOf('wiwInner'));
  }
  if (transport == 'mim') {
    _put(args, '--mim-outer', cfg.textOf('mimOuter'));
    _put(args, '--mim-inner', cfg.textOf('mimInner'));
  }

  // --- health ---
  if (!cfg.boolOf('dataCheck')) args.add('--no-data-check');
  _put(args, '--validate-secs', cfg.textOf('validateSecs'));
  if (transport == 'masque' || transport == 'mim') {
    _put(args, '--startup-secs', cfg.textOf('startupSecs'));
  }
  _put(args, '--reconnect-secs', cfg.textOf('reconnectSecs'));
  _put(args, '--dns', cfg.textOf('dns'));

  // --- routing ---
  _put(args, '--route-block', cfg.textOf('routeBlock'));
  _put(args, '--route-direct', cfg.textOf('routeDirect'));
  if (!cfg.boolOf('routeSniff')) env['AETHER_ROUTE_SNIFF'] = '0';
  if (cfg.boolOf('routeSniff')) env['AETHER_ROUTE_SNIFF_MS'] = cfg.textOf('routeSniffMs');

  // --- zero trust ---
  final String team = cfg.textOf('team').trim();
  if (team.isNotEmpty) {
    _put(args, '--team', team);
    switch (cfg.textOf('ztMethod')) {
      case 'email':
        _put(args, '--access-email', cfg.textOf('ztEmail'));
      case 'token':
        _put(args, '--access-id', cfg.textOf('ztId'));
        _put(args, '--access-secret', cfg.textOf('ztSecret'));
      case 'jwt':
        _put(args, '--access-token', cfg.textOf('ztJwt'));
      default:
        break;
    }
    if (cfg.boolOf('gateway')) args.add('--gateway');
  }

  // --- limits and identity (environment only in 2.0.0) ---
  _putEnv(env, 'AETHER_PERF_PROFILE', cfg.textOf('perf'));
  _putEnv(env, 'AETHER_MAX_CLIENTS', cfg.textOf('maxClients'));
  _putEnv(env, 'AETHER_HALF_CLOSE_SECS', cfg.textOf('halfClose'));
  _putEnv(env, 'AETHER_TCP_KEEPALIVE_SECS', cfg.textOf('tcpKeepalive'));
  _putEnv(env, 'AETHER_TCP_CONNECT_SECS', cfg.textOf('tcpConnect'));
  if (!cfg.boolOf('reprovision')) env['AETHER_REPROVISION'] = '0';

  return AetherInvocation(args, env: env);
}

void _putEnv(Map<String, String> env, String key, String value) {
  if (value.trim().isEmpty) return;
  env[key] = value.trim();
}

/// Tor, as Aether 2 carries it. `only` skips the WARP tunnel entirely, `chain`
/// runs Tor inside the tunnel and `reverse` dials the tunnel through Tor --
/// and because a Tor exit carries TCP only, `reverse` pins the tunnel to
/// MASQUE over HTTP/2 exactly as the preview warns it must.
List<String> buildTorArgs(VpnConfig cfg) {
  final bool reverse = cfg.textOf('torWay') == 'reverse';
  final bool only = cfg.textOf('torWay') == 'only';

  VpnConfig effective = cfg;
  if (reverse) {
    effective = VpnConfig.from(cfg)
      ..set('transport', 'masque')
      ..set('carrier', 'h2');
  }
  if (only) {
    // Nothing of WARP applies to a plain Tor proxy, so ask the planner for the
    // connection-side flags only: bind, upstream, mark, routes.
    effective = VpnConfig.from(cfg);
  }

  final AetherInvocation base = buildAetherInvocation(effective);
  final List<String> args = only
      ? stripWarpFlags(base.args)
      : List<String>.of(base.args);

  if (only) {
    args.add('--tor-only');
  } else if (reverse) {
    args.add('--tor-reverse');
  } else {
    args.add('--tor');
  }

  switch (cfg.textOf('torBridges')) {
    case 'force':
      args.add('--tor-bridges');
    case 'never':
      args.add('--no-tor-bridges');
    case 'custom':
      for (final String line in cfg.textOf('torBridgeLines').split('\n')) {
        if (line.trim().isNotEmpty) _put(args, '--tor-bridge', line);
      }
      break;
    case 'auto':
    default:
      break;
  }

  _put(args, '--tor-bridge-file', cfg.textOf('torBridgeFile'));
  _put(args, '--tor-pt', cfg.textOf('torPt'));
  _put(args, '--tor-pt-dir', cfg.textOf('torPtDir'));
  _put(args, '--tor-bind', cfg.textOf('torBind'));
  _put(args, '--tor-dir', cfg.textOf('torDir'));

  return args;
}


/// Drop the WARP half of a command line.
///
/// `--tor-only` opens no tunnel at all, so the protocol, scan and camouflage
/// flags have nothing to describe. They are removed rather than left to the
/// core, which would happily scan for a peer it is never going to dial.
List<String> stripWarpFlags(List<String> args) {
  const Set<String> valueFlags = <String>{
    '--peer',
    '--wg-peer',
    '--wiw-outer',
    '--wiw-inner',
    '--mim-outer',
    '--mim-inner',
    '--h2-peer',
    '--fragment-size',
    '--fragment-delay',
    '--keepalive',
    '--scan',
    '--noize',
    '--protocol',
    '--validate-secs',
    '--startup-secs',
    '--reconnect-secs',
    '--tls-groups',
    '--routes',
  };
  const Set<String> bareFlags = <String>{
    '--masque',
    '--wg',
    '--wireguard',
    '--warp',
    '--gool',
    '--wiw',
    '--mim',
    '--masque-in-masque',
    '-4',
    '-6',
    '--dual',
    '--h2',
    '--h3',
    '--no-quic-v2',
    '--fragment',
    '--ech',
    '--no-profile-retry',
    '--no-data-check',
    '--quick-reconnect',
    '--no-quick-reconnect',
    '--gateway',
  };

  final List<String> out = <String>[];
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (valueFlags.contains(arg)) {
      i++;
      continue;
    }
    if (bareFlags.contains(arg)) continue;
    out.add(arg);
  }
  return out;
}

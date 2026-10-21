import '../models/vpn_config.dart';

/// Psiphon, as Aether 2 does not carry it.
/// The bundled Aether 2.3.0 still carries no Psiphon of its own, and White-
/// Aesther's own psiphon carrier is an Android library rather than a binary,
/// so the `psiphon` mode here runs psiphon-tunnel-core beside it. When the
/// settings ask for a chain, the two are started in the order the settings
/// screen describes:
///
/// * `chain`   app -> aether (WARP) -> psiphon -> internet, exit is Psiphon
/// * `reverse` app -> psiphon -> aether (WARP) -> internet, exit is WARP
/// * `only`    app -> psiphon -> internet
///
/// Whoever the user talks to binds [VpnConfig] `bind`; the other one takes
/// `psBind`. Aether dials its way out through a proxy with `--upstream`, and
/// psiphon-tunnel-core does the same with `UpstreamProxyUrl`.
class PsiphonPlan {
  const PsiphonPlan({
    required this.args,
    required this.configJson,
    required this.socksPort,
    required this.upstream,
  });

  final List<String> args;
  final String configJson;

  /// The port this Psiphon process listens on.
  final int socksPort;

  /// The proxy Psiphon dials through, when it is the inner hop.
  final String? upstream;
}

int _portOf(String address, int fallback) {
  final int colon = address.lastIndexOf(':');
  if (colon < 0) return fallback;
  return int.tryParse(address.substring(colon + 1)) ?? fallback;
}

/// Build the Psiphon side of a connection for the current settings.
PsiphonPlan buildPsiphonPlan(VpnConfig cfg) {
  final String way = cfg.textOf('psWay');
  final int bindPort = _portOf(cfg.textOf('bind'), 1819);
  final int hopPort = _portOf(cfg.textOf('psBind'), 1821);

  final int socksPort;
  final String? upstream;
  switch (way) {
    case 'chain':
      // aether is the one the user talks to, so psiphon sits behind it.
      socksPort = hopPort;
      upstream = null;
    case 'reverse':
      socksPort = bindPort;
      upstream = 'socks5://127.0.0.1:$hopPort';
    case 'only':
    default:
      socksPort = bindPort;
      upstream = null;
  }

  final Map<String, Object?> config = <String, Object?>{
    'DataDirectory': '<dataDir>',
    'ListenInterface': '127.0.0.1',
    'SOCKSProxyPort': socksPort,
    // Nothing asks Psiphon for an HTTP proxy: the app exposes its own.
    'HTTPProxyPort': 0,
    'PropagationChannelId': 'FFFFFFFFFFFFFFFF',
    'SponsorId': 'FFFFFFFFFFFFFFFF',
    if (upstream != null) 'UpstreamProxyUrl': upstream,
    if (cfg.textOf('psRegion').trim().isNotEmpty)
      'DeviceRegion': cfg.textOf('psRegion').trim().toUpperCase(),
    if (cfg.textOf('psCdnSni').trim().isNotEmpty)
      'MeekHostHeader': cfg.textOf('psCdnSni').trim(),
  };

  switch (cfg.textOf('psShape')) {
    // A preference, not a lock: psiphon-tunnel-core still falls back to
    // anything else it can reach when the hinted protocol is blocked.
    case 'cdn':
      config['TunnelProtocol'] = 'MEEK_OBFUSCATED_SESSION_RESUMPTION';
    case 'direct':
      config['TunnelProtocol'] = 'TLSV2';
    case 'auto':
    default:
      break;
  }

  final List<String> ips = cfg
      .textOf('psCdnIps')
      .split(RegExp(r'[,\s]+'))
      .where((String ip) => ip.trim().isNotEmpty)
      .toList();
  if (ips.isNotEmpty) config['MeekDialAddresses'] = ips;

  final List<String> args = <String>['-configFile', '<configFile>'];
  if (cfg.textOf('psDir').trim().isNotEmpty) {
    args
      ..add('-dataDirectory')
      ..add(cfg.textOf('psDir').trim());
  }
  if (cfg.textOf('psHttp').trim().isNotEmpty) {
    args
      ..add('-httpProxy')
      ..add(cfg.textOf('psHttp').trim());
  }

  return PsiphonPlan(
    args: args,
    configJson: _json(config),
    socksPort: socksPort,
    upstream: upstream,
  );
}

/// The WARP hop for the `chain` mode: aether dials out through Psiphon.
List<String> chainWarpArgs(VpnConfig cfg, int psiphonPort) {
  final List<String> args = <String>['--bind', cfg.textOf('bind'), '--upstream',
    'socks5://127.0.0.1:$psiphonPort'];
  return args;
}

/// A small JSON writer. The Psiphon config is flat, so a full serializer is
/// more code than the problem is worth; this escapes what actually appears in
/// one and refuses to pretend otherwise.
String _json(Map<String, Object?> values) {
  final StringBuffer out = StringBuffer('{');
  bool first = true;
  values.forEach((String key, Object? value) {
    if (!first) out.write(',');
    first = false;
    out.write('${_str(key)}:${_value(value)}');
  });
  out.write('}');
  return out.toString();
}

String _value(Object? value) {
  if (value == null) return 'null';
  if (value is bool || value is num) return value.toString();
  return _str(value.toString());
}

String _str(String value) {
  final StringBuffer out = StringBuffer('"');
  for (final int unit in value.codeUnits) {
    switch (unit) {
      case 0x22:
        out.write('\\"');
      case 0x5C:
        out.write('\\\\');
      case 0x0A:
        out.write('\\n');
      case 0x0D:
        out.write('\\r');
      case 0x09:
        out.write('\\t');
      default:
        if (unit < 0x20) {
          out.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
        } else {
          out.writeCharCode(unit);
        }
    }
  }
  out.write('"');
  return out.toString();
}

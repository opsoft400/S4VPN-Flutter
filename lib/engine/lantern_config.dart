import '../models/vpn_config.dart';

/// The S4 engine: Lantern, speaking to us only through a local proxy.
///
/// Lantern's library is written to own a tun device itself, which is exactly
/// what a second tunnel inside the same process cannot do. What ships here is
/// the released Lantern core run as its own process in proxy-only mode, so S4
/// has the same shape as every other engine in this app: a core that opens a
/// local SOCKS5, and a platform tunnel that points at it.
class LanternPlan {
  const LanternPlan({
    required this.args,
    required this.env,
    required this.socksPort,
    required this.apiPort,
  });

  final List<String> args;
  final Map<String, String> env;
  final int socksPort;
  final int apiPort;
}

int _portOf(String address, int fallback) {
  final int colon = address.lastIndexOf(':');
  if (colon < 0) return fallback;
  return int.tryParse(address.substring(colon + 1)) ?? fallback;
}

/// Build the lantern command line for the current settings.
///
/// The API port is kept away from every proxy port the settings can choose, so
/// a port collision is never mistaken for a tunnel that failed to start.
LanternPlan buildLanternPlan(VpnConfig cfg) {
  final int socksPort = _portOf(cfg.textOf('bind'), 1819);
  final int apiPort = socksPort == 16379 ? 16380 : 16379;

  final List<String> args = <String>[
    '--temp',
    '--no-launch-browser',
    '--proxyPort',
    '$socksPort',
    '--apiPort',
    '$apiPort',
    '--env',
    'prod',
  ];

  final String httpAddr = cfg.textOf('httpAddr').trim();
  if (cfg.boolOf('httpOn') && httpAddr.isNotEmpty) {
    args
      ..add('--httpPort')
      ..add('${_portOf(httpAddr, 1822)}');
  }

  final Map<String, String> env = <String, String>{
    'LANTERN_ENV': 'prod',
    'LANTERN_DISABLE_STATS': cfg.boolOf('stats') ? '0' : '1',
  };

  return LanternPlan(
    args: args,
    env: env,
    socksPort: socksPort,
    apiPort: apiPort,
  );
}

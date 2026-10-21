/// A server in the White engine's built-in subscription.
///
/// The preview ships a fixed list and treats it as a live subscription: the
/// latencies move on every re-test, the fastest one is what `auto` picks, and
/// the flag, the protocol tag and the name are all the user ever sees.
class WhiteServer {
  const WhiteServer({
    required this.flag,
    required this.name,
    required this.protocol,
    required this.latency,
  });

  final String flag;

  /// Persian name, as authored.
  final String name;
  final String protocol;
  final int latency;

  WhiteServer copyWith({int? latency}) => WhiteServer(
        flag: flag,
        name: name,
        protocol: protocol,
        latency: latency ?? this.latency,
      );
}

/// Latency bands, matching the preview's `.ok` / `.mid` / `.bad` classes.
enum LatencyBand { ok, mid, bad }

LatencyBand latencyBand(int latency) {
  if (latency < 90) return LatencyBand.ok;
  if (latency < 160) return LatencyBand.mid;
  return LatencyBand.bad;
}

const List<WhiteServer> kWhiteServers = <WhiteServer>[
  WhiteServer(flag: '🇩🇪', name: 'White · آلمان ۱', protocol: 'VLESS', latency: 64),
  WhiteServer(flag: '🇳🇱', name: 'White · هلند ۱', protocol: 'VLESS', latency: 78),
  WhiteServer(flag: '🇫🇷', name: 'White · فرانسه ۱', protocol: 'Trojan', latency: 112),
  WhiteServer(flag: '🇹🇷', name: 'White · ترکیه ۱', protocol: 'Hysteria2', latency: 148),
  WhiteServer(flag: '🇺🇸', name: 'White · آمریکا ۱', protocol: 'VMess', latency: 196),
  WhiteServer(flag: '🇫🇮', name: 'White · فنلاند ۱', protocol: 'VLESS', latency: 88),
  WhiteServer(flag: '🇬🇧', name: 'White · بریتانیا ۱', protocol: 'Trojan', latency: 132),
  WhiteServer(flag: '🇨🇦', name: 'White · کانادا ۱', protocol: 'VLESS', latency: 171),
];

/// The server `auto` settles on: the lowest latency in the list.
WhiteServer fastestServer(Iterable<WhiteServer> servers) {
  WhiteServer best = servers.first;
  for (final WhiteServer server in servers) {
    if (server.latency <= best.latency) best = server;
  }
  return best;
}

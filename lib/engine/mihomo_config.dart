import '../models/vpn_config.dart';
import '../models/white_servers.dart';

/// White's built-in subscriptions.
///
/// The preview describes `whSub: builtin` as a list the app carries with it,
/// and the White engine this was written against ships none -- its sources are
/// always the user's own links. Fill this in and `builtin` starts working with
/// no link to paste; leave it empty and the planner falls back to the link in
/// [VpnConfig] `whSubUrl`.
const List<String> kBuiltinSubscriptions = <String>[];

/// A source of exit nodes: a subscription URL, or nothing.
class WhiteSource {
  const WhiteSource(this.name, this.url);

  final String name;
  final String url;
}

/// Everything needed to write the Mihomo configuration for the White engine.
class MihomoPlan {
  const MihomoPlan({
    required this.yaml,
    required this.sources,
    required this.reason,
  });

  final String yaml;
  final List<WhiteSource> sources;

  /// Set when the configuration cannot be written -- no subscription, most
  /// often. The UI shows it instead of a silent failure.
  final String? reason;
}

/// Resolve the subscription list the way the settings screen describes it.
List<WhiteSource> resolveSources(VpnConfig cfg) {
  if (cfg.textOf('whSub') == 'personal') {
    final String url = cfg.textOf('whSubUrl').trim();
    if (url.isEmpty) return const <WhiteSource>[];
    return <WhiteSource>[WhiteSource('White', url)];
  }
  return kBuiltinSubscriptions
      .where((String url) => url.trim().isNotEmpty)
      .map((String url) => WhiteSource('White', url))
      .toList();
}

/// The proxy name the WARP hop is given inside the generated configuration.
const String kWarpProxyName = 'aether';
const String kExitGroup = 'exit';

/// The internal port the WARP hop listens on when White is chained through it.
/// The user's own SOCKS address is the one on the home screen, so the hop has
/// to sit somewhere else.
int whiteWarpHopPort(int bindPort) => bindPort == 1818 ? 1816 : 1818;

/// Write the Mihomo configuration for the current White settings.
MihomoPlan buildMihomoConfig(
  VpnConfig cfg, {
  required int socksPort,
  int? httpPort,
  int? warpHopPort,
}) {
  final List<WhiteSource> sources = resolveSources(cfg);
  if (sources.isEmpty) {
    return MihomoPlan(
      yaml: '',
      sources: sources,
      reason: 'هیچ سابسکریپشنی تنظیم نشده است؛ لینک خودتان را در تنظیمات وارد کنید.',
    );
  }

  final bool throughWarp = cfg.textOf('whChain') == 'warp';
  final bool shareOnLan = cfg.boolOf('whShare');
  final String through = throughWarp ? '\n    dialer-proxy: $kWarpProxyName' : '';

  final StringBuffer out = StringBuffer();
  out.writeln('mode: rule');
  out.writeln('log-level: info');
  out.writeln('ipv6: true');
  out.writeln('find-process-mode: off');
  out.writeln('mixed-port: $socksPort');
  if (httpPort != null) out.writeln('port: $httpPort');
  out.writeln('allow-lan: ${shareOnLan ? 'true' : 'false'}');
  if (shareOnLan) {
    out.writeln("bind-address: '*'");
    out.writeln('lan-auth: ${cfg.boolOf('whPass') ? 's4vpn:auto' : 'none'}');
  }

  _writeDns(out, cfg, throughWarp ? kWarpProxyName : null);

  if (throughWarp && warpHopPort != null) {
    out.writeln('proxies:');
    out.writeln('  - {name: $kWarpProxyName, type: socks5, server: 127.0.0.1, '
        'port: $warpHopPort, udp: true}');
    out.writeln();
  }

  final List<String> names = <String>[];
  out.writeln('proxy-providers:');
  for (final WhiteSource source in sources) {
    final String key = providerKey(source.url);
    names.add(key);
    out
      ..writeln('  $key:')
      ..writeln('    type: http')
      ..writeln('    url: ${yamlQuote(source.url)}')
      ..writeln('    interval: 3600')
      ..writeln('    path: ./providers/$key.yaml$through')
      ..writeln('    health-check: {enable: true, url: "http://www.gstatic.com/generate_204", '
          'interval: 300, lazy: true}');
  }
  out.writeln();

  // `auto` picks the fastest tested node on every connect; `manual` parks the
  // group on the node the user chose. Same distinction the settings screen
  // draws between the two.
  final String groupType =
      cfg.textOf('whServerPick') == 'manual' ? 'select' : 'url-test';
  final String? pinned = cfg.textOf('whServerPick') == 'manual' &&
          cfg.textOf('whServer') != 'auto'
      ? cfg.textOf('whServer')
      : null;

  out.writeln('proxy-groups:');
  out.writeln('  - name: $kExitGroup');
  out.writeln('    type: $groupType');
  if (pinned != null) out.writeln('    now: ${yamlQuote(pinned)}');
  if (throughWarp) {
    out.writeln('    proxies: [$kWarpProxyName]');
    out.writeln('    use: [${names.join(', ')}]');
  } else {
    out.writeln('    use: [${names.join(', ')}]');
  }
  out.writeln();

  _writeRules(out, cfg);

  return MihomoPlan(yaml: out.toString(), sources: sources, reason: null);
}

void _writeDns(StringBuffer out, VpnConfig cfg, String? viaProxy) {
  final String via = viaProxy == null ? '' : '#$viaProxy';
  final String custom = cfg.textOf('whDnsAddr').trim();

  final List<String> nameservers = <String>[];
  switch (cfg.textOf('whDns')) {
    case 'doh':
      nameservers.add('${custom.isEmpty ? 'https://1.1.1.1/dns-query' : 'https://$custom/dns-query'}$via');
      nameservers.add('https://dns.google/dns-query$via');
    case 'dot':
      nameservers.add('${custom.isEmpty ? 'tls://1.1.1.1' : 'tls://$custom'}$via');
      nameservers.add('tls://dns.google$via');
    case 'doq':
      // QUIC carries DNS without the round trips TLS pays for, which is the
      // whole reason it is offered: one handshake instead of two.
      nameservers.add('${custom.isEmpty ? 'quic://1.1.1.1' : 'quic://$custom'}$via');
      nameservers.add('quic://dns.google$via');
    case 'auto':
    default:
      nameservers.add('https://1.1.1.1/dns-query$via');
      nameservers.add('https://dns.google/dns-query$via');
  }

  out
    ..writeln('dns:')
    ..writeln('  enable: true')
    ..writeln('  ipv6: true')
    ..writeln('  listen: 0.0.0.0:1053')
    // fake-ip answers instantly from a reserved range and lets the real lookup
    // happen at the far end, where it cannot leak.
    ..writeln('  enhanced-mode: fake-ip')
    ..writeln('  fake-ip-range: 198.19.0.1/16')
    ..writeln('  nameserver:');
  for (final String server in nameservers) {
    out.writeln('    - $server');
  }
  out.writeln();
}

void _writeRules(StringBuffer out, VpnConfig cfg) {
  out.writeln('rules:');

  // Refusals first, so a blocked destination cannot also match a direct rule
  // further down and get dialled anyway.
  for (final String pattern in _ruleLines(cfg.textOf('routeBlock'))) {
    for (final String rule in mihomoRules(pattern, 'REJECT')) {
      out.writeln('  - $rule');
    }
  }
  for (final String pattern in _ruleLines(cfg.textOf('routeDirect'))) {
    for (final String rule in mihomoRules(pattern, 'DIRECT')) {
      out.writeln('  - $rule');
    }
  }

  if (cfg.textOf('whRoute') == 'iran') {
    out.writeln('  - DOMAIN-SUFFIX,ir,DIRECT');
    for (final String domain in kIranBypassDomains) {
      out.writeln('  - DOMAIN-SUFFIX,$domain,DIRECT');
    }
  }

  if (cfg.textOf('whRoute') == 'global') {
    out.writeln('  - MATCH,$kExitGroup');
    return;
  }
  // `sub` leaves the subscription's own rules to do the work by routing
  // everything the app does not already match into the group.
  out.writeln('  - MATCH,$kExitGroup');
}

/// The handful of Iranian destinations `whRoute: iran` sends straight out.
/// Suffixes only: a rule mihomo cannot resolve is one it drops without saying
/// so, and a suffix is resolvable from the name the client already has.
const List<String> kIranBypassDomains = <String>[
  'ir',
  'bankmellat.ir',
  'bpi.ir',
  'shaparak.ir',
  'sep.ir',
  'irannet.ir',
  'irancell.ir',
  'mci.ir',
  'rightel.ir',
  'aptela.com',
  'digikala.com',
  'snapp.ir',
  'tap30.ir',
  'digipay.ir',
  'bale.ir',
  'rubika.ir',
  'eitaa.com',
  'filimo.com',
  'aparat.com',
  'varzesh3.com',
  'digism.ir',
];

List<String> _ruleLines(String raw) => raw
    .split(RegExp(r'[\n,;]'))
    .map((String line) => line.trim())
    .where((String line) => line.isNotEmpty && !line.startsWith('#'))
    .toList();

/// One rule in the app's grammar as Mihomo rules, or empty if it is neither.
///
/// `private` is spelled out as ranges rather than GEOIP,PRIVATE: that wants a
/// database this build does not ship, and an unresolvable rule is dropped
/// silently.
List<String> mihomoRules(String pattern, String action) {
  final String entry = pattern.trim();
  if (entry.isEmpty || entry.startsWith('#')) return const <String>[];

  final int splitAt = entry.indexOf(':');
  final bool hasKind = splitAt > 0 &&
      !entry.substring(0, splitAt).contains('.') &&
      !entry.substring(0, splitAt).contains('/');
  final String kind = hasKind ? entry.substring(0, splitAt).trim().toLowerCase() : '';
  final String value = hasKind ? entry.substring(splitAt + 1).trim() : entry;
  if (value.isEmpty) return const <String>[];

  switch (kind) {
    case 'domain':
    case 'suffix':
      return <String>['DOMAIN-SUFFIX,$value,$action'];
    case 'full':
    case 'exact':
      return <String>['DOMAIN,$value,$action'];
    case 'keyword':
      return <String>['DOMAIN-KEYWORD,$value,$action'];
    case 'regexp':
    case 'regex':
      return <String>['DOMAIN-REGEX,$value,$action'];
    case 'ip':
    case 'cidr':
      return <String>['IP-CIDR,$value,$action,no-resolve'];
    case 'port':
      return <String>['DST-PORT,$value,$action'];
    case 'geoip':
    case 'geosite':
      if (value.toLowerCase() == 'private') return _privateRules(action);
      return const <String>[];
    case '':
      if (value.toLowerCase() == 'private') return _privateRules(action);
      if (value.contains('/')) return <String>['IP-CIDR,$value,$action,no-resolve'];
      return <String>['DOMAIN-SUFFIX,$value,$action'];
    default:
      return const <String>[];
  }
}

List<String> _privateRules(String action) => <String>[
      '10.0.0.0/8',
      '172.16.0.0/12',
      '192.168.0.0/16',
      '169.254.0.0/16',
      '127.0.0.0/8',
    ].map((String cidr) => 'IP-CIDR,$cidr,$action,no-resolve').toList();

/// A provider's name, derived from its URL rather than its position: two
/// different subscriptions must never share a cache file, or the second one is
/// served the first one's nodes until its refresh interval expires.
String providerKey(String url) {
  int hash = 0x811c9dc5;
  for (final int unit in url.trim().codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  final String hex = hash.toRadixString(16).padLeft(8, '0');
  return 'source$hex';
}

/// A YAML double-quoted scalar. A subscription URL may carry `#`, which
/// unquoted starts a comment and truncates the link to whatever came before it.
String yamlQuote(String value) {
  final StringBuffer out = StringBuffer('"');
  for (final int unit in value.codeUnits) {
    if (unit == 0x22 || unit == 0x5C) {
      out.write('\\${String.fromCharCode(unit)}');
    } else if (unit == 0x0A) {
      out.write('\\n');
    } else if (unit == 0x0D) {
      out.write('\\r');
    } else if (unit == 0x09) {
      out.write('\\t');
    } else if (unit < 0x20) {
      out.write('\\x${unit.toRadixString(16).padLeft(2, '0')}');
    } else {
      out.writeCharCode(unit);
    }
  }
  out.write('"');
  return out.toString();
}

/// Latencies the White server list shows, jittered the way the preview's
/// re-test does: enough movement to prove the button did something, never
/// enough to be mistaken for a measurement.
List<WhiteServer> retestServers(List<WhiteServer> servers, int Function(int) jitter) =>
    servers
        .map((WhiteServer server) =>
            server.copyWith(latency: (server.latency + jitter(server.latency)).clamp(38, 400)))
        .toList();

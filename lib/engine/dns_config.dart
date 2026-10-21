import '../models/vpn_config.dart';

/// The DNS engine: WhiteDNS's tunnelling client, driven the same way its own
/// app drives it.
///
/// WhiteDNS renders a TOML config file and a resolver list next to the core
/// binary and starts it with `-config <file> -resolvers <file>`. The binary
/// then serves a local SOCKS5 on the address the settings chose, which is
/// exactly the shape every other engine in this app ends in.
class DnsPlanFile {
  const DnsPlanFile({required this.name, required this.contents});

  final String name;
  final String contents;
}

/// What to start for the DNS engine.
class DnsPlan {
  const DnsPlan({
    required this.args,
    required this.files,
    required this.socksPort,
    required this.httpPort,
    this.reason,
  });

  final List<String> args;
  final List<DnsPlanFile> files;

  /// The local SOCKS5 the core serves once it is up.
  final int socksPort;
  final int? httpPort;

  /// Set when the profile cannot run; the home screen shows the message.
  final String? reason;

  bool get ok => reason == null;
}

String _t(VpnConfig cfg, String key) => cfg.textOf(key).trim();

String _escape(String value) =>
    value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

/// The two-letter engine key the settings carry (`storm` / `cotten`).
String dnsEngineOf(VpnConfig cfg) =>
    cfg.textOf('dnsEngine') == 'cotten' ? 'cotten' : 'storm';

/// The resolver file: every non-empty line. WhiteDNS accepts one resolver (or
/// a list) per line -- an empty profile means the server section carries none
/// and the core scans by itself.
String renderResolvers(VpnConfig cfg) {
  final String text = _t(cfg, 'dnsResolverText');
  return text
      .split(RegExp(r'[\n,]'))
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .join('\n');
}

/// The TOML, in the same key order the WhiteDNS renderer writes it.
String renderDnsToml(VpnConfig cfg) {
  final String domain = _t(cfg, 'dnsDomain');
  final String key = _t(cfg, 'dnsKey');
  final int encMethod = int.tryParse(_t(cfg, 'dnsEncMethod'))?.clamp(0, 5) ?? 1;

  final String listenIp =
      _t(cfg, 'dnsListenIp').isEmpty ? '127.0.0.1' : _t(cfg, 'dnsListenIp');
  final int listenPort = int.tryParse(_t(cfg, 'dnsListenPort')) ?? 10886;
  final int? httpPort = cfg.boolOf('dnsHttpEnabled')
      ? int.tryParse(_t(cfg, 'dnsHttpPort')) ?? 10887
      : null;

  String num(String key, String fallback) {
    final String v = _t(cfg, key);
    return v.isEmpty ? fallback : v;
  }

  String url(String key, String fallback) {
    final String v = _t(cfg, key);
    return v.isEmpty ? fallback : _escape(v);
  }

  final StringBuffer toml = StringBuffer()
    ..writeln('DOMAINS = ["${_escape(domain)}"]')
    ..writeln('DATA_ENCRYPTION_METHOD = $encMethod')
    ..writeln('ENCRYPTION_KEY = "${_escape(key)}"')
    ..writeln(
        'PROTOCOL_TYPE = "${url('dnsProtocol', 'SOCKS5')}"')
    ..writeln('LISTEN_IP = "${_escape(listenIp)}"')
    ..writeln('LISTEN_PORT = $listenPort')
    ..writeln('HTTP_PROXY_ENABLED = ${httpPort != null}')
    ..writeln('HTTP_PROXY_PORT = ${httpPort ?? 0}')
    ..writeln('SOCKS5_AUTH = ${cfg.boolOf('dnsSockAuth')}')
    ..writeln('SOCKS5_USER = "${url('dnsSockUser', 'master_dns_vpn')}"')
    ..writeln('SOCKS5_PASS = "${url('dnsSockPass', 'master_dns_vpn')}"')
    ..writeln('LOCAL_DNS_ENABLED = ${cfg.boolOf('dnsLocalDns')}')
    ..writeln('LOCAL_DNS_IP = "127.0.0.1"')
    ..writeln(
        'LOCAL_DNS_PORT = ${int.tryParse(_t(cfg, 'dnsLocalDnsPort')) ?? 53}')
    ..writeln(
        'RESOLVER_BALANCING_STRATEGY = ${int.tryParse(_t(cfg, 'dnsBalancing')) ?? 3}')
    ..writeln('UPLOAD_PACKET_DUPLICATION_COUNT = ${num('dnsDupUp', '3')}')
    ..writeln('DOWNLOAD_PACKET_DUPLICATION_COUNT = ${num('dnsDupDown', '7')}')
    ..writeln(
        'UPLOAD_COMPRESSION_TYPE = ${int.tryParse(_t(cfg, 'dnsCompUp')) ?? 2}')
    ..writeln(
        'DOWNLOAD_COMPRESSION_TYPE = ${int.tryParse(_t(cfg, 'dnsCompDown')) ?? 2}')
    ..writeln('BASE_ENCODE_DATA = ${cfg.boolOf('dnsBaseEncode')}')
    ..writeln('MIN_UPLOAD_MTU = ${num('dnsMinUpMtu', '40')}')
    ..writeln('MIN_DOWNLOAD_MTU = ${num('dnsMinDownMtu', '300')}')
    ..writeln('MAX_UPLOAD_MTU = ${num('dnsMaxUpMtu', '140')}')
    ..writeln('MAX_DOWNLOAD_MTU = ${num('dnsMaxDownMtu', '3000')}')
    ..writeln(
        'MTU_TEST_RETRIES_RESOLVERS = ${num('dnsMtuRetriesResolvers', '3')}')
    ..writeln(
        'MTU_TEST_TIMEOUT_RESOLVERS = ${num('dnsMtuTimeoutResolvers', '2.5')}')
    ..writeln(
        'MTU_TEST_PARALLELISM_RESOLVERS = ${num('dnsMtuParallelismResolvers', '100')}')
    ..writeln('MTU_TEST_RETRIES_LOGS = ${num('dnsMtuRetriesLogs', '5')}')
    ..writeln('MTU_TEST_TIMEOUT_LOGS = ${num('dnsMtuTimeoutLogs', '2.5')}')
    ..writeln(
        'MTU_TEST_PARALLELISM_LOGS = ${num('dnsMtuParallelismLogs', '32')}')
    ..writeln('RX_TX_WORKERS = ${num('dnsRxTxWorkers', '4')}')
    ..writeln('TUNNEL_PROCESS_WORKERS = ${num('dnsTunnelWorkers', '4')}')
    ..writeln('TUNNEL_PACKET_TIMEOUT_SECONDS = ${num('dnsPacketTimeout', '10.0')}')
    ..writeln(
        'DISPATCHER_IDLE_POLL_INTERVAL_SECONDS = ${num('dnsIdlePoll', '0.020')}')
    ..writeln('TX_CHANNEL_SIZE = ${num('dnsTxChannel', '2048')}')
    ..writeln('RX_CHANNEL_SIZE = ${num('dnsRxChannel', '2048')}')
    ..writeln(
        'RESOLVER_UDP_CONNECTION_POOL_SIZE = ${num('dnsResolverPool', '64')}')
    ..writeln('STREAM_QUEUE_INITIAL_CAPACITY = ${num('dnsStreamQueue', '128')}')
    ..writeln(
        'ORPHAN_QUEUE_INITIAL_CAPACITY = ${num('dnsOrphanQueue', '32')}')
    ..writeln(
        'DNS_RESPONSE_FRAGMENT_STORE_CAPACITY = ${num('dnsFragmentStore', '256')}')
    ..writeln('MAX_ACTIVE_STREAMS = ${num('dnsMaxStreams', '2048')}')
    ..writeln(
        'LOCAL_HANDSHAKE_TIMEOUT_SECONDS = ${num('dnsHandshakeTimeout', '5.0')}')
    ..writeln(
        'SOCKS_UDP_ASSOCIATE_READ_TIMEOUT_SECONDS = ${num('dnsUdpAssociateTimeout', '30.0')}')
    ..writeln(
        'CLIENT_TERMINAL_STREAM_RETENTION_SECONDS = ${num('dnsStreamRetention', '45.0')}')
    ..writeln(
        'CLIENT_CANCELLED_SETUP_RETENTION_SECONDS = ${num('dnsCancelledRetention', '120.0')}')
    ..writeln('SESSION_INIT_RETRY_BASE_SECONDS = ${num('dnsRetryBase', '1.0')}')
    ..writeln('SESSION_INIT_RETRY_STEP_SECONDS = ${num('dnsRetryStep', '1.0')}')
    ..writeln(
        'SESSION_INIT_RETRY_LINEAR_AFTER = ${num('dnsRetryLinearAfter', '5')}')
    ..writeln('SESSION_INIT_RETRY_MAX_SECONDS = ${num('dnsRetryMax', '60.0')}')
    ..writeln(
        'SESSION_INIT_BUSY_RETRY_INTERVAL_SECONDS = ${num('dnsBusyRetry', '60.0')}')
    ..writeln(
        'STARTUP_MODE = "${url('dnsStartupMode', 'resolvers')}"')
    ..writeln('LOG_SCAN_MAX_DAYS = 14')
    ..writeln('LOG_SCAN_MAX_RESOLVERS = 128')
    ..writeln('LOG_BASED_MTU_VERIFY = true')
    ..writeln('STATS_REPORT_INTERVAL_SECONDS = 1.0')
    ..writeln('PING_WATCHDOG_TIMEOUT_SECONDS = ${num('dnsWatchdog', '300')}')
    ..writeln('TRAFFIC_WARMUP_ENABLED = ${cfg.boolOf('dnsWarmup')}')
    ..writeln(
        'TRAFFIC_WARMUP_PROBE_COUNT = ${num('dnsWarmupProbes', '4')}')
    ..writeln(
        'TRAFFIC_KEEPALIVE_INTERVAL_SECONDS = ${num('dnsKeepalive', '5')}')
    ..writeln('AUTO_TUNE_ENABLED = ${cfg.boolOf('dnsAutoTune')}')
    ..writeln('LOG_LEVEL = "${url('dnsLogLevel', 'WARN')}"')
    ..writeln('LOG_TO_FILE = true')
    ..writeln('LOG_DIR = "logs"');

  return toml.toString();
}

/// Everything the supervisor needs to run the DNS core.
DnsPlan buildDnsPlan(VpnConfig cfg) {
  if (_t(cfg, 'dnsDomain').isEmpty) {
    return const DnsPlan(
      args: <String>[],
      files: <DnsPlanFile>[],
      socksPort: 0,
      httpPort: null,
      reason: 'دامنه سرور DNS را وارد کنید',
    );
  }
  if (_t(cfg, 'dnsKey').isEmpty) {
    return const DnsPlan(
      args: <String>[],
      files: <DnsPlanFile>[],
      socksPort: 0,
      httpPort: null,
      reason: 'کلید رمزنگاری سرور DNS را وارد کنید',
    );
  }

  final int listenPort = int.tryParse(_t(cfg, 'dnsListenPort')) ?? 10886;
  final int? httpPort = cfg.boolOf('dnsHttpEnabled')
      ? int.tryParse(_t(cfg, 'dnsHttpPort')) ?? 10887
      : null;

  return DnsPlan(
    args: <String>[
      '-config',
      '<s4vpn-dns.toml>',
      '-resolvers',
      '<s4vpn-resolvers.list>',
    ],
    files: <DnsPlanFile>[
      DnsPlanFile(name: 's4vpn-dns.toml', contents: renderDnsToml(cfg)),
      DnsPlanFile(name: 's4vpn-resolvers.list', contents: renderResolvers(cfg)),
    ],
    socksPort: listenPort,
    httpPort: httpPort,
  );
}

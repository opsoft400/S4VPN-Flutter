import 'package:flutter_test/flutter_test.dart';
import 'package:s4vpn/engine/dns_config.dart';
import 'package:s4vpn/models/vpn_config.dart';

void main() {
  test('an empty server profile refuses to connect', () {
    final VpnConfig cfg = VpnConfig.defaults()..set('engine', 'dns');
    final DnsPlan plan = buildDnsPlan(cfg);
    expect(plan.ok, isFalse);
    expect(plan.reason, isNotNull);
  });

  test('the plan carries the config and resolver files to the core', () {
    final VpnConfig cfg = VpnConfig.defaults()
      ..set('engine', 'dns')
      ..set('dnsDomain', 'tun.example.com')
      ..set('dnsKey', 'k3y');
    final DnsPlan plan = buildDnsPlan(cfg);
    expect(plan.ok, isTrue);
    expect(plan.socksPort, 10886);
    expect(
      plan.files.map((DnsPlanFile f) => f.name).toSet(),
      <String>{'s4vpn-dns.toml', 's4vpn-resolvers.list'},
    );
    expect(plan.files.first.contents, contains('tun.example.com'));
    expect(plan.files.first.contents, contains('k3y'));
  });

  test('the TOML matches the WhiteDNS renderer, key for key', () {
    final VpnConfig cfg = VpnConfig.defaults()
      ..set('engine', 'dns')
      ..set('dnsDomain', 'tun.example.com')
      ..set('dnsKey', 'k3y')
      ..set('dnsEncMethod', '2')
      ..set('dnsBalancing', '4');

    final String toml = renderDnsToml(cfg);
    final List<String> keys = toml
        .split('\n')
        .map((String line) => line.split('=').first.trim())
        .toList();

    const List<String> expected = <String>[
      'DOMAINS',
      'DATA_ENCRYPTION_METHOD',
      'ENCRYPTION_KEY',
      'PROTOCOL_TYPE',
      'LISTEN_IP',
      'LISTEN_PORT',
      'HTTP_PROXY_ENABLED',
      'HTTP_PROXY_PORT',
      'SOCKS5_AUTH',
      'SOCKS5_USER',
      'SOCKS5_PASS',
      'LOCAL_DNS_ENABLED',
      'LOCAL_DNS_IP',
      'LOCAL_DNS_PORT',
      'RESOLVER_BALANCING_STRATEGY',
      'UPLOAD_PACKET_DUPLICATION_COUNT',
      'DOWNLOAD_PACKET_DUPLICATION_COUNT',
      'UPLOAD_COMPRESSION_TYPE',
      'DOWNLOAD_COMPRESSION_TYPE',
      'BASE_ENCODE_DATA',
      'MIN_UPLOAD_MTU',
      'MIN_DOWNLOAD_MTU',
      'MAX_UPLOAD_MTU',
      'MAX_DOWNLOAD_MTU',
      'MTU_TEST_RETRIES_RESOLVERS',
      'MTU_TEST_TIMEOUT_RESOLVERS',
      'MTU_TEST_PARALLELISM_RESOLVERS',
      'MTU_TEST_RETRIES_LOGS',
      'MTU_TEST_TIMEOUT_LOGS',
      'MTU_TEST_PARALLELISM_LOGS',
      'RX_TX_WORKERS',
      'TUNNEL_PROCESS_WORKERS',
      'TUNNEL_PACKET_TIMEOUT_SECONDS',
      'DISPATCHER_IDLE_POLL_INTERVAL_SECONDS',
      'TX_CHANNEL_SIZE',
      'RX_CHANNEL_SIZE',
      'RESOLVER_UDP_CONNECTION_POOL_SIZE',
      'STREAM_QUEUE_INITIAL_CAPACITY',
      'ORPHAN_QUEUE_INITIAL_CAPACITY',
      'DNS_RESPONSE_FRAGMENT_STORE_CAPACITY',
      'MAX_ACTIVE_STREAMS',
      'LOCAL_HANDSHAKE_TIMEOUT_SECONDS',
      'SOCKS_UDP_ASSOCIATE_READ_TIMEOUT_SECONDS',
      'CLIENT_TERMINAL_STREAM_RETENTION_SECONDS',
      'CLIENT_CANCELLED_SETUP_RETENTION_SECONDS',
      'SESSION_INIT_RETRY_BASE_SECONDS',
      'SESSION_INIT_RETRY_STEP_SECONDS',
      'SESSION_INIT_RETRY_LINEAR_AFTER',
      'SESSION_INIT_RETRY_MAX_SECONDS',
      'SESSION_INIT_BUSY_RETRY_INTERVAL_SECONDS',
      'STARTUP_MODE',
      'PING_WATCHDOG_TIMEOUT_SECONDS',
      'TRAFFIC_WARMUP_ENABLED',
      'TRAFFIC_WARMUP_PROBE_COUNT',
      'TRAFFIC_KEEPALIVE_INTERVAL_SECONDS',
      'AUTO_TUNE_ENABLED',
      'LOG_LEVEL',
      'LOG_TO_FILE',
      'LOG_DIR',
    ];
    for (final String key in expected) {
      expect(keys, contains(key), reason: 'missing TOML key: $key');
    }

    expect(toml, contains('DOMAINS = ["tun.example.com"]'));
    expect(toml, contains('DATA_ENCRYPTION_METHOD = 2'));
    expect(toml, contains('RESOLVER_BALANCING_STRATEGY = 4'));
    expect(toml, contains('PROTOCOL_TYPE = "SOCKS5"'));
  });

  test('resolvers keep one per line and drop blanks', () {
    final VpnConfig cfg = VpnConfig.defaults()
      ..set('engine', 'dns')
      ..set('dnsResolverText', ' 1.2.3.4:53 \n\n 5.6.7.8:1053');
    expect(renderResolvers(cfg), '1.2.3.4:53\n5.6.7.8:1053');
  });
}

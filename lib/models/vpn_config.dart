/// The settings model.
///
/// One flat map of user-visible keys, exactly the shape the preview keeps in
/// its `cfg` object: the settings screen writes straight into it, the engine
/// planners read straight out of it, and there is no second copy to drift.
///
/// The defaults are the preview's defaults. If one of them looks surprising,
/// the preview is the specification, not this file.
class VpnConfig {
  VpnConfig._(this.values);

  factory VpnConfig.defaults() => VpnConfig._(Map<String, Object?>.from(kDefaults));

  /// Deep copy, used for reset and for the "apply on next connect" snapshot.
  factory VpnConfig.from(VpnConfig other) =>
      VpnConfig._(Map<String, Object?>.from(other.values));

  final Map<String, Object?> values;

  Object? operator [](String key) => values[key];

  void set(String key, Object? value) => values[key] = value;

  String textOf(String key) {
    final Object? v = values[key];
    return v == null ? '' : v.toString();
  }

  bool boolOf(String key) {
    final Object? v = values[key];
    if (v == true) return true;
    if (v == false) return false;
    final String s = v.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  int intOf(String key, {int fallback = 0}) {
    final int? parsed = int.tryParse(textOf(key).trim());
    return parsed ?? fallback;
  }

  double doubleOf(String key, {double fallback = 0}) {
    final double? parsed = double.tryParse(textOf(key).trim());
    return parsed ?? fallback;
  }

  /// Every key, with its default, so a settings control can bind by key alone.
  static const Map<String, Object?> kDefaults = <String, Object?>{
    'engine': 'aether',
    // WARP / Aether tunnel
    'transport': 'masque',
    'scan': 'balanced',
    'noize': 'firewall',
    'ip': '4',
    'peer': '',
    'wiwOuter': '',
    'wiwInner': '',
    'mimOuter': '',
    'mimInner': '',
    'quick': true,
    'carrier': 'h3',
    'quicV2': true,
    'h2Peer': '',
    'fragment': false,
    'fragSize': '16-32',
    'fragDelay': '2-10',
    'ech': false,
    'keepalive': '5',
    'noRetry': false,
    'dataCheck': true,
    'validateSecs': '10',
    'startupSecs': '30',
    'reconnectSecs': '2',
    'dns': '1.1.1.1,1.0.0.1',
    // Psiphon
    'psWay': 'only',
    'psShape': 'auto',
    'psRegion': '',
    'psCdnIps': '',
    'psCdnSni': '',
    'psBind': '127.0.0.1:1821',
    'psHttp': '',
    'psConfig': '',
    'psDir': '',
    'psBin': '',
    // Tor
    'torWay': 'only',
    'torBridges': 'auto',
    'torBridgeLines': '',
    'torBridgeFile': '',
    'torPt': '',
    'torPtDir': '',
    'torRelays': 'auto',
    'torRelayCount': '',
    'torRelayPorts': 'web',
    'torBind': '127.0.0.1:1820',
    'torHttp': '',
    'torDir': '',
    // local proxies, exit, upstream
    'bind': '127.0.0.1:1819',
    'httpOn': false,
    'httpAddr': '127.0.0.1:1822',
    'exitLoc': '',
    'exitLocSecs': '60',
    'upstream': '',
    'mark': '',
    // routing
    'routeBlock': '',
    'routeDirect': '',
    'routeSniff': true,
    'routeSniffMs': '400',
    // White (WhiteVPN-style Mihomo core)
    'whSub': 'builtin',
    'whSubUrl': '',
    // DNS (WhiteDNS tunnelling client: StormDNS / CottenDNS)
    'dnsEngine': 'storm',
    'dnsDomain': '',
    'dnsKey': '',
    'dnsEncMethod': '1',
    'dnsConnMode': 'proxy',
    'dnsProtocol': 'SOCKS5',
    'dnsResolverText': '',
    'dnsListenIp': '127.0.0.1',
    'dnsListenPort': '10886',
    'dnsHttpEnabled': true,
    'dnsHttpPort': '10887',
    'dnsSockAuth': false,
    'dnsSockUser': 'master_dns_vpn',
    'dnsSockPass': 'master_dns_vpn',
    'dnsBalancing': '3',
    'dnsDupUp': '3',
    'dnsDupDown': '7',
    'dnsCompUp': '2',
    'dnsCompDown': '2',
    'dnsBaseEncode': false,
    'dnsMinUpMtu': '40',
    'dnsMinDownMtu': '300',
    'dnsMaxUpMtu': '140',
    'dnsMaxDownMtu': '3000',
    'dnsMtuRetriesResolvers': '3',
    'dnsMtuTimeoutResolvers': '2.5',
    'dnsMtuParallelismResolvers': '100',
    'dnsMtuRetriesLogs': '5',
    'dnsMtuTimeoutLogs': '2.5',
    'dnsMtuParallelismLogs': '32',
    'dnsRxTxWorkers': '4',
    'dnsTunnelWorkers': '4',
    'dnsPacketTimeout': '10.0',
    'dnsIdlePoll': '0.020',
    'dnsTxChannel': '2048',
    'dnsRxChannel': '2048',
    'dnsResolverPool': '64',
    'dnsStreamQueue': '128',
    'dnsOrphanQueue': '32',
    'dnsFragmentStore': '256',
    'dnsMaxStreams': '2048',
    'dnsHandshakeTimeout': '5.0',
    'dnsUdpAssociateTimeout': '30.0',
    'dnsStreamRetention': '45.0',
    'dnsCancelledRetention': '120.0',
    'dnsRetryBase': '1.0',
    'dnsRetryStep': '1.0',
    'dnsRetryLinearAfter': '5',
    'dnsRetryMax': '60.0',
    'dnsBusyRetry': '60.0',
    'dnsLocalDns': false,
    'dnsLocalDnsPort': '53',
    'dnsStartupMode': 'resolvers',
    'dnsWatchdog': '300',
    'dnsWarmup': false,
    'dnsWarmupProbes': '4',
    'dnsKeepalive': '5',
    'dnsAutoTune': true,
    'dnsLogLevel': 'WARN',
    'dnsSplit': 'off',
    'dnsSplitCount': '0',
    'whServerPick': 'auto',
    'whServer': 'auto',
    'whSort': 'low',
    'whRoute': 'sub',
    'whDns': 'auto',
    'whDnsAddr': '',
    'whChain': 'direct',
    'whNoise': 'off',
    'whFronting': '',
    'whSplit': 'off',
    'whSplitCount': '0',
    'whShare': false,
    'whPass': false,
    'whClean': true,
    'whLan': true,
    // zero trust
    'team': '',
    'ztMethod': 'email',
    'ztEmail': '',
    'ztId': '',
    'ztSecret': '',
    'ztJwt': '',
    'gateway': false,
    // limits, stats, identity
    'maxClients': '',
    'halfClose': '30',
    'tcpKeepalive': '60',
    'tcpConnect': '30',
    'perf': 'medium',
    'stats': true,
    'statsSecs': '60',
    'reprovision': true,
    // Rewards / Premium
    'rewardCredits': 0,
    'totalEarned': 0,
    'totalSpent': 0,
    'premiumExpiry': 0,
    'codeUsed': false,
    'premiumActivated': false,
    'code': '',
  };
}
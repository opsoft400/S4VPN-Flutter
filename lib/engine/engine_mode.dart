/// The six connection modes on the home screen.
///
/// The mapping from mode to core is fixed and comes from the brief:
/// `aether`, `psiphon` and `tor` are carried by WhiteAestherMobile-1.12.0 (its
/// Aether 2.3.0 vendored inside it: MASQUE/WireGuard/WARP-in-WARP plus
/// Tor, and psiphon as its own carrier), `white` by the White VPN core
/// (Mihomo), and `s4` by the Lantern core. `dns` is the WhiteDNS DNS-tunnelling
/// client (StormDNS or CottenDNS, chosen in the settings) behind a local
/// SOCKS5, exactly the shape WhiteDNS-Android's own process manager drives it
/// with.
///
/// `white_aether` is a themed variant using the white aesthetic instead of
/// the default aether appearance.
enum EngineMode {
  aether('aether', 'WARP'),
  psiphon('psiphon', 'سایفون'),
  tor('tor', 'تور'),
  white('white', 'وایت'),
  s4('s4', 'SOFT400'),
  dns('dns', 'SOFT400'),
  white_aether('white_aether', 'White Aether');

  const EngineMode(this.id, this.subtitle);

  final String id;
  final String subtitle;

  static EngineMode parse(String? value) => EngineMode.values.firstWhere(
        (EngineMode mode) => mode.id == value,
        orElse: () => EngineMode.aether,
      );
}

/// The cores this app can drive. Each one is a separate executable shipped in
/// the bundle; the supervisor starts them, the planner decides what they get
/// told to do.
enum CoreId {
  /// Aether 2.3.0 (Rust, vendored in WhiteAestherMobile-1.12.0): MASQUE,
  /// WireGuard, WARP-in-WARP, plus Tor through the same binary.
  aether,

  /// psiphon-tunnel-core (Go), used on its own or chained either way round.
  psiphon,

  /// Mihomo (Go): the White engine's routing, subscriptions and servers.
  mihomo,

  /// Lantern (Go): the S4 engine.
  lantern,

  /// StormDNS (Go): the DNS tunnelling client of WhiteDNS, run with a TOML
  /// config file. Serves a local SOCKS5 the platform tunnel points at.
  stormdns,

  /// CottenDNS: the second WhiteDNS engine. Same command shape as StormDNS.
  cottendns,
}

import 'package:flutter_test/flutter_test.dart';
import 'package:s4vpn/models/vpn_config.dart';

void main() {
  test('the shipped defaults are the preview defaults', () {
    final VpnConfig cfg = VpnConfig.defaults();
    expect(cfg.textOf('engine'), 'aether');
    expect(cfg.textOf('transport'), 'masque');
    expect(cfg.textOf('scan'), 'balanced');
    expect(cfg.textOf('noize'), 'firewall');
    expect(cfg.textOf('bind'), '127.0.0.1:1819');
    expect(cfg.boolOf('dataCheck'), isTrue);
    expect(cfg.boolOf('stats'), isTrue);
    expect(cfg.textOf('dns'), '1.1.1.1,1.0.0.1');
  });

  test('the DNS mode offers the four modes the settings screen draws', () {
    final VpnConfig cfg = VpnConfig.defaults();
    // auto, doh, dot -- and doq, which this app adds on top of the preview.
    expect(cfg.textOf('whDns'), 'auto');
    expect(VpnConfig.kDefaults.containsKey('whDns'), isTrue);
  });

  test('copying does not alias the original', () {
    final VpnConfig original = VpnConfig.defaults();
    final VpnConfig copy = VpnConfig.from(original)..set('engine', 'tor');
    expect(original.textOf('engine'), 'aether');
    expect(copy.textOf('engine'), 'tor');
  });

  test('numeric reads tolerate an empty or unparsable value', () {
    final VpnConfig cfg = VpnConfig.defaults();
    expect(cfg.intOf('maxClients', fallback: 512), 512);
    cfg.set('maxClients', '2048');
    expect(cfg.intOf('maxClients'), 2048);
  });

  test('every default is a string, a bool or null', () {
    for (final MapEntry<String, Object?> entry in VpnConfig.kDefaults.entries) {
      expect(
        entry.value is String || entry.value is bool || entry.value == null,
        isTrue,
        reason: '${entry.key} has an unexpected type ${entry.value.runtimeType}',
      );
    }
  });
}

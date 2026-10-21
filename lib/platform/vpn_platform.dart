import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// The seam between the Dart app and whatever owns the device's packets.
///
/// On Android that is a `VpnService`: it builds the interface, points it at
/// the local proxy the cores opened, and is the only thing allowed to ask the
/// system to route traffic. On Windows and Linux there is no such object --
/// the cores already listen locally, so the desktop half of this class is
/// configuration and process plumbing rather than a tunnel.
class VpnPlatform {
  VpnPlatform._();

  static const MethodChannel channel = MethodChannel('s4vpn/platform');
  static final VpnPlatform instance = VpnPlatform._();

  static bool get _isAndroid => Platform.isAndroid;

  /// Where an engine executable was unpacked, when the platform had to do the
  /// unpacking. Android will only leave an executable where it can exec it, so
  /// the Kotlin side copies it there and hands the path back.
  Future<String?> corePath(String coreName) async {
    if (!_isAndroid) return null;
    final Object? result =
        await channel.invokeMethod<String>('corePath', <String, Object?>{'core': coreName});
    return result as String?;
  }

  /// Ask the system for a tunnel pointing at [socksPort].
  ///
  /// [excludedPackages] carries the split-tunnel choice: in `bypass` mode the
  /// named apps stay outside the tunnel, in `vpnonly` mode only they enter it,
  /// and in `off` mode the list is empty and the whole device is covered.
  Future<void> startVpn({
    required int socksPort,
    int? httpPort,
    required String mode,
    List<String> excludedPackages = const <String>[],
    List<String> allowedPackages = const <String>[],
  }) async {
    if (!_isAndroid) return;
    await channel.invokeMethod<void>('startVpn', <String, Object?>{
      'socksPort': socksPort,
      'httpPort': httpPort,
      'mode': mode,
      'excludedPackages': excludedPackages,
      'allowedPackages': allowedPackages,
    });
  }

  Future<void> stopVpn() async {
    if (!_isAndroid) return;
    await channel.invokeMethod<void>('stopVpn');
  }

  Future<bool> isVpnActive() async {
    if (!_isAndroid) return false;
    final Object? result = await channel.invokeMethod<bool>('isVpnActive');
    return result == true;
  }

  /// The directory settings and core state are kept in.
  Future<String> stateDirectory() async {
    if (_isAndroid) {
      final Object? result = await channel.invokeMethod<String>('stateDir');
      if (result is String && result.isNotEmpty) return result;
    }
    final String exeDir = File(Platform.resolvedExecutable).parent.path;
    final String dir = '$exeDir${Platform.pathSeparator}data';
    Directory(dir).createSync(recursive: true);
    return dir;
  }

  Future<Map<String, Object?>> loadState() async {
    try {
      final String dir = await stateDirectory();
      final File file = File('$dir${Platform.pathSeparator}settings.json');
      if (!file.existsSync()) return <String, Object?>{};
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) return decoded;
      if (decoded is Map) return decoded.cast<String, Object?>();
    } on Exception {
      // A missing or corrupt file must not stop the app from opening; the
      // defaults are always available.
    }
    return <String, Object?>{};
  }

  Future<void> saveState(Map<String, Object?> state) async {
    try {
      final String dir = await stateDirectory();
      final File file = File('$dir${Platform.pathSeparator}settings.json');
      await file.writeAsString(jsonEncode(state), flush: true);
    } on Exception {
      // Losing a preference is better than losing the session.
    }
  }
}

/// Byte counters read from the tunnel interface, when there is one.
class Traffic {
  const Traffic({required this.rx, required this.tx});

  final int rx;
  final int tx;
}

/// Counters from the tunnel interface, or null where there is no interface to
/// count. Desktop cores do not expose one, so the readout says so rather than
/// inventing numbers.
Future<Traffic?> readTraffic() async {
  if (!Platform.isAndroid) return null;
  try {
    final Object? result = await VpnPlatform.channel
        .invokeMethod<Map<Object?, Object?>>('traffic');
    if (result is Map) {
      final int rx = (result['rx'] as num?)?.toInt() ?? 0;
      final int tx = (result['tx'] as num?)?.toInt() ?? 0;
      return Traffic(rx: rx, tx: tx);
    }
  } on Exception {
    return null;
  }
  return null;
}

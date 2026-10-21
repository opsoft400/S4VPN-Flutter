import 'dart:io';

import 'engine_mode.dart';
import '../platform/vpn_platform.dart';

/// Where an engine's executable lives.
///
/// Cores are not part of the Dart build: they arrive either next to the
/// application (desktop) or as a library-shaped binary the platform extracts
/// for us (Android, which will only leave an executable where it can exec it).
/// This resolves both, and only then falls back to `PATH`, so a missing core
/// is reported as *this* core rather than as a shell's "command not found".
class CoreLocator {
  CoreLocator({VpnPlatform? platform}) : _platform = platform ?? VpnPlatform.instance;

  final VpnPlatform _platform;

  static const Map<CoreId, String> executableNames = <CoreId, String>{
    CoreId.aether: 'aether',
    CoreId.psiphon: 'psiphon-tunnel-core',
    CoreId.mihomo: 'mihomo',
    CoreId.lantern: 'lantern',
    CoreId.stormdns: 'stormdns',
    CoreId.cottendns: 'cottendns',
  };

  /// The asset directory names inside `native/engines`, used by the scripts
  /// that unpack cores before a build.
  static const Map<CoreId, String> sourceArchives = <CoreId, String>{
    CoreId.aether: 'WhiteAestherMobile-1.12.0.zip',
    CoreId.psiphon: 'WhiteAestherMobile-1.12.0.zip',
    CoreId.mihomo: 'v1.11.0-whitevpn.zip',
    CoreId.lantern: 'v10.0.0-lant.zip',
    CoreId.stormdns: 'WhiteDNS-Android-1.6.0.zip',
    CoreId.cottendns: 'WhiteDNS-Android-1.6.0.zip',
  };

  String _fileName(CoreId core) {
    final String base = executableNames[core]!;
    return Platform.isWindows ? '$base.exe' : base;
  }

  /// Absolute path to the core, or null when it is not installed anywhere we
  /// looked. The caller turns that into a message naming the core.
  Future<String?> resolve(CoreId core) async {
    // 1. The platform knows best: Android extracts jniLibs for us, and the
    //    Kotlin side copies the one we asked for somewhere executable.
    try {
      final String? fromPlatform = await _platform.corePath(core.name);
      if (fromPlatform != null && fromPlatform.isNotEmpty) {
        final File file = File(fromPlatform);
        if (file.existsSync()) return fromPlatform;
      }
    } on Exception {
      // A desktop platform has no such channel; carry on with the filesystem.
    }

    // 2. Beside the application, in the layout tool/prepare_cores.sh produces.
    final String exeDir = File(Platform.resolvedExecutable).parent.path;
    final List<String> candidates = <String>[
      _path(exeDir, 'cores', _fileName(core)),
      _path(exeDir, _fileName(core)),
      _path(Directory.current.path, 'cores', _fileName(core)),
    ];
    for (final String candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }

    // 3. Whatever is on PATH.
    final String? onPath = _which(executableNames[core]!);
    if (onPath != null) return onPath;

    return null;
  }

  /// Where a core should keep its identity and state. Keeping this beside the
  /// executable rather than in a temp directory is deliberate: a lost identity
  /// means registering a new device on every boot, which Cloudflare rate
  /// limits.
  String dataDirectory(CoreId core) {
    final String exeDir = File(Platform.resolvedExecutable).parent.path;
    final String dir = _path(exeDir, 'data', core.name);
    Directory(dir).createSync(recursive: true);
    return dir;
  }

  static String _path(String a, String b, [String c = '']) =>
      c.isEmpty ? '$a${Platform.pathSeparator}$b' : '$a${Platform.pathSeparator}$b${Platform.pathSeparator}$c';
  static String? _which(String name) {
    final String? path = Platform.environment['PATH'];
    if (path == null) return null;
    for (final String dir in path.split(Platform.pathSeparator)) {
      if (dir.isEmpty) continue;
      final String candidate = '$dir${Platform.pathSeparator}$name';
      final File file = File(candidate);
      if (file.existsSync()) return candidate;
    }
    return null;
  }
}

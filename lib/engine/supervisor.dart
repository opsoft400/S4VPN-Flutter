import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'core_locator.dart';
import 'engine_mode.dart';
import 'plan.dart';

/// One line a core printed.
class CoreLog {
  const CoreLog(this.core, this.line, {this.error = false});

  final CoreId? core;
  final String line;
  final bool error;

  @override
  String toString() => '${core?.name ?? 'app'}: $line';
}

/// Starts engine processes, watches them, and stops them.
///
/// A core is a separate program with its own idea of when it is ready, so
/// [start] does not return on "process spawned" -- it returns once something is
/// listening on the port the settings asked for, or once it can say why not.
/// That difference is the whole point: a tunnel that has not come up and a
/// tunnel that never tried must not look the same on screen.
class Supervisor {
  Supervisor({CoreLocator? locator}) : _locator = locator ?? CoreLocator();

  final CoreLocator _locator;
  final List<Process> _processes = <Process>[];
  final Set<int> _dead = <int>{};
  final List<StreamSubscription<String>> _streams = <StreamSubscription<String>>[];
  final List<CoreLog> _log = <CoreLog>[];

  final StreamController<CoreLog> _logs = StreamController<CoreLog>.broadcast();
  Timer? _reaper;
  bool _running = false;
  String? _lastError;

  bool get running => _running;
  String? get lastError => _lastError;
  List<CoreLog> get logLines => List<CoreLog>.unmodifiable(_log);
  Stream<CoreLog> get logs => _logs.stream;

  void _emit(CoreLog entry) {
    _log.add(entry);
    if (_log.length > 500) _log.removeAt(0);
    if (!_logs.isClosed) _logs.add(entry);
  }

  /// Bring the plan up. Throws with a human-readable reason when a core is
  /// missing or refuses to listen.
  Future<void> start(
    EnginePlan plan, {
    void Function(String message)? onProgress,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (_running) await stop();
    _lastError = null;
    _log.clear();
    _dead.clear();

    if (!plan.ok) {
      _lastError = plan.reason;
      throw StateError(plan.reason ?? 'plan cannot run');
    }

    final String runDir = _runDirectory();
    Directory(runDir).createSync(recursive: true);

    for (final CoreProcess spec in plan.processes) {
      onProgress?.call('starting ${spec.core.name}');
      final String? executable = await _locator.resolve(spec.core);
      if (executable == null) {
        final String message =
            'هسته ${spec.core.name} پیدا نشد؛ ساخت هسته‌ها را دوباره اجرا کنید.';
        _lastError = message;
        _emit(CoreLog(spec.core, message, error: true));
        await _killAll();
        throw StateError(message);
      }

      final Map<String, String> files = <String, String>{};
      spec.files.forEach((String name, String contents) {
        final String full = '$runDir${Platform.pathSeparator}$name';
        File(full).writeAsStringSync(contents);
        files[name] = full;
      });

      final List<String> args = spec.args
          .map((String arg) => _substitute(arg, runDir, files, spec))
          .toList();

      final Map<String, String> env = <String, String>{
        ...Platform.environment,
        ...spec.env,
        'S4VPN_RUN_DIR': runDir,
      };

      final Process process = await Process.start(
        executable,
        args,
        workingDirectory: runDir,
        environment: env,
        mode: ProcessStartMode.normal,
      );
      _processes.add(process);
      _watch(process.stdout, spec.core, error: false);
      _watch(process.stderr, spec.core, error: true);
      _watchExit(process, spec.core);
      _emit(CoreLog(spec.core, 'started with ${args.length} arguments'));
    }

    _running = true;
    onProgress?.call('waiting for the proxy');
    final bool up = await _waitForPort(plan.socksPort, timeout);
    if (!up) {
      final String message =
          'پروکسی روی ${plan.socksPort} باز نشد؛ پیام هسته را ببینید.';
      _lastError = message;
      await stop();
      throw StateError(message);
    }
    _startReaper();
    onProgress?.call('proxy ready');
  }

  Future<void> stop() async {
    _reaper?.cancel();
    _reaper = null;
    _running = false;
    await _killAll();
  }

  void _watchExit(Process process, CoreId core) {
    unawaited(process.exitCode.then((int code) {
      _dead.add(process.pid);
      if (code != 0) {
        final String message = '${core.name} exited with code $code';
        _lastError = message;
        _emit(CoreLog(core, message, error: true));
      }
    }));
  }

  Future<void> _killAll() async {
    final List<Process> processes = List<Process>.of(_processes);
    _processes.clear();
    for (final StreamSubscription<String> sub in _streams) {
      await sub.cancel();
    }
    _streams.clear();
    for (final Process process in processes) {
      process.kill(ProcessSignal.sigterm);
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final Process process in processes) {
      process.kill(ProcessSignal.sigkill);
    }
  }

  void _watch(Stream<List<int>> stream, CoreId core, {required bool error}) {
    _streams.add(
      stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
        if (line.trim().isEmpty) return;
        _emit(CoreLog(core, line, error: error));
      }),
    );
  }

  /// Watch for a core that dies while we believe we are connected. Without it a
  /// crashed tunnel keeps drawing as connected until the user taps again.
  void _startReaper() {
    _reaper?.cancel();
    _reaper = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (!_running) return;
      if (_processes.any((Process p) => _dead.contains(p.pid))) {
        _lastError = 'یکی از هسته‌ها حین اتصال بسته شد.';
        _emit(CoreLog(null, _lastError!, error: true));
        timer.cancel();
      }
    });
  }

  Future<bool> _waitForPort(int port, Duration timeout) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_processes.isEmpty) return false;
      try {
        final Socket socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
        ).timeout(const Duration(seconds: 1));
        await socket.close();
        return true;
      } on Exception {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    return false;
  }

  String _runDirectory() {
    final String exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}run';
  }

  /// Cores are told where their files are with placeholders rather than with a
  /// path baked into the plan: the same plan has to work from an unpacked
  /// build, a bundled Windows install and an Android data directory.
  String _substitute(
    String arg,
    String runDir,
    Map<String, String> files,
    CoreProcess spec,
  ) {
    String out = arg;
    files.forEach((String name, String full) {
      out = out.replaceAll('<$name>', full);
    });
    out = out.replaceAll('<configFile>', files['psiphon.json'] ?? '');
    out = out.replaceAll('<dataDir>', _locator.dataDirectory(spec.core));
    out = out.replaceAll('<runDir>', runDir);
    return out;
  }
}

/// A minimal SOCKS5 client, used only to prove a proxy is alive and to time a
/// round trip through it. It never carries application traffic.
class ProxyProbe {
  const ProxyProbe({this.host = '127.0.0.1'});

  final String host;

  /// Open a connection through the proxy to [target] and return how long the
  /// handshake took, or null when the proxy refused or timed out.
  Future<int?> handshake(
    int proxyPort, {
    String target = '1.1.1.1',
    int targetPort = 443,
  }) async {
    final Stopwatch watch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        proxyPort,
        timeout: const Duration(seconds: 5),
      );
      socket.add(<int>[0x05, 0x01, 0x00]);
      final List<int> greeting =
          await _read(socket, 2, const Duration(seconds: 5));
      if (greeting.length < 2 || greeting[0] != 0x05 || greeting[1] != 0x00) {
        return null;
      }

      socket.add(<int>[
        0x05,
        0x01,
        0x00,
        0x01,
        ..._ipv4(target),
        (targetPort >> 8) & 0xFF,
        targetPort & 0xFF,
      ]);
      final List<int> reply =
          await _read(socket, 10, const Duration(seconds: 8));
      if (reply.length < 4 || reply[1] != 0x00) return null;
      return watch.elapsedMilliseconds;
    } on Exception {
      return null;
    } finally {
      await socket?.close();
    }
  }

  Future<List<int>> _read(Socket socket, int bytes, Duration timeout) async {
    final StreamIterator<List<int>> iterator = StreamIterator<List<int>>(socket);
    final List<int> buffer = <int>[];
    while (buffer.length < bytes) {
      final bool hasMore = await iterator
          .moveNext()
          .timeout(timeout, onTimeout: () => false);
      if (!hasMore) break;
      buffer.addAll(iterator.current);
    }
    return buffer;
  }

  static List<int> _ipv4(String host) {
    final List<int> out = <int>[];
    for (final String part in host.split('.')) {
      final int? value = int.tryParse(part);
      out.add(value != null && value >= 0 && value <= 255 ? value : 0);
    }
    while (out.length < 4) {
      out.add(0);
    }
    return out.take(4).toList();
  }
}

/// Jitter for the White server re-test: bounded, and never negative enough to
/// push a server under the floor the preview clamps to.
int whiteJitter(int latency) {
  final math.Random random = math.Random();
  final int delta = random.nextInt(29) - 14;
  final int floorDelta = latency + delta < 38 ? 38 - latency : 0;
  return delta + floorDelta;
}

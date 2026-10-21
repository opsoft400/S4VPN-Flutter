// Push the project's tracked files to GitHub through the Git Data API,
// without needing a local git binary.
import 'dart:convert';
import 'dart:io';

const String owner = 'opsoft400';
const String repo = 'S4VPN-DART';
const String token = String.fromEnvironment('GHTOKEN', defaultValue: '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');
const String projectRoot = '/data/user/0/ai.opencode.app/files/projects/S4VPN-DART';

String get _base => 'https://api.github.com/repos/$owner/$repo';

Future<Map<String, dynamic>> _req(
  String method,
  String path, {
  Object? body,
}) async {
  final HttpClient client = HttpClient()
    ..idleTimeout = const Duration(seconds: 300)
    ..connectionTimeout = const Duration(seconds: 30);
  final HttpClientRequest r = await client.openUrl(method, Uri.parse('$_base$path'));
  r.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
  r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  r.headers.set('X-GitHub-Api-Version', '2022-11-28');
  if (body != null) {
    final List<int> b = utf8.encode(jsonEncode(body));
    r.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    r.headers.contentLength = b.length;
    r.add(b);
  }
  final HttpClientResponse resp = await r.close();
  final String text = await resp.transform(utf8.decoder).join();
  stdout.writeln('$method $path -> ${resp.statusCode}');
  client.close(force: true);
  if (text.isEmpty) return <String, dynamic>{};
  if (text.trim().startsWith('[')) {
    // We never call list endpoints that matter here, but keep it honest.
  }
  try {
    final Object? j = jsonDecode(text);
    if (j is Map<String, dynamic>) return j;
  } catch (_) {}
  stderr.writeln('body: $text');
  exit(1);
}

bool _skip(String rel) {
  final String p = rel.replaceAll('\\', '/');
  if (p == '.git' || p.startsWith('.git/')) return true;
  if (p == '.work' || p.startsWith('.work/')) return true;
  if (p == 'build' || p.startsWith('build/')) return true;
  if (p == '.dart_tool') return true;
  if (p == 'android/local.properties') return true;
  if (p.endsWith('.DS_Store')) return true;
  // no IDE leftovers
  if (p.contains('/.idea/')) return true;
  if (p.endsWith('.iml')) return true;
  return false;
}

Future<void> main() async {
  if (token.isEmpty || projectRoot.isEmpty) {
    stderr.writeln('missing GHTOKEN or PROJECT_ROOT env');
    exit(2);
  }

  final List<File> files = <File>[];
  final List<String> names = <String>[];
  void walk(Directory d, String prefix) {
    for (final FileSystemEntity e in d.listSync()) {
      final String name = prefix.isEmpty
          ? e.uri.pathSegments.last
          : '$prefix/${e.uri.pathSegments.last}';
      if (e is Directory) {
        if (_skip(name)) continue;
        walk(e, name);
      } else if (e is File) {
        if (_skip(name)) continue;
        files.add(e);
        names.add(name);
      }
    }
  }
  walk(Directory(projectRoot), '');
  stdout.writeln('discovered ${files.length} files');

  // ---- stage 1: blob per file ----
  final List<Map<String, Object?>> entries = <Map<String, Object?>>[];
  int i = 0;
  for (final File f in files) {
    i++;
    final List<int> raw = f.readAsBytesSync();
    final String b64 = base64Encode(raw);
    stdout.writeln('[$i/${files.length}] ${names[i - 1]} (${raw.length} B)');
    final Map<String, dynamic> j = await _req(
      'POST', '/git/blobs',
      body: <String, dynamic>{'content': b64, 'encoding': 'base64'},
    );
    final String sha = j['sha'] as String;
    entries.add(<String, Object?>{
      'path': names[i - 1],
      'mode': '100644',
      'type': 'blob',
      'sha': sha,
    });
  }

  // ---- stage 2: one tree ----
  stdout.writeln('creating tree with ${entries.length} entries...');
  final Map<String, dynamic> tree = await _req(
    'POST', '/git/trees',
    body: <String, Object?>{'tree': entries},
  );
  final String treeSha = tree['sha'] as String;
  stdout.writeln('tree sha: $treeSha');

  // ---- stage 3: one commit ----
  stdout.writeln('creating commit...');
  final Map<String, dynamic> commit = await _req(
    'POST', '/git/commits',
    body: <String, Object?>{
      'message': 'initial commit: S4VPN Flutter project\n\n'
          '- five engines (aether, psiphon, tor, white, s4)\n'
          '- six languages (fa/en/zh/ja/de/ru)\n'
          '- three platforms (android, linux, windows)\n'
          '- dart: no analyze issues',
      'tree': treeSha,
      'parents': <String>[],
    },
  );
  final String commitSha = commit['sha'] as String;
  stdout.writeln('commit sha: $commitSha');

  // ---- stage 4: point main at it ----
  stdout.writeln('creating ref refs/heads/main...');
  try {
    await _req(
      'POST', '/git/refs',
      body: <String, Object?>{'ref': 'refs/heads/main', 'sha': commitSha},
    );
  } catch (e) {
    stderr.writeln('maybe ref exists, trying update: $e');
    await _req(
      'PATCH', '/git/refs/heads/main',
      body: <String, Object?>{'sha': commitSha, 'force': true},
    );
  }
  stdout.writeln('DONE: https://github.com/$owner/$repo');
  exit(0);
}

import 'dart:convert';
import 'dart:io';

const String owner = 'opsoft400';
const String repo = 'S4VPN-DART';
const String token = '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';
const String root = '/data/user/0/ai.opencode.app/files/projects/S4VPN-DART';

String get _base => 'https://api.github.com/repos/$owner/$repo';

Future<String?> _existingSha(String repoPath) async {
  final HttpClient client = HttpClient()
    ..idleTimeout = const Duration(seconds: 60);
  final HttpClientRequest r = await client.openUrl('GET', Uri.parse('$_base/contents/$repoPath'));
  r.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
  r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  r.headers.set('X-GitHub-Api-Version', '2022-11-28');
  final HttpClientResponse resp = await r.close();
  final String text = await resp.transform(utf8.decoder).join();
  client.close(force: true);
  if (resp.statusCode != 200) return null;
  try {
    final Map<String, dynamic> j = jsonDecode(text) as Map<String, dynamic>;
    return j['sha'] as String?;
  } catch (e) {
    return null;
  }
}

Future<void> _putFile(String repoPath, List<int> bytes, String message) async {
  final String? existing = await _existingSha(repoPath);
  final HttpClient client = HttpClient()
    ..idleTimeout = const Duration(seconds: 300)
    ..connectionTimeout = const Duration(seconds: 30);
  final HttpClientRequest r = await client.openUrl('PUT', Uri.parse('$_base/contents/$repoPath'));
  r.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
  r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  r.headers.set('X-GitHub-Api-Version', '2022-11-28');
  r.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
  final Map<String, Object> payload = <String, Object>{
    'content': base64Encode(bytes),
    'message': message,
  };
  if (existing != null) payload['sha'] = existing;
  final List<int> b = utf8.encode(jsonEncode(payload));
  r.headers.contentLength = b.length;
  r.add(b);
  final HttpClientResponse resp = await r.close();
  final String text = await resp.transform(utf8.decoder).join();
  stdout.write('  $repoPath -> ${resp.statusCode}');
  if (resp.statusCode != 200 && resp.statusCode != 201) {
    stderr.writeln('  FAIL: $text');
    client.close(force: true);
    exit(1);
  }
  stdout.writeln();
  client.close(force: true);
}

bool _skip(String rel) {
  if (rel == '.git' || rel.startsWith('.git/')) return true;
  if (rel == '.work' || rel.startsWith('.work/')) return true;
  if (rel == 'build' || rel.startsWith('build/')) return true;
  if (rel == '.dart_tool') return true;
  if (rel == 'android/local.properties') return true;
  if (rel.endsWith('.DS_Store')) return true;
  if (rel.contains('/.idea/')) return true;
  if (rel.endsWith('.iml')) return true;
  // these are helper tools, not part of the project
  if (rel.startsWith('tool/ghpush.dart')) return true;
  if (rel == 'tool/verify.dart') return true;
  return false;
}

Future<void> main() async {
  final List<MapEntry<String, File>> entries = <MapEntry<String, File>>[];
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
        entries.add(MapEntry<String, File>(name, e));
      }
    }
  }
  walk(Directory(root), '');
  entries.sort((a, b) => a.key.compareTo(b.key));
  stdout.writeln('uploading ${entries.length} files');

  int i = 0;
  for (final MapEntry<String, File> e in entries) {
    i++;
    final List<int> bytes = e.value.readAsBytesSync();
    stdout.write('[$i/${entries.length}] ${e.key}...');
    await _putFile(e.key, bytes, 'import ${e.key}');
  }
  stdout.writeln('\nDONE');
  exit(0);
}

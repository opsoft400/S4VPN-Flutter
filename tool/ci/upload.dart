// Upload a directory to GitHub through the REST API.
//
// The sandbox's `git` is a stand-in, so the tree is built by hand: one blob
// per file, one tree, one commit, one ref update. It is also the fallback for
// any environment where the git binary is not the real thing.
import 'dart:convert';
import 'dart:io';

const String owner = 'opsoft400';
const String repo = 'S4VPN-Flutter';

final HttpClient client = HttpClient();
final String token = Platform.environment['GH_TOKEN'] ?? '';

Future<dynamic> api(String method, String path, [Object? body]) async {
  final Uri uri = Uri.parse('https://api.github.com$path');
  // The sandbox's proxy drops long-lived connections, so every call is
  // retried rather than trusted to survive the first attempt.
  Object? lastError;
  for (int attempt = 1; attempt <= 6; attempt++) {
    try {
      final HttpClientRequest request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 's4vpn-uploader');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final HttpClientResponse response = await request.close();
      final String text = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        stderr.writeln('$method $path -> ${response.statusCode}: '
            '${text.length > 400 ? text.substring(0, 400) : text}');
        exit(1);
      }
      return text.isEmpty ? null : jsonDecode(text);
    } on Exception catch (error) {
      lastError = error;
      stderr.writeln('retry $attempt for $path: $error');
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    }
  }
  stderr.writeln('giving up on $path: $lastError');
  exit(1);
}

bool ignored(String path) {
  for (final String skip in <String>[
    '/.dart_tool/',
    '/build/',
    '/.idea/',
    '/.git/',
    '/.work/',
  ]) {
    if (path.contains(skip)) return true;
  }
  // The cores are staged by the CI, not committed: the DNS ones are extracted
  // from the WhiteDNS release and the rest are built from the engine zips.
  if (path.contains('/jniLibs/') && path.endsWith('.so')) {
    return true;
  }
  return false;
}

Future<void> main(List<String> args) async {
  final String root = args[0];
  final String branch = args.length > 1 ? args[1] : 'main';
  final Directory dir = Directory(root);

  final List<File> files = <File>[];
  await for (final FileSystemEntity entity in dir.list(recursive: true)) {
    if (entity is! File) continue;
    final String rel = entity.path.substring(root.length + 1);
    if (ignored('/$rel')) continue;
    files.add(entity);
  }
  files.sort((File a, File b) => a.path.compareTo(b.path));
  stdout.writeln('files: ${files.length}');

  final List<Map<String, String>> entries = <Map<String, String>>[];

  // Blobs already uploaded are remembered, so a dropped connection costs one
  // file rather than the whole tree. The cache lives outside the tree it
  // describes.
  final File cache = File(
      '${Directory.systemTemp.path}/s4vpn-upload-cache-${owner}-$repo.json');
  final Map<String, String> known = <String, String>{};
  if (cache.existsSync()) {
    final dynamic decoded = jsonDecode(cache.readAsStringSync());
    if (decoded is Map) {
      decoded.forEach((Object? key, Object? value) {
        if (key is String && value is String) known[key] = value;
      });
    }
  }
  final Map<String, String> fresh = <String, String>{};

  int done = 0;
  for (final File file in files) {
    final String rel = file.path.substring(root.length + 1);
    final String key = '$rel:${file.lengthSync()}:${file.lastModifiedSync().millisecondsSinceEpoch}';
    String? sha = known[key];
    if (sha == null) {
      final List<int> bytes = file.readAsBytesSync();
      final dynamic blob = await api(
        'POST',
        '/repos/$owner/$repo/git/blobs',
        <String, String>{
          'content': base64.encode(bytes),
          'encoding': 'base64',
        },
      );
      sha = blob['sha'] as String;
      fresh[key] = sha;
      cache.writeAsStringSync(jsonEncode(<String, String>{...known, ...fresh}));
    }
    entries.add(<String, String>{
      'path': rel,
      'mode': '100644',
      'type': 'blob',
      'sha': sha,
    });
    done++;
    if (done % 20 == 0 || done == files.length) {
      stdout.writeln('  $done/${files.length} $rel');
    }
  }

  // The tree is built in two passes. A tree request carrying the four engine
  // zips times out on the API, so the archives go into their own tree first
  // and the rest of the project is layered on top of it.
  const int bigThreshold = 2 * 1024 * 1024;
  final List<Map<String, String>> small = <Map<String, String>>[];
  final List<Map<String, String>> big = <Map<String, String>>[];
  for (final Map<String, String> entry in entries) {
    final File file = File('$root/${entry['path']}');
    if (file.lengthSync() > bigThreshold) {
      big.add(entry);
    } else {
      small.add(entry);
    }
  }

  String baseTree = '';
  if (big.isNotEmpty) {
    final dynamic bigTree = await api(
      'POST',
      '/repos/$owner/$repo/git/trees',
      <String, dynamic>{'tree': big},
    );
    baseTree = bigTree['sha'] as String;
    stdout.writeln('archives tree: $baseTree (${big.length} files)');
  }

  final dynamic tree = await api(
    'POST',
    '/repos/$owner/$repo/git/trees',
    <String, dynamic>{
      'tree': small,
      if (baseTree.isNotEmpty) 'base_tree': baseTree,
    },
  );
  stdout.writeln('tree: ${tree['sha']}');

  // The branch's current head, so the commit has a parent when there is one.
  String? parent;
  try {
    final dynamic ref =
        await api('GET', '/repos/$owner/$repo/git/ref/heads/$branch');
    parent = (ref['object'] as Map<String, dynamic>)['sha'] as String;
  } catch (_) {
    parent = null;
  }

  final dynamic commit = await api(
    'POST',
    '/repos/$owner/$repo/git/commits',
    <String, dynamic>{
      'message': 'S4VPN: multi-engine client with the DNS (SOFT400) mode',
      'tree': tree['sha'],
      if (parent != null) 'parents': <String>[parent],
    },
  );
  stdout.writeln('commit: ${commit['sha']}');

  final dynamic updated = await api(
    'PATCH',
    '/repos/$owner/$repo/git/refs/heads/$branch',
    <String, dynamic>{
      'sha': commit['sha'] as String,
      'force': true,
    },
  );
  stdout.writeln('ref: ${updated['object']['sha']}');
}

import 'dart:convert';
import 'dart:io';

import 'dart:math' as math;

/// What the server said about a code.
class CodeResult {
  const CodeResult.valid(this.seconds, {this.message})
      : valid = true,
        error = false;

  const CodeResult.invalid(this.message)
      : valid = false,
        seconds = 0,
        error = true;

  final bool valid;
  final bool error;
  final int seconds;
  final String? message;

  Duration get duration => Duration(seconds: seconds);
}

/// Checks a code with the server.
///
/// The server owns the truth: it answers how long the code grants and whether
/// it is good at all. The app never decides that on its own, because a code
/// that works on one phone and not another is the server's business.
///
/// Expected answer:
///
/// ```json
/// { "valid": true,  "seconds": 2592000, "message": "ok" }
/// { "valid": false, "message": "این کد مصرف شده" }
/// ```
class CodeService {
  CodeService({this.baseUrl = '', this.deviceId = ''});

  /// Where the codes are checked. Empty means "no server yet", and the screen
  /// says so rather than pretending a code worked.
  final String baseUrl;

  /// A stable id for this install, sent along so the server can count uses.
  final String deviceId;

  Future<CodeResult> redeem(String code) async {
    final String trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const CodeResult.invalid('کد وارد نشده');
    }
    if (baseUrl.trim().isEmpty) {
      return const CodeResult.invalid('سرور کد فعال نیست');
    }

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final HttpClientRequest request = await client.postUrl(
        Uri.parse('${_trimSlash(baseUrl)}/redeem'),
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(<String, Object?>{
        'code': trimmed,
        'device': deviceId,
      }));
      final HttpClientResponse response = await request.close();

      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        return CodeResult.invalid('سرور پاسخ ${response.statusCode} داد');
      }
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map) {
        return const CodeResult.invalid('پاسخ سرور قابل خواندن نبود');
      }
      final Map<String, Object?> json = decoded.cast<String, Object?>();
      final bool valid = json['valid'] == true;
      if (!valid) {
        final String message = (json['message'] ?? 'کد درست نیست').toString();
        return CodeResult.invalid(message);
      }
      final int seconds = (json['seconds'] as num?)?.toInt() ?? 0;
      if (seconds <= 0) {
        return const CodeResult.invalid('مدت کد نامعتبر است');
      }
      return CodeResult.valid(seconds, message: json['message'] as String?);
    } on SocketException {
      return const CodeResult.invalid('اتصال به سرور برقرار نشد');
    } on HttpException {
      return const CodeResult.invalid('پاسخی از سرور نرسید');
    } on FormatException {
      return const CodeResult.invalid('پاسخ سرور خوانا نبود');
    } finally {
      client.close(force: true);
    }
  }

  static String _trimSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  /// A stable id for this install, derived once and kept in the settings.
  static String deriveDeviceId(String seed) {
    final math.Random random = math.Random(seed.hashCode);
    const String alphabet = '0123456789abcdef';
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < 32; i++) {
      out.write(alphabet[random.nextInt(alphabet.length)]);
    }
    return out.toString();
  }
}

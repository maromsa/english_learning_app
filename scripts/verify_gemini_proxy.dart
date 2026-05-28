// Temporary connectivity check for GEMINI_PROXY_URL.
// Delete this file once you have confirmed AI works end-to-end.
//
// Usage (from repo root):
//   set -a && source .env && set +a && dart run scripts/verify_gemini_proxy.dart
// Or:
//   GEMINI_PROXY_URL=https://... dart run scripts/verify_gemini_proxy.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _timeout = Duration(seconds: 30);

void main(List<String> args) async {
  _loadDotEnvIfPresent('.env');

  final url = Platform.environment['GEMINI_PROXY_URL']?.trim() ?? '';
  if (url.isEmpty) {
    stderr.writeln(
      '❌ GEMINI_PROXY_URL is not set.\n'
      '   Add it to .env or export it, then re-run this script.',
    );
    exit(1);
  }

  final endpoint = Uri.tryParse(url);
  if (endpoint == null || !endpoint.hasScheme || !endpoint.hasAuthority) {
    stderr.writeln('❌ GEMINI_PROXY_URL is not a valid URL: $url');
    exit(1);
  }

  stdout.writeln('🔍 Gemini proxy connectivity check');
  stdout.writeln('   Endpoint: $endpoint');
  stdout.writeln('');

  final payload = <String, dynamic>{
    'mode': 'text',
    'prompt':
        'Reply with exactly one short English sentence that includes the word "hello". '
        'No markdown, no JSON.',
    'system_instruction':
        'You are a friendly English tutor for children. Keep answers very short.',
  };

  stdout.writeln('📤 POST ${jsonEncode(payload)}');

  final client = HttpClient();
  client.connectionTimeout = _timeout;

  try {
    final request = await client.postUrl(endpoint);
    final bodyBytes = utf8.encode(jsonEncode(payload));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.contentLength = bodyBytes.length;
    request.add(bodyBytes);

    final response = await request.close().timeout(_timeout);
    final body = await response.transform(utf8.decoder).join();

    stdout.writeln('📥 HTTP ${response.statusCode}');
    stdout.writeln('   Body: $body');

    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln('\n❌ Proxy returned a non-200 status.');
      exit(1);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      stderr.writeln('\n❌ Response is not valid JSON.');
      exit(1);
    }

    if (decoded is! Map) {
      stderr.writeln('\n❌ Expected a JSON object, got ${decoded.runtimeType}.');
      exit(1);
    }

    final text = decoded['text'];
    if (text is! String || text.trim().isEmpty) {
      stderr.writeln(
        '\n❌ Missing or empty "text" field. '
        'The proxy should return {"text": "..."} for mode "text".',
      );
      exit(1);
    }

    stdout.writeln('\n✅ Proxy is reachable and returned AI text:');
    stdout.writeln('   "${text.trim()}"');
    exit(0);
  } on SocketException catch (e) {
    stderr.writeln('\n❌ Network error: $e');
    stderr.writeln(
      '   Check GEMINI_PROXY_URL, VPN/firewall, and that the function is deployed.',
    );
    exit(1);
  } on TimeoutException {
    stderr.writeln('\n❌ Request timed out after ${_timeout.inSeconds}s.');
    exit(1);
  } finally {
    client.close(force: true);
  }
}

void _loadDotEnvIfPresent(String path) {
  final file = File(path);
  if (!file.existsSync()) return;

  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;

    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }

    if (Platform.environment.containsKey(key)) continue;
    Platform.environment[key] = value;
  }
}

/// legado 书源的 HTTP 访问层。
///
/// 中文站点编码三种情况都常见：响应头声明、`<meta charset>` 声明、两者都没有。
/// 这里按"响应头 → meta → 试解 UTF-8 看乱码比例"的顺序判断，命中 GBK 时用
/// `package:charset` 真正解码（不是 latin1 透传）。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset/charset.dart';

import 'rule_engine.dart' show resolveUrl;

class LegadoClient {
  LegadoClient({this.timeout = const Duration(seconds: 15)});

  final Duration timeout;

  static const userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  HttpClient? _client;

  HttpClient get _http =>
      _client ??= HttpClient()
        ..connectionTimeout = timeout
        ..idleTimeout = const Duration(seconds: 20);

  /// 解析 legado 的 URL 写法：地址后面可以跟一段 JSON 选项。
  ///
  /// ```
  /// https://a.com/s?q=1
  /// https://a.com/api,{"method":"POST","body":"key=1","charset":"gbk"}
  /// ```
  ///
  /// 不解析这段，POST 站点会被当成 GET 请求，整条搜索链路都拿不到结果。
  static ({String url, Map<String, dynamic> options}) splitOptions(String spec) {
    final cut = spec.lastIndexOf(',{');
    if (cut < 0) return (url: spec.trim(), options: const {});
    final tail = spec.substring(cut + 1);
    try {
      final decoded = jsonDecode(tail);
      if (decoded is Map) {
        return (
          url: spec.substring(0, cut).trim(),
          options: Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      // 不是合法 JSON 就整串当地址，交给上层报错。
    }
    return (url: spec.trim(), options: const {});
  }

  /// 下载二进制内容（封面、插图）。超过 [maxBytes] 直接放弃，避免被大文件拖死。
  Future<Uint8List?> getBytes(
    String spec, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
  }) async {
    final parts = splitOptions(spec);
    if (parts.url.isEmpty) return null;
    try {
      final request = await _http.getUrl(Uri.parse(parts.url));
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      headers.forEach((key, value) {
        if (key.toLowerCase() == 'user-agent') return;
        request.headers.set(key, value);
      });
      final response = await request.close().timeout(timeout);
      if (response.statusCode >= 400) {
        await response.drain<void>();
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(timeout)) {
        builder.add(chunk);
        if (builder.length > maxBytes) return null;
      }
      final bytes = builder.takeBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  /// 把规则产出的地址解析成"绝对 URL (+ 原样的 JSON 选项)"。
  ///
  /// 顺序很重要：必须先把 `,{...}` 拆下来再解析地址，否则 `Uri.resolve` 会把
  /// 那段 JSON 当成路径的一部分。
  static String resolveSpec(String baseUrl, String raw) {
    final parts = splitOptions(raw);
    final resolved = resolveUrl(baseUrl, parts.url);
    if (parts.options.isEmpty) return resolved;
    return '$resolved,${jsonEncode(parts.options)}';
  }

  Future<String?> get(
    String url, {
    Map<String, String> headers = const {},
  }) async {
    if (url.isEmpty) return null;
    final parts = splitOptions(url);
    if (parts.options.isEmpty) {
      return _send(parts.url, 'GET', null, const {}, headers);
    }

    final options = parts.options;
    final method = '${options['method'] ?? 'GET'}'.toUpperCase();
    final body = options['body'];
    final optionHeaders = <String, String>{};
    final rawHeaders = options['headers'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, value) {
        if (key is String && value is String) optionHeaders[key] = value;
      });
    }
    final charset = options['charset'] is String
        ? options['charset'] as String
        : '';

    return _send(
      parts.url,
      method,
      body is String && body.isNotEmpty ? body : null,
      optionHeaders,
      headers,
      charsetOverride: charset,
    );
  }

  Future<String?> _send(
    String url,
    String method,
    String? body,
    Map<String, String> optionHeaders,
    Map<String, String> sourceHeaders, {
    String charsetOverride = '',
  }) async {
    if (url.isEmpty) return null;
    try {
      final request = await _http.openUrl(
        method,
        Uri.parse(url),
      );
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'text/html,*/*');
      sourceHeaders.forEach((key, value) {
        if (key.toLowerCase() == 'user-agent') return;
        request.headers.set(key, value);
      });
      optionHeaders.forEach(request.headers.set);
      if (body != null) {
        final bytes = utf8.encode(body);
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        request.contentLength = bytes.length;
        request.add(bytes);
      }

      final response = await request.close().timeout(timeout);
      if (response.statusCode >= 400) {
        await response.drain<void>();
        return null;
      }
      final bytes = await response
          .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk))
          .timeout(timeout);

      final declared = charsetOverride.isNotEmpty
          ? charsetOverride.toLowerCase()
          : (response.headers.contentType?.charset ?? '').toLowerCase();
      return _decode(bytes, declared);
    } catch (_) {
      return null;
    }
  }

  String _decode(List<int> bytes, String declaredCharset) {
    if (_isGbk(declaredCharset)) return _decodeGbk(bytes);
    if (declaredCharset.contains('utf')) {
      return utf8.decode(bytes, allowMalformed: true);
    }

    // 响应头没声明时先看页面自己的 meta。
    final head = latin1.decode(
      bytes.take(2048).toList(),
      allowInvalid: true,
    );
    final meta = RegExp(
      r'''charset\s*=\s*["']?\s*([A-Za-z0-9_-]+)''',
      caseSensitive: false,
    ).firstMatch(head);
    if (meta != null) {
      final value = meta.group(1)!.toLowerCase();
      if (_isGbk(value)) return _decodeGbk(bytes);
    }

    final utf8Text = utf8.decode(bytes, allowMalformed: true);
    final broken = '\uFFFD'.allMatches(utf8Text).length;
    // 替换字符成片出现说明不是 UTF-8，按 GBK 再解一次。
    if (broken > utf8Text.length ~/ 20) return _decodeGbk(bytes);
    return utf8Text;
  }

  bool _isGbk(String charset) =>
      charset.contains('gbk') ||
      charset.contains('gb2312') ||
      charset.contains('gb18030') ||
      charset == 'gb';

  String _decodeGbk(List<int> bytes) {
    try {
      return gbk.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  void close() {
    _client?.close(force: true);
    _client = null;
  }
}

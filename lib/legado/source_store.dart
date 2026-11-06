/// 书源仓库：内置源 + 用户导入源 + 启用状态。
///
/// 内置源随包放在 `assets/legado/sources.json`，用户导入的源单独存一份，两者
/// 按 `bookSourceUrl` 去重（用户导入的优先，方便覆盖内置的同名源）。启用状态
/// 只记禁用名单，这样新导入的源默认就是开的。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'book_source.dart';
import 'legado_bootstrap.dart';

class LegadoSourceStore extends ChangeNotifier {
  LegadoSourceStore({this.preferences});

  final SharedPreferences? preferences;

  static const _userKey = 'legado.sources.user.v1';
  static const _disabledKey = 'legado.sources.disabled.v1';

  final List<LegadoBookSource> _builtIn = [];
  final List<LegadoBookSource> _user = [];
  final Set<String> _disabled = {};

  bool _loaded = false;
  String? _error;

  List<LegadoBookSource> get builtIn => List.unmodifiable(_builtIn);

  List<LegadoBookSource> get user => List.unmodifiable(_user);

  String? get error => _error;

  bool get loaded => _loaded;

  /// 全部源，用户导入的排在前面。
  List<LegadoBookSource> get all => [..._user, ..._builtIn];

  /// 引擎可执行且未被禁用的源。
  ///
  /// 内置源与用户导入源可能指向同一个 `bookSourceUrl`（用户把内置源又导入了一次），
  /// 这里按 key 去重：保留先出现的（用户导入的排在前面）。不去重会让发现页的
  /// 源列表出现重复项，`Wrap` 里同 key 的两个按钮会直接红屏。
  List<LegadoBookSource> get enabled {
    final seen = <String>{};
    return [
      for (final source in all)
        if (source.isSupported &&
            !_disabled.contains(_key(source)) &&
            seen.add(_key(source)))
          source,
    ];
  }

  /// 引擎执行不了的源（脚本型或非文本类型），在列表里灰显。
  List<LegadoBookSource> get unsupported =>
      all.where((source) => !source.isSupported).toList();

  bool isEnabled(LegadoBookSource source) =>
      source.isSupported && !_disabled.contains(_key(source));

  static String _key(LegadoBookSource source) => source.baseUrl;

  Future<void> load({String assetPath = legadoAssetPath}) async {
    if (_loaded) return;
    _loaded = true;
    // 内置源是可选的：仓库里不带书源时这里会读不到资源，不能因此让用户导入的
    // 书源也读不出来，所以两段分开处理。
    try {
      await _loadBuiltIn(assetPath);
    } catch (_) {
      // 没有内置书源文件，属于正常情况。
    }
    _loadUser();
    _error = null;
    notifyListeners();
  }

  Future<void> _loadBuiltIn(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    for (final item in decoded) {
      if (item is! Map) continue;
      final source = LegadoBookSource.fromJson(Map<String, dynamic>.from(item));
      if (source != null) _builtIn.add(source);
    }
  }

  void _loadUser() {
    final store = preferences;
    if (store == null) return;
    final rawUser = store.getString(_userKey);
    if (rawUser != null) {
      try {
        final decoded = jsonDecode(rawUser);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final source = LegadoBookSource.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (source != null) _user.add(source);
          }
        }
      } catch (_) {
        // 损坏的导入记录只影响用户自建源，内置源照常可用。
      }
    }
    final rawDisabled = store.getStringList(_disabledKey);
    if (rawDisabled != null) _disabled.addAll(rawDisabled);
  }

  /// 从 JSON 文本导入。支持三种常见形态：书源数组、单个书源对象、以及被
  /// 阅读器导出的 `{"bookSources":[...]}` 包装。
  Future<ImportResult> importJson(String text) async {
    final parsed = _parseSources(text);
    if (parsed.isEmpty) {
      return const ImportResult(added: 0, skipped: 0, error: '没有识别到书源');
    }

    var added = 0;
    var skipped = 0;
    final existing = {for (final source in _user) _key(source): source};
    for (final source in parsed) {
      final key = _key(source);
      if (existing.containsKey(key)) {
        skipped++;
        continue;
      }
      existing[key] = source;
      _user.add(source);
      added++;
    }
    if (added > 0) await _persistUser();
    notifyListeners();
    return ImportResult(added: added, skipped: skipped);
  }

  /// 从分享链接导入（形如 `https://host/xxx.json`）。
  Future<ImportResult> importUrl(String url, {Duration timeout = const Duration(seconds: 20)}) async {
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return const ImportResult(added: 0, skipped: 0, error: '请填写 http(s) 开头的地址');
    }
    final client = HttpClientHolder();
    try {
      final text = await client.getText(trimmed, timeout: timeout);
      if (text == null) {
        return const ImportResult(added: 0, skipped: 0, error: '下载失败，请检查网络或链接');
      }
      return importJson(text);
    } finally {
      client.close();
    }
  }

  List<LegadoBookSource> _parseSources(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return const [];
    }

    Iterable<Object?> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map) {
      final wrapped = decoded['bookSources'] ?? decoded['sources'];
      items = wrapped is List ? wrapped : [decoded];
    } else {
      return const [];
    }

    final result = <LegadoBookSource>[];
    for (final item in items) {
      if (item is! Map) continue;
      final source = LegadoBookSource.fromJson(Map<String, dynamic>.from(item));
      if (source != null) result.add(source);
    }
    return result;
  }

  Future<void> setEnabled(LegadoBookSource source, bool value) async {
    final key = _key(source);
    if (value) {
      _disabled.remove(key);
    } else {
      _disabled.add(key);
    }
    await _persistDisabled();
    notifyListeners();
  }

  /// 只允许移除用户导入的源；内置源可以禁用但不删。
  Future<void> removeUserSource(LegadoBookSource source) async {
    final key = _key(source);
    _user.removeWhere((item) => _key(item) == key);
    _disabled.remove(key);
    await _persistUser();
    await _persistDisabled();
    notifyListeners();
  }

  /// 把所有启用中的源导出成 legado 可识别的数组。
  String exportJson() => jsonEncode([
    for (final source in all)
      if (isEnabled(source)) source.toJson(),
  ]);

  Future<void> _persistUser() async {
    final store = preferences;
    if (store == null) return;
    await store.setString(
      _userKey,
      jsonEncode([for (final source in _user) source.toJson()]),
    );
  }

  Future<void> _persistDisabled() async {
    final store = preferences;
    if (store == null) return;
    await store.setStringList(_disabledKey, _disabled.toList());
  }
}

class ImportResult {
  const ImportResult({required this.added, required this.skipped, this.error});

  final int added;
  final int skipped;
  final String? error;

  bool get ok => error == null;

  String get summary => error ??
      (added == 0 ? '没有新增书源（$skipped 个已存在）' : '新增 $added 个书源'
          '${skipped > 0 ? '，跳过 $skipped 个重复' : ''}');
}

/// 极简下载器，只服务于"从链接导入书源"这一个场景。
class HttpClientHolder {
  HttpClient? _client;

  HttpClient get _http => _client ??= HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  Future<String?> getText(String url, {required Duration timeout}) async {
    try {
      final request = await _http.getUrl(Uri.parse(url));
      request.headers.set('user-agent', 'Wenku8-Flutter/legado-import');
      final response = await request.close().timeout(timeout);
      if (response.statusCode >= 400) {
        await response.drain<void>();
        return null;
      }
      final bytes = await response
          .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk))
          .timeout(timeout);
      // 书源分享站点有时用 gzip，交给 HttpClient 自动解压后按 UTF-8 读。
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  void close() {
    _client?.close(force: true);
    _client = null;
  }
}

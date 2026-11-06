/// 与 Android 侧 [`LegadoEnginePlugin`] 通信的通道封装。
///
/// 引擎在 Kotlin 侧（Archive 的 `AnalyzeRule` / `AnalyzeUrl` + Rhino），Dart 只做
/// 三件事：把书源 JSON 递过去、把结果映射成 [Novel] / [NovelChapter]、维护 int id。
///
/// 所有方法都有超时：书源站点经常挂着不回，不能让一次搜索把整个 App 卡死。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

class LegadoEngineChannel {
  LegadoEngineChannel({MethodChannel? channel, this.timeout = const Duration(seconds: 30)})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'app.yunqi.reader/legado_engine';

  final MethodChannel _channel;
  final Duration timeout;

  /// 引擎是否已就绪（Context 已注入、Rhino 可用）。
  Future<bool> ready() async {
    try {
      return await _channel.invokeMethod<bool>('ready') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> search({
    required String source,
    required String key,
    int page = 1,
  }) => _invoke('search', {'source': source, 'key': key, 'page': page});

  Future<String> bookInfo({required String source, required String bookUrl}) =>
      _invoke('bookInfo', {'source': source, 'bookUrl': bookUrl});

  Future<String> toc({required String source, required String tocUrl}) =>
      _invoke('toc', {'source': source, 'tocUrl': tocUrl});

  Future<String> content({
    required String source,
    required String chapterUrl,
  }) => _invoke('content', {'source': source, 'chapterUrl': chapterUrl});

  /// 解析 `exploreUrl`：返回 `[{title,url,type,action,style}]`。
  Future<String> exploreKinds({required String source}) =>
      _invoke('exploreKinds', {'source': source}, timeout: const Duration(seconds: 20));

  /// 按分类拉一页，返回书籍数组（字段同 search）。
  Future<String> explore({
    required String source,
    required String url,
    int page = 1,
  }) => _invoke('explore', {'source': source, 'url': url, 'page': page});

  Future<String> _invoke(
    String method,
    Map<String, Object?> arguments, {
    Duration? timeout,
  }) async {
    final result = await _channel
        .invokeMethod<String>(method, arguments)
        .timeout(timeout ?? this.timeout);
    return result ?? '';
  }
}

/// 把引擎返回的 JSON 数组解析成 map 列表，失败返回空表（不抛给 UI）。
List<Map<String, dynamic>> decodeEngineList(String raw) {
  if (raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  } catch (_) {
    return const [];
  }
}

/// 把引擎返回的 JSON 对象解析成 map，失败返回空 map。
Map<String, dynamic> decodeEngineObject(String raw) {
  if (raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return const {};
  }
}

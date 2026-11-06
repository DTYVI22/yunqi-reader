/// 走 Android 引擎（Archive 规则求值 + Rhino）的 [NovelRepository] 实现。
///
/// 与 `legado_repository.dart`（纯 Dart 引擎）的分工：
/// - Dart 版只覆盖 CSS/Default 子集，没有 `@js`、JSONPath、XPath、分页正文；
/// - 引擎版把求值全部交给 Kotlin，Dart 只负责「拼 JSON → 映射成 Novel → 管 int id」。
///
/// 书源的 `rawJson` 原样透传，避免 Dart 侧不认识的字段在传输中丢失。
library;

import 'dart:async';
import 'dart:convert';

import '../catalog.dart';
import '../explore_catalog.dart';
import 'book_registry.dart';
import 'book_source.dart';
import 'engine_channel.dart';
import 'legado_repository.dart' show colorsForId;

class LegadoEngineRepository extends NovelRepository {
  LegadoEngineRepository({
    required List<LegadoBookSource> Function() sources,
    required this.registry,
    LegadoEngineChannel? channel,
    this.searchConcurrency = 8,
    this.sourceTimeout = const Duration(seconds: 25),
  }) : _sourceProvider = sources,
       _channel = channel ?? LegadoEngineChannel();

  final List<LegadoBookSource> Function() _sourceProvider;
  final LegadoBookRegistry registry;
  final LegadoEngineChannel _channel;
  final int searchConcurrency;
  final Duration sourceTimeout;

  List<LegadoBookSource> get sources => _sourceProvider();

  /// 引擎是否就绪。非 Android 平台或通道未注册时返回 false，调用方回退 Dart 引擎。
  Future<bool> isAvailable() => _channel.ready();

  /// 搜索期间命中的书，避免详情页再请求一次。
  final Map<int, Novel> _known = {};

  LegadoBookSource? _sourceOf(String key) {
    for (final source in sources) {
      if (source.baseUrl == key) return source;
    }
    return null;
  }

  @override
  Future<List<Novel>> list() async => const [];

  @override
  Future<List<Novel>> search(String query) async {
    final trimmed = query.trim();
    final active = sources;
    if (trimmed.isEmpty || active.isEmpty) return const [];

    final results = <int, Novel>{};
    for (var index = 0; index < active.length; index += searchConcurrency) {
      final batch = active.skip(index).take(searchConcurrency).toList();
      final settled = await Future.wait([
        for (final source in batch) _searchSource(source, trimmed),
      ]);
      for (final novels in settled) {
        for (final novel in novels) {
          results.putIfAbsent(novel.id, () => novel);
        }
      }
    }
    return results.values.toList();
  }

  @override
  Future<Novel?> find(int id) async {
    final cached = _known[id];
    if (cached != null) return cached;
    final ref = registry.lookup(id);
    if (ref == null) return null;
    final source = _sourceOf(ref.sourceUrl);
    if (source == null) return null;
    return _loadDetail(source, ref);
  }

  @override
  Future<Novel> detail(Novel novel) async {
    final ref = registry.lookup(novel.id);
    if (ref == null) return novel;
    final source = _sourceOf(ref.sourceUrl);
    if (source == null) return novel;
    return await _loadDetail(source, ref) ?? novel;
  }

  @override
  Future<List<NovelChapter>> chapters(int id) async {
    final ref = registry.lookup(id);
    if (ref == null) return const [];
    final source = _sourceOf(ref.sourceUrl);
    if (source == null) return const [];

    final tocUrl = ref.tocUrl ?? ref.bookUrl;
    final rows = await _invokeToc(source, tocUrl);
    if (rows.isEmpty) return const [];

    final refs = <LegadoChapterRef>[];
    final result = <NovelChapter>[];
    for (final row in rows) {
      final title = '${row['title'] ?? ''}'.trim();
      final link = '${row['url'] ?? ''}'.trim();
      if (link.isEmpty) continue;
      final url = _absolute(tocUrl, link);
      final chapterId = await registry.chapterIdFor(id, url);
      refs.add(LegadoChapterRef(id: chapterId, url: url, title: title));
      result.add(NovelChapter(title, '', id: chapterId));
    }
    if (refs.isEmpty) return const [];
    await registry.replaceChapters(id, refs);
    return result;
  }

  @override
  Future<String> chapterContent(int novelId, NovelChapter chapter) async {
    final ref = registry.lookup(novelId);
    if (ref == null) throw const FormatException('这本书不在书源记录里');
    final source = _sourceOf(ref.sourceUrl);
    if (source == null) throw const FormatException('书源已移除');

    final url =
        registry.chapterUrlFor(novelId, chapter.id) ??
        _chapterUrlByTitle(novelId, chapter.title);
    if (url == null) throw const FormatException('找不到这一章的地址');

    final raw = await _channel.content(
      source: jsonEncode(source.rawJson),
      chapterUrl: url,
    );
    if (raw.trim().isEmpty) {
      throw const FormatException('这一章没有取到正文，可能站点已改版');
    }
    return raw.trim();
  }

  @override
  Future<NovelPage> browse({
    NovelSort sort = NovelSort.lastUpdate,
    int page = 1,
    bool refresh = false,
    ExploreTarget? target,
  }) async {
    if (target != null) {
      final source = _sourceOf(target.sourceKey);
      if (source == null) return NovelPage(items: const [], page: page);
      try {
        final raw = await _channel
            .explore(
              source: jsonEncode(source.rawJson),
              url: target.url,
              page: page,
            )
            .timeout(sourceTimeout);
        return NovelPage(items: await _novelsFrom(source, raw), page: page);
      } catch (_) {
        return NovelPage(items: const [], page: page);
      }
    }
    // 没有选中分类：不猜「各源首页」。书源的首屏推荐没有统一语义，猜错会让
    // 用户等 8 个源的超时（每个 25s）。这里直接返回空，由发现页引导用户选分类。
    if (sources.isEmpty) return NovelPage(items: const [], page: page);
    return NovelPage(items: const [], page: page);
  }

  /// 列出所有「有发现页」的源及其分类（`exploreUrl` 为空的源不出现）。
  @override
  Future<List<ExploreSource>> exploreSources({bool refresh = false}) async {
    final seen = <String>{};
    final active = [
      for (final source in sources)
        if (source.exploreUrl.trim().isNotEmpty && seen.add(source.baseUrl)) source,
    ];
    if (active.isEmpty) return const [];

    final result = <ExploreSource>[];
    const batchSize = 6;
    for (var index = 0; index < active.length; index += batchSize) {
      final batch = active.skip(index).take(batchSize).toList();
      result.addAll(await Future.wait([for (final s in batch) _kindsOf(s)]));
    }
    return result;
  }

  // ---- 内部 ----

  Future<ExploreSource> _kindsOf(LegadoBookSource source) async {
    try {
      final raw = await _channel
          .exploreKinds(source: jsonEncode(source.rawJson))
          .timeout(const Duration(seconds: 25));
      return ExploreSource(
        key: source.baseUrl,
        name: source.name,
        group: source.group,
        type: source.type,
        kinds: decodeEngineList(raw).map(ExploreKind.fromMap).toList(),
      );
    } catch (error) {
      return ExploreSource(
        key: source.baseUrl,
        name: source.name,
        group: source.group,
        type: source.type,
        kinds: const [],
        error: '$error',
      );
    }
  }

  Future<List<Novel>> _searchSource(
    LegadoBookSource source,
    String query,
  ) async {
    try {
      final raw = await _channel
          .search(source: jsonEncode(source.rawJson), key: query, page: 1)
          .timeout(sourceTimeout);
      return _novelsFrom(source, raw);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Novel>> _novelsFrom(
    LegadoBookSource source,
    String raw,
  ) async {
    final rows = decodeEngineList(raw);
    final novels = <Novel>[];
    for (final row in rows) {
      final title = '${row['name'] ?? ''}'.trim();
      final link = '${row['bookUrl'] ?? ''}'.trim();
      if (title.isEmpty || link.isEmpty) continue;
      final bookUrl = _absolute(source.baseUrl, link);
      final id = await registry.idFor(source.baseUrl, bookUrl, title: title);
      final cover = '${row['coverUrl'] ?? ''}'.trim();
      final novel = Novel(
        id: id,
        title: title,
        author: '${row['author'] ?? ''}'.trim(),
        genre: '${(row['kind'] as String?)?.trim().isNotEmpty == true ? row['kind'] : source.name}',
        summary: '${row['intro'] ?? ''}'.trim(),
        colors: colorsForId(id),
        coverUrl: cover.isEmpty ? null : _absolute(source.baseUrl, cover),
        lastUpdate: row['lastChapter'] as String?,
      );
      _known[id] = novel;
      novels.add(novel);
    }
    return novels;
  }

  Future<Novel?> _loadDetail(
    LegadoBookSource source,
    LegadoBookRef ref,
  ) async {
    final info = decodeEngineObject(
      await _channel
          .bookInfo(
            source: jsonEncode(source.rawJson),
            bookUrl: ref.bookUrl,
          )
          .timeout(sourceTimeout),
    );
    if (info.isEmpty) return null;

    final tocLink = '${info['tocUrl'] ?? ''}'.trim();
    if (tocLink.isNotEmpty) {
      await registry.cacheTocUrl(ref.id, _absolute(ref.bookUrl, tocLink));
    }

    String? pick(String key) {
      final value = '${info[key] ?? ''}'.trim();
      return value.isEmpty ? null : value;
    }

    final cover = pick('coverUrl');
    final novel = Novel(
      id: ref.id,
      title: pick('name') ?? ref.title,
      author: pick('author') ?? '',
      genre: pick('kind') ?? source.name,
      summary: pick('intro') ?? '',
      colors: colorsForId(ref.id),
      coverUrl: cover == null ? null : _absolute(ref.bookUrl, cover),
      lastUpdate: pick('lastChapter'),
    );
    _known[ref.id] = novel;
    await registry.idFor(source.baseUrl, ref.bookUrl, title: novel.title);
    return novel;
  }

  Future<List<Map<String, dynamic>>> _invokeToc(
    LegadoBookSource source,
    String tocUrl,
  ) async {
    try {
      final raw = await _channel
          .toc(source: jsonEncode(source.rawJson), tocUrl: tocUrl)
          .timeout(sourceTimeout);
      return decodeEngineList(raw);
    } catch (_) {
      return const [];
    }
  }

  String? _chapterUrlByTitle(int bookId, String title) {
    for (final ref in registry.chaptersOf(bookId)) {
      if (ref.title == title) return ref.url;
    }
    return null;
  }

  /// 引擎返回的是规则原始值（多为 `/book/1.html`），按当前页面解析成绝对地址。
  String _absolute(String base, String value) {
    final text = value.trim();
    if (text.isEmpty) return text;
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    if (text.startsWith('//')) return 'http:$text';
    final parsed = Uri.tryParse(base);
    if (parsed == null || parsed.host.isEmpty) return text;
    try {
      return parsed.resolve(text).toString();
    } catch (_) {
      return text;
    }
  }
}

/// 把 legado 书源接成项目自己的 [NovelRepository]。
///
/// 项目原有的在线源是 `LegacyWenkuRepository`（公开快照里是空壳），书架、阅读
/// 器、缓存全部通过这个抽象接口取书。这里实现同样的 6 个方法，书与章节的 int
/// id 由 [LegadoBookRegistry] 维护，真实地址是 legado 的 URL。
library;

import 'dart:async';

import 'package:flutter/material.dart' show Color;
import 'package:html/parser.dart' as html_parser;

import '../catalog.dart';
import 'book_registry.dart';
import 'book_source.dart';
import 'explore.dart';
import 'legado_client.dart';
import 'rule_engine.dart';

class LegadoRepository extends NovelRepository {
  LegadoRepository({
    required List<LegadoBookSource> Function() sources,
    required this.registry,
    LegadoClient? client,
    this.searchConcurrency = 24,
    this.sourceTimeout = const Duration(seconds: 8),
  }) : _sourceProvider = sources,
       _client = client ?? LegadoClient();

  /// 源列表在每次使用时现取：用户在设置里导入、启用或禁用书源后，下一条搜索
  /// 立刻按新配置执行，不需要重启应用。
  final List<LegadoBookSource> Function() _sourceProvider;
  final LegadoBookRegistry registry;
  final LegadoClient _client;
  final int searchConcurrency;
  final Duration sourceTimeout;

  List<LegadoBookSource> get sources =>
      _sourceProvider().where((source) => source.isSupported).toList();

  static const _engine = RuleEngine();

  /// 搜索期间命中的书，避免详情页再次请求。
  final Map<int, Novel> _known = {};

  @override
  Future<List<Novel>> list() async => const [];

  @override
  Future<Novel?> find(int id) async {
    final cached = _known[id];
    if (cached != null) return cached;
    final ref = registry.lookup(id);
    if (ref == null) return null;
    final source = _sourceOf(ref.sourceUrl);
    if (source == null) return null;
    return _loadDetail(source, ref, ref.bookUrl);
  }

  @override
  Future<Novel> detail(Novel novel) async {
    final ref = registry.lookup(novel.id);
    if (ref == null) return novel;
    final source = _sourceOf(ref.sourceUrl);
    if (source == null) return novel;
    return await _loadDetail(source, ref, ref.bookUrl) ?? novel;
  }

  @override
  Future<List<Novel>> search(String query) async {
    final trimmed = query.trim();
    final active = sources;
    if (trimmed.isEmpty || active.isEmpty) return const [];

    final results = <int, Novel>{};
    final queue = List<LegadoBookSource>.from(active)
      ..sort((a, b) => b.weight.compareTo(a.weight));

    // 用户等不了几十秒：首批一定跑完，之后只要够数或超时就收手。书源多的时候
    // 全跑一遍要按分钟算，而前几个源通常已经能给出可用结果。
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    const enough = 15;

    for (var index = 0; index < queue.length; index += searchConcurrency) {
      if (index > 0 &&
          (results.length >= enough || DateTime.now().isAfter(deadline))) {
        break;
      }
      final batch = queue.skip(index).take(searchConcurrency).toList();
      final settled = await Future.wait([
        for (final source in batch)
          _searchSource(source, trimmed).timeout(
            sourceTimeout,
            onTimeout: () => const <Novel>[],
          ),
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
  Future<List<NovelChapter>> chapters(int id) async {
    final ref = registry.lookup(id);
    if (ref == null) return const [];
    final source = _sourceOf(ref.sourceUrl);
    if (source == null) return const [];

    // 目录可能分页（ruleToc.nextTocUrl）：第一页必抓，之后按规则给出的地址
    // 逐页跟进。visited 同时用来防死循环和防重复抓取。
    const maxPages = 30;
    final firstUrl = ref.tocUrl ?? ref.bookUrl;
    final queue = <String>[firstUrl];
    final visited = <String>{};
    final seenChapters = <String>{};
    final refs = <LegadoChapterRef>[];
    final result = <NovelChapter>[];

    while (queue.isNotEmpty && visited.length < maxPages) {
      final tocUrl = queue.removeAt(0);
      if (!visited.add(tocUrl)) continue;

      final html = await _client.get(tocUrl, headers: source.header);
      if (html == null) {
        // 缓存的目录地址可能已失效：第一页失败时回详情页重新解析一次。
        if (tocUrl == firstUrl && ref.tocUrl != null) {
          registry.cacheTocUrl(id, ref.bookUrl);
          if (await _loadDetail(source, ref, ref.bookUrl) != null) {
            queue.add(ref.bookUrl);
          }
        }
        continue;
      }

      final document = html_parser.parse(html);
      final context = RuleContext(baseUrl: tocUrl);
      final rows = _engine
          .evaluate(source.ruleToc['chapterList'], document, context)
          .elements;

      // 后续页解析不出章节，说明分页规则给出的地址没用了，停在这里。
      if (rows.isEmpty) {
        if (visited.length > 1) break;
        continue;
      }

      for (final row in rows) {
        final title =
            _engine.evaluate(
              source.ruleToc['chapterName'],
              row,
              context,
            ).first ??
            '';
        final link =
            _engine.evaluate(
              source.ruleToc['chapterUrl'],
              row,
              context,
            ).first ??
            '';
        if (link.isEmpty) continue;
        final url = LegadoClient.resolveSpec(tocUrl, link);
        // 分页站点的相邻页可能重叠，按最终地址去重。
        if (!seenChapters.add(url)) continue;
        final chapterId = await registry.chapterIdFor(id, url);
        refs.add(LegadoChapterRef(id: chapterId, url: url, title: title));
        result.add(NovelChapter(title, '', id: chapterId));
      }

      final nextRule = source.ruleToc['nextTocUrl'];
      if (nextRule != null && nextRule.isNotEmpty) {
        for (final value in _engine.evaluate(nextRule, document, context).all) {
          final next = LegadoClient.resolveSpec(tocUrl, value);
          if (next.isNotEmpty && !visited.contains(next)) queue.add(next);
        }
      }
    }

    if (refs.isEmpty) return const [];
    await registry.replaceChapters(id, refs);
    return result;
  }

  @override
  Future<String> chapterContent(int novelId, NovelChapter chapter) async {
    // 已知现象：部分书源站点抓取的是原版站内容，而原版站做了防盗版混淆——
    // 正文里会混入别的小说的段落。这是源与站点层面的固有情况，不是规则解析
    // 错误，也不在这里做清洗；换源即可绕开。
    final ref = registry.lookup(novelId);
    if (ref == null) throw const FormatException('这本书不在书源记录里');
    final source = _sourceOf(ref.sourceUrl);
    if (source == null) throw const FormatException('书源已移除');

    final url =
        registry.chapterUrlFor(novelId, chapter.id) ??
        // 目录刚刷新过、章节还是旧 id 时，用标题兜底找一次
        _fallbackChapterUrl(novelId, chapter.title);
    if (url == null) throw const FormatException('找不到这一章的地址');

    final html = await _client.get(url, headers: source.header);
    if (html == null) throw const FormatException('章节请求失败，请检查网络');

    final document = html_parser.parse(html);
    final context = RuleContext(baseUrl: url);
    final rule =
        (source.ruleContent['content'] ?? '') +
        (source.ruleContent['replaceRegex'] ?? '');
    final text = _engine.evaluate(rule, document, context).first ?? '';
    if (text.trim().isEmpty) {
      throw const FormatException('这一章没有取到正文，可能站点已改版');
    }
    return text;
  }

  String? _fallbackChapterUrl(int bookId, String title) {
    for (final ref in registry.chaptersOf(bookId)) {
      if (ref.title == title) return ref.url;
    }
    return null;
  }

  /// 搜索一个源。任何异常都收敛成空列表，避免单个源拖垮整次搜索。
  Future<List<Novel>> _searchSource(
    LegadoBookSource source,
    String query,
  ) async {
    final path = source.searchUrl
        .replaceAll('{{key}}', Uri.encodeComponent(query))
        .replaceAll('{{page}}', '1');
    final url = LegadoClient.resolveSpec(source.baseUrl, path);
    final html = await _client.get(url, headers: source.header);
    if (html == null) return const [];
    return _booksFromPage(source, html, url, source.ruleSearch);
  }

  /// 从一个列表页里按给定规则集提取书目。搜索与发现共用。
  Future<List<Novel>> _booksFromPage(
    LegadoBookSource source,
    String html,
    String pageUrl,
    RuleMap rules, {
    int limit = 30,
  }) async {
    if (rules.isEmpty) return const [];
    final document = html_parser.parse(html);
    final context = RuleContext(baseUrl: pageUrl);
    final rows = _engine.evaluate(rules['bookList'], document, context).elements;
    if (rows.isEmpty) return const [];

    final novels = <Novel>[];
    for (final row in rows.take(limit)) {
      final title = _engine.evaluate(rules['name'], row, context).first;
      final link = _engine.evaluate(rules['bookUrl'], row, context).first;
      if (title == null || title.isEmpty || link == null || link.isEmpty) {
        continue;
      }
      final bookUrl = LegadoClient.resolveSpec(pageUrl, link);
      final id = await registry.idFor(
        source.baseUrl,
        bookUrl,
        title: title,
      );
      final cover = _engine.evaluate(rules['coverUrl'], row, context).first;
      final novel = Novel(
        id: id,
        title: title,
        author: _engine.evaluate(rules['author'], row, context).first ?? '',
        genre: _engine.evaluate(rules['kind'], row, context).first ?? source.name,
        summary: _engine.evaluate(rules['intro'], row, context).first ?? '',
        colors: colorsForId(id),
        coverUrl: cover == null || cover.isEmpty
            ? null
            : LegadoClient.resolveSpec(pageUrl, cover),
        lastUpdate: _engine.evaluate(rules['lastChapter'], row, context).first,
      );
      _known[id] = novel;
      novels.add(novel);
    }
    return novels;
  }

  /// 发现页：legado 书源的「发现」就是 exploreUrl 里的分类。
  ///
  /// 现有发现页 UI 只有一条列表，没有分类 tab，所以这里取每个源分类表的第一项，
  /// 拼成一条「各源首页推荐」的列表。排序参数对书源没有意义，忽略。
  @override
  Future<NovelPage> browse({
    NovelSort sort = NovelSort.lastUpdate,
    int page = 1,
    bool refresh = false,
  }) async {
    final active = sources;
    if (active.isEmpty) return NovelPage(items: const [], page: page);

    final queue = List<LegadoBookSource>.from(active)
      ..sort((a, b) => b.weight.compareTo(a.weight));
    final results = <int, Novel>{};
    const enough = 24;

    for (final source in queue.take(12)) {
      final categories = parseExploreUrl(source.exploreUrl, source.baseUrl);
      if (categories.isEmpty) continue;
      final target = categories.first;
      final url = LegadoClient.resolveSpec(
        source.baseUrl,
        target.urlForPage(page),
      );
      final html = await _client
          .get(url, headers: source.header)
          .timeout(sourceTimeout, onTimeout: () => null);
      if (html == null) continue;
      // 发现页的分类页多数没有单独的 ruleExplore，退回搜索用的同名规则。
      final rules = source.ruleExplore.isNotEmpty
          ? source.ruleExplore
          : source.ruleSearch;
      final novels = await _booksFromPage(source, html, url, rules);
      for (final novel in novels) {
        results.putIfAbsent(novel.id, () => novel);
      }
      if (results.length >= enough) break;
    }

    return NovelPage(items: results.values.toList(), page: page);
  }

  /// 打开详情页补齐简介、封面、目录地址。
  Future<Novel?> _loadDetail(
    LegadoBookSource source,
    LegadoBookRef ref,
    String bookUrl,
  ) async {
    final html = await _client.get(bookUrl, headers: source.header);
    if (html == null) return null;
    final document = html_parser.parse(html);
    final context = RuleContext(baseUrl: bookUrl);

    String? pick(String field) =>
        _engine.evaluate(source.ruleBookInfo[field], document, context).first;

    final tocLink = pick('tocUrl');
    if (tocLink != null && tocLink.isNotEmpty) {
      await registry.cacheTocUrl(ref.id, LegadoClient.resolveSpec(bookUrl, tocLink));
    }

    final cover = pick('coverUrl');
    final novel = Novel(
      id: ref.id,
      title: pick('name') ?? ref.title,
      author: pick('author') ?? '',
      genre: pick('kind') ?? source.name,
      summary: pick('intro') ?? '',
      colors: colorsForId(ref.id),
      coverUrl: cover == null || cover.isEmpty ? null : resolveUrl(bookUrl, cover),
      lastUpdate: pick('lastChapter'),
    );
    _known[ref.id] = novel;
    await registry.idFor(source.baseUrl, bookUrl, title: novel.title);
    return novel;
  }

  LegadoBookSource? _sourceOf(String sourceUrl) {
    for (final source in sources) {
      if (source.baseUrl == sourceUrl) return source;
    }
    return null;
  }
}

/// 书源没有配色信息，按 id 稳定地挑一组，保证同一本书每次配色一致。
const _palettes = <List<Color>>[
  [Color(0xFF2C3440), Color(0xFF39465A)],
  [Color(0xFF3A2E3F), Color(0xFF4C3D55)],
  [Color(0xFF2F3A2F), Color(0xFF415245)],
  [Color(0xFF3A342A), Color(0xFF4F4636)],
  [Color(0xFF2B3540), Color(0xFF3D4C5C)],
  [Color(0xFF332E3A), Color(0xFF463F52)],
];

List<Color> colorsForId(int id) => _palettes[id.abs() % _palettes.length];

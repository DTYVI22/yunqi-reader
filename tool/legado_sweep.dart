// 批量验证：对全部可执行书源跑一遍搜索→详情→目录，统计成功率。
//
// 用法：dart run tool/legado_sweep.dart [关键词]
import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:wenku8_flutter/legado/book_source.dart';
import 'package:wenku8_flutter/legado/rule_engine.dart';

const _ua =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

Future<String?> fetch(String url, Map<String, String> headers) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.userAgentHeader, _ua);
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode >= 400) return null;
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    final decoded = utf8.decode(bytes, allowMalformed: true);
    final broken = RegExp('\uFFFD').allMatches(decoded).length;
    return broken > decoded.length ~/ 20
        ? latin1.decode(bytes, allowInvalid: true)
        : decoded;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

class Stat {
  String name = '';
  int search = 0;
  int detail = 0;
  int toc = 0;
  String note = '';
}

Future<void> main(List<String> args) async {
  final keyword = args.isNotEmpty ? args[0] : '我有一座恐怖屋';
  final raw =
      jsonDecode(
            await File('../legado-sources/source.json').readAsString(),
          )
          as List<dynamic>;
  final sources = raw
      .whereType<Map<String, dynamic>>()
      .map(LegadoBookSource.fromJson)
      .whereType<LegadoBookSource>()
      .where((source) => source.isSupported)
      .toList();
  stdout.writeln('可执行书源 ${sources.length} 个，开始批量验证（关键词：$keyword）\n');

  const engine = RuleEngine();
  final stats = <Stat>[];

  Future<void> probe(LegadoBookSource source) async {
    final stat = Stat()..name = source.name;
    final searchPath = source.searchUrl
        .replaceAll('{{key}}', Uri.encodeComponent(keyword))
        .replaceAll('{{page}}', '1');
    final searchUrl = resolveUrl(source.baseUrl, searchPath);

    final searchHtml = await fetch(searchUrl, source.header);
    if (searchHtml == null) {
      stat.note = '搜索请求失败';
      stats.add(stat);
      stdout.writeln('✗ ${source.name.padRight(16)} 搜索请求失败');
      return;
    }

    final searchContext = RuleContext(baseUrl: searchUrl);
    final document = html_parser.parse(searchHtml);
    final rows = engine
        .evaluate(source.ruleSearch['bookList'], document, searchContext)
        .elements;
    if (rows.isEmpty) {
      stat.note = 'bookList 无命中';
      stats.add(stat);
      stdout.writeln('✗ ${source.name.padRight(16)} bookList 无命中');
      return;
    }
    stat.search = rows.length;

    final firstLink = engine
        .evaluate(source.ruleSearch['bookUrl'], rows.first, searchContext)
        .first;
    if (firstLink == null) {
      stat.note = 'bookUrl 取不到';
      stats.add(stat);
      stdout.writeln('△ ${source.name.padRight(16)} ${rows.length} 条，bookUrl 取不到');
      return;
    }
    final detailUrl = resolveUrl(searchUrl, firstLink);
    final detailHtml = await fetch(detailUrl, source.header);
    if (detailHtml == null) {
      stat.note = '详情请求失败';
      stats.add(stat);
      stdout.writeln('△ ${source.name.padRight(16)} ${rows.length} 条，详情请求失败');
      return;
    }
    final detailContext = RuleContext(baseUrl: detailUrl);
    final detail = html_parser.parse(detailHtml);
    final title = engine
        .evaluate(source.ruleBookInfo['name'], detail, detailContext)
        .first;
    final tocLink =
        engine
            .evaluate(source.ruleBookInfo['tocUrl'], detail, detailContext)
            .first ??
        detailUrl;
    if (title != null && title.isNotEmpty) stat.detail = 1;

    final tocUrl = resolveUrl(detailUrl, tocLink);
    final tocHtml = await fetch(tocUrl, source.header);
    if (tocHtml == null) {
      stat.note = '目录请求失败';
      stats.add(stat);
      stdout.writeln('△ ${source.name.padRight(16)} ${rows.length} 条，目录请求失败');
      return;
    }
    final tocContext = RuleContext(baseUrl: tocUrl);
    final toc = html_parser.parse(tocHtml);
    final chapters = engine
        .evaluate(source.ruleToc['chapterList'], toc, tocContext)
        .elements;
    stat.toc = chapters.length;

    final mark = stat.detail == 1 && chapters.isNotEmpty ? '✓' : '△';
    stdout.writeln(
      '$mark ${source.name.padRight(16)} 搜索 ${rows.length} 条 · '
      '详情「${title ?? '-'}」· 目录 ${chapters.length} 章',
    );
    stats.add(stat);
  }

  const concurrency = 8;
  for (var index = 0; index < sources.length; index += concurrency) {
    final batch = sources.skip(index).take(concurrency).toList();
    await Future.wait([for (final source in batch) probe(source)]);
  }

  final searchOk = stats.where((s) => s.search > 0).length;
  final detailOk = stats.where((s) => s.detail > 0).length;
  final tocOk = stats.where((s) => s.toc > 0).length;
  stdout.writeln('\n===== 汇总 =====');
  stdout.writeln('参与：${stats.length}');
  stdout.writeln('搜索有结果：$searchOk');
  stdout.writeln('详情有标题：$detailOk');
  stdout.writeln('目录有章节：$tocOk');
}

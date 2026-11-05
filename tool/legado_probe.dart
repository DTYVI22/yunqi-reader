// legado 书源引擎的探针脚本：用真实书源跑一次搜索，验证规则求值。
//
// 用法：dart run tool/legado_probe.dart [书源名] [关键词]
import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:wenku8_flutter/legado/book_source.dart';
import 'package:wenku8_flutter/legado/rule_engine.dart';

const _ua =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

Future<String> fetch(String url, Map<String, String> headers) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.userAgentHeader, _ua);
    headers.forEach(request.headers.set);
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    final decoded = utf8.decode(bytes, allowMalformed: true);
    // 中文站常见 GBK，用替换字符比例判断是否解错。
    final broken = RegExp('\uFFFD').allMatches(decoded).length;
    if (broken > decoded.length ~/ 20) {
      return latin1.decode(bytes, allowInvalid: true);
    }
    return decoded;
  } finally {
    client.close(force: true);
  }
}

Future<void> main(List<String> args) async {
  final wanted = args.isNotEmpty ? args[0] : '快眼看书';
  final keyword = args.length > 1 ? args[1] : '我有一座恐怖屋';
  final file = File('../legado-sources/source.json');
  final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
  final sources = raw
      .whereType<Map<String, dynamic>>()
      .map(LegadoBookSource.fromJson)
      .whereType<LegadoBookSource>()
      .toList();

  stdout.writeln('书源总数 ${sources.length}，引擎可执行 '
      '${sources.where((s) => s.isSupported).length} 个');

  final source = sources.firstWhere(
    (s) => s.name == wanted,
    orElse: () => sources.firstWhere((s) => s.isSupported),
  );
  stdout.writeln('目标书源：${source.name}  ${source.baseUrl}');
  stdout.writeln('searchUrl：${source.searchUrl}');

  final searchPath = source.searchUrl
      .replaceAll('{{key}}', Uri.encodeComponent(keyword))
      .replaceAll('{{page}}', '1');
  final url = resolveUrl(source.baseUrl, searchPath);
  stdout.writeln('请求：$url');

  final body = await fetch(url, source.header);
  stdout.writeln('返回 ${body.length} 字符');

  final document = html_parser.parse(body);
  const engine = RuleEngine();
  final context = RuleContext(baseUrl: url);

  final listRule = source.ruleSearch['bookList'] ?? '';
  stdout.writeln('bookList 规则：$listRule');
  final listValue = engine.evaluate(listRule, document, context);
  final items = listValue.elements;
  stdout.writeln('命中书籍行：${items.length}');

  if (items.isEmpty) {
    final title = document.querySelector('title')?.text ?? '(无标题)';
    stdout.writeln('页面标题：$title');
    return;
  }

  for (final item in items.take(5)) {
    final name = engine.evaluate(source.ruleSearch['name'], item, context).first;
    final author = engine.evaluate(
      source.ruleSearch['author'],
      item,
      context,
    ).first;
    final bookUrl = engine.evaluate(
      source.ruleSearch['bookUrl'],
      item,
      context,
    ).first;
    final kind = engine.evaluate(source.ruleSearch['kind'], item, context).first;
    stdout.writeln('  · $name / ${author ?? '-'} / ${kind ?? '-'}');
    stdout.writeln('    $bookUrl');
  }

  // 进一步验证详情、目录、正文链路
  final firstBook = engine
      .evaluate(source.ruleSearch['bookUrl'], items.first, context)
      .first;
  if (firstBook == null) return;
  final bookUrl = resolveUrl(source.baseUrl, firstBook);
  stdout.writeln('\n== 详情页 $bookUrl');
  final detailHtml = await fetch(bookUrl, source.header);
  final detail = html_parser.parse(detailHtml);
  final detailContext = RuleContext(baseUrl: bookUrl);
  for (final field in ['name', 'author', 'intro', 'kind', 'lastChapter']) {
    final value = engine.evaluate(
      source.ruleBookInfo[field],
      detail,
      detailContext,
    ).first;
    stdout.writeln('  $field: ${value?.replaceAll('\n', ' ').substring(0, value.length > 60 ? 60 : value.length) ?? '-'}');
  }

  final tocUrl = engine.evaluate(
    source.ruleBookInfo['tocUrl'],
    detail,
    detailContext,
  ).first ?? bookUrl;
  stdout.writeln('\n== 目录页 $tocUrl');
  final tocHtml = await fetch(tocUrl, source.header);
  final toc = html_parser.parse(tocHtml);
  final tocContext = RuleContext(baseUrl: tocUrl);
  final chapters = engine.evaluate(
    source.ruleToc['chapterList'],
    toc,
    tocContext,
  ).elements;
  stdout.writeln('  章节数：${chapters.length}');
  for (final chapter in chapters.take(3)) {
    final title = engine.evaluate(
      source.ruleToc['chapterName'],
      chapter,
      tocContext,
    ).first;
    final link = engine.evaluate(
      source.ruleToc['chapterUrl'],
      chapter,
      tocContext,
    ).first;
    stdout.writeln('    · $title -> $link');
  }

  if (chapters.isEmpty) return;
  final chapterUrl = engine
      .evaluate(source.ruleToc['chapterUrl'], chapters.first, tocContext)
      .first;
  if (chapterUrl == null) return;
  final contentUrl = resolveUrl(source.baseUrl, chapterUrl);
  stdout.writeln('\n== 正文页 $contentUrl');
  final contentHtml = await fetch(contentUrl, source.header);
  final contentDoc = html_parser.parse(contentHtml);
  final content = engine.evaluate(
    source.ruleContent['content'],
    contentDoc,
    RuleContext(baseUrl: contentUrl),
  ).first;
  stdout.writeln('  正文长度：${content?.length ?? 0}');
  stdout.writeln('  预览：${content?.substring(0, content.length > 120 ? 120 : content.length).replaceAll('\n', ' ') ?? '-'}');
}

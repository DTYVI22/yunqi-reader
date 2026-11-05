/// legado 书源的「发现」入口：`exploreUrl`。
///
/// 字段里是一串分类，每项形如 `名称::地址`，用换行分隔；也有源用 JSON 数组
/// `[{"title":"..","url":".."}]`。地址里的 `{{page}}` 会替换成页码。
///
/// 还有一类源用 `@js:` 动态生成分类，需要执行脚本，这里直接跳过。
library;

import 'dart:convert';

class ExploreCategory {
  const ExploreCategory({required this.title, required this.url});

  final String title;

  /// 已解析成绝对地址；可能仍含 `{{page}}` 占位。
  final String url;

  String urlForPage(int page) =>
      url.replaceAll('{{page}}', '$page');

  Map<String, Object?> toJson() => {'title': title, 'url': url};
}

/// 这条 `exploreUrl` 是否只能靠脚本生成。
bool exploreNeedsScript(String? exploreUrl) {
  final text = exploreUrl?.trim();
  if (text == null || text.isEmpty) return true;
  return text.startsWith('@js:') ||
      text.contains('<js>') ||
      text.contains('java.connect');
}

/// 解析 `exploreUrl`。解析不出来时返回空列表，调用方按「这个源没有发现页」处理。
///
/// [baseUrl] 用来把相对地址补成绝对地址。
List<ExploreCategory> parseExploreUrl(String? exploreUrl, String baseUrl) {
  final text = exploreUrl?.trim();
  if (text == null || text.isEmpty) return const [];
  if (exploreNeedsScript(text)) return const [];

  if (text.startsWith('[')) {
    return _parseJson(text, baseUrl);
  }
  return _parseLines(text, baseUrl);
}

List<ExploreCategory> _parseJson(String text, String baseUrl) {
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    return const [];
  }
  if (decoded is! List) return const [];

  final result = <ExploreCategory>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final title = item['title'];
    final url = item['url'];
    if (title is! String || url is! String) continue;
    final resolved = _resolve(baseUrl, url);
    // 只作为分组标题的条目（url 为空）不产生可点分类。
    if (resolved.isEmpty) continue;
    result.add(ExploreCategory(title: title.trim(), url: resolved));
  }
  return result;
}

List<ExploreCategory> _parseLines(String text, String baseUrl) {
  final result = <ExploreCategory>[];
  for (final rawLine in const LineSplitter().convert(text)) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final cut = line.indexOf('::');
    if (cut <= 0) continue;
    final title = line.substring(0, cut).trim();
    final url = line.substring(cut + 2).trim();
    if (title.isEmpty || url.isEmpty) continue;
    final resolved = _resolve(baseUrl, url);
    if (resolved.isEmpty) continue;
    result.add(ExploreCategory(title: title, url: resolved));
  }
  return result;
}

String _resolve(String baseUrl, String url) {
  final value = url.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
  if (value.startsWith('//')) return 'http:$value';
  if (value.startsWith('/')) return '$root$value';
  return '$root/$value';
}

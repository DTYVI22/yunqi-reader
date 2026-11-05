/// Legado 书源的本地模型。
///
/// 只保留这个项目实际用得到的字段：搜索与详情/目录/正文四段规则，加上请求头
/// 与编码。`<js>` / `@js:` / `java.connect` 这些脚本形态不在第一版范围内，解析
/// 时标记出来，由上层决定是否跳过该书源。
library;

/// 一段规则（search/bookInfo/toc/content）里的具名字段。
typedef RuleMap = Map<String, String>;

class LegadoBookSource {
  LegadoBookSource({
    required this.name,
    required this.url,
    required this.type,
    required this.searchUrl,
    this.exploreUrl = '',
    required this.ruleSearch,
    this.ruleExplore = const {},
    required this.ruleBookInfo,
    required this.ruleToc,
    required this.ruleContent,
    this.header = const {},
    this.group = '',
    this.weight = 0,
    this.enabled = true,
  });

  /// 书源显示名。
  final String name;

  /// 站点根地址，可能带 `#` 尾巴（作者常用来写备注）。
  final String url;

  /// legado 的 bookSourceType：0 文本、1 音频、4 视频。
  final int type;

  final String searchUrl;

  /// 发现页分类，形如 `名称::地址` 的多行文本或 JSON 数组。
  final String exploreUrl;
  final RuleMap ruleSearch;
  final RuleMap ruleExplore;
  final RuleMap ruleBookInfo;
  final RuleMap ruleToc;
  final RuleMap ruleContent;
  final Map<String, String> header;
  final String group;
  final int weight;
  final bool enabled;

  /// 去掉 `#` 备注后的站点根地址。
  String get baseUrl {
    final cut = url.indexOf('#');
    final raw = cut >= 0 ? url.substring(0, cut) : url;
    return raw.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// 规则里是否出现脚本形态。引擎不执行脚本，只做静态判断。
  bool get usesScript {
    if (_hasScript(searchUrl)) return true;
    for (final map in [ruleSearch, ruleBookInfo, ruleToc, ruleContent]) {
      for (final value in map.values) {
        if (_hasScript(value)) return true;
      }
    }
    return false;
  }

  /// 少了任何一个就读不到书的字段。
  ///
  /// 封面、分类、简介、字数、最新章节这些只影响列表里的展示：脚本求值失败时
  /// 留空即可，不该因为一个封面规则废掉整个源。
  static const coreRuleFields = {
    'bookList',
    'name',
    'bookUrl',
    'chapterList',
    'chapterName',
    'chapterUrl',
    'content',
    'tocUrl',
  };

  /// 核心字段里是否夹着脚本。有就真的执行不了。
  bool get usesScriptInCore {
    if (_hasScript(searchUrl)) return true;
    for (final entry in [
      ...ruleSearch.entries,
      ...ruleBookInfo.entries,
      ...ruleToc.entries,
      ...ruleContent.entries,
    ]) {
      if (coreRuleFields.contains(entry.key) && _hasScript(entry.value)) {
        return true;
      }
    }
    return false;
  }

  /// 只有边缘字段用到脚本：源照样可用，那几个字段按空处理。
  bool get degradesScriptFields => !usesScriptInCore && usesScript;

  static bool _hasScript(String? value) =>
      value != null &&
      (value.contains('@js:') ||
          value.contains('<js>') ||
          value.contains('java.connect'));

  /// 这个源能否由当前引擎直接执行。
  bool get isSupported =>
      enabled && type == 0 && !usesScriptInCore && searchUrl.isNotEmpty;

  /// 导出成 legado 兼容的 JSON，便于备份或转回原阅读器。
  Map<String, Object?> toJson() => {
    'bookSourceName': name,
    'bookSourceUrl': url,
    'bookSourceType': type,
    'bookSourceGroup': group,
    'searchUrl': searchUrl,
    'exploreUrl': exploreUrl,
    'ruleSearch': ruleSearch,
    'ruleExplore': ruleExplore,
    'ruleBookInfo': ruleBookInfo,
    'ruleToc': ruleToc,
    'ruleContent': ruleContent,
    if (header.isNotEmpty) 'header': header,
    'weight': weight,
    'enabled': enabled,
  };

  static LegadoBookSource? fromJson(Map<String, dynamic> json) {
    final name = json['bookSourceName'];
    final url = json['bookSourceUrl'];
    if (name is! String || url is! String) return null;
    return LegadoBookSource(
      name: name,
      url: url,
      type: json['bookSourceType'] is int ? json['bookSourceType'] as int : 0,
      searchUrl: json['searchUrl'] is String
          ? json['searchUrl'] as String
          : '',
      exploreUrl: json['exploreUrl'] is String
          ? json['exploreUrl'] as String
          : '',
      ruleSearch: _rules(json['ruleSearch']),
      ruleExplore: _rules(json['ruleExplore']),
      ruleBookInfo: _rules(json['ruleBookInfo']),
      ruleToc: _rules(json['ruleToc']),
      ruleContent: _rules(json['ruleContent']),
      header: _headers(json['header']),
      group: json['bookSourceGroup'] is String
          ? json['bookSourceGroup'] as String
          : '',
      weight: json['weight'] is int ? json['weight'] as int : 0,
      enabled: json['enabled'] != false,
    );
  }

  static RuleMap _rules(Object? value) {
    if (value is! Map) return const {};
    final result = <String, String>{};
    value.forEach((key, raw) {
      if (key is String && raw is String && raw.isNotEmpty) {
        result[key] = raw;
      }
    });
    return result;
  }

  static Map<String, String> _headers(Object? value) {
    if (value is! Map) return const {};
    final result = <String, String>{};
    value.forEach((key, raw) {
      if (key is String && raw is String) result[key] = raw;
    });
    return result;
  }
}

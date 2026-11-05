/// legado 规则求值。
///
/// 一条规则是若干步骤用 `@` 连起来：选择器步骤做 DOM 查询，取值器步骤取文本或
/// 属性。`&&` 拼接多段规则，`||` 取第一个非空，`##正则##替换` 做后处理，
/// `{{变量}}` 做模板替换。
///
/// 脚本形态（`@js:` / `<js>` / `java.connect`）不在这里执行，调用方先用
/// [LegadoBookSource.usesScript] 过滤掉。
library;

import 'package:html/dom.dart';

import 'html_query.dart';

/// 把规则产出的地址解析成绝对 URL。legado 的书源里三种形态混用：完整地址、
/// 协议相对地址（`//host/path`）、相对地址（`/a/b` 或 `a/b`）。
///
/// 必须用 [Uri.resolve] 而不是字符串拼接：规则里的相对地址是相对**当前页面**的，
/// 而这个页面的路径可能很深（`/modules/article/search.php?...`），字符串拼接会把
/// 查询串留在中间。
String resolveUrl(String baseUrl, String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  if (text.startsWith('//')) return 'http:$text';

  final base = Uri.tryParse(baseUrl.trim());
  if (base == null || base.host.isEmpty) return text;
  try {
    return base.resolve(text).toString();
  } catch (_) {
    return text;
  }
}

class RuleContext {
  RuleContext({this.baseUrl = '', Map<String, String>? vars})
    : vars = vars ?? const {};

  /// 当前页面地址，对应规则里的 `{{baseUrl}}`。
  final String baseUrl;
  final Map<String, String> vars;

  String expand(String text) {
    var result = text;
    if (baseUrl.isNotEmpty) {
      result = result.replaceAll('{{baseUrl}}', baseUrl);
    }
    vars.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });
    return result;
  }
}

/// 规则求值结果：要么是 DOM 节点集合，要么是字符串集合。
class RuleValue {
  const RuleValue.elements(this.elements) : strings = const [];
  const RuleValue.strings(this.strings) : elements = const [];

  final List<Element> elements;
  final List<String> strings;

  bool get isEmpty => elements.isEmpty && strings.isEmpty;

  /// 第一个非空字符串。
  String? get first {
    for (final value in strings) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    for (final element in elements) {
      final text = element.text.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// 所有字符串（取值器产生）或节点文本（选择器产生）。
  List<String> get all {
    if (strings.isNotEmpty) return strings;
    return [
      for (final element in elements)
        if (element.text.trim().isNotEmpty) element.text.trim(),
    ];
  }
}

class RuleEngine {
  const RuleEngine();

  /// 求值一条规则，根节点可以是整个文档或一个元素。
  RuleValue evaluate(String? rule, Object root, RuleContext context) {
    final source = rule?.trim();
    if (source == null || source.isEmpty) return const RuleValue.strings([]);

    // `||`：返回第一个非空；`&&`：多段拼接。
    final alternatives = _splitTop(source, '||');
    if (alternatives.length > 1) {
      for (final part in alternatives) {
        final value = _evaluateConjunction(part, root, context);
        if (!value.isEmpty) return value;
      }
      return const RuleValue.strings([]);
    }
    return _evaluateConjunction(source, root, context);
  }

  RuleValue _evaluateConjunction(
    String rule,
    Object root,
    RuleContext context,
  ) {
    final parts = _splitTop(rule, '&&');
    if (parts.length == 1) return _evaluateSingle(parts.first, root, context);

    final collected = <String>[];
    for (final part in parts) {
      final value = _evaluateSingle(part, root, context);
      collected.addAll(value.all.where((item) => item.isNotEmpty));
    }
    return RuleValue.strings(collected);
  }

  RuleValue _evaluateSingle(String rule, Object root, RuleContext context) {
    // `##正则##替换`：切出规则本体和替换步骤。
    final segments = _splitTop(rule, '##');
    final body = segments.first;
    final replacements = segments.skip(1).toList();

    var value = _runSteps(body.trim(), root, context);
    if (replacements.isEmpty) return value;

    // `##正则##替换` —— 奇数下标是替换文本
    var text = value.strings.isNotEmpty
        ? value.strings.join('\n')
        : value.all.join('\n');
    for (var i = 0; i < replacements.length; i += 2) {
      final pattern = replacements[i];
      final replacement = i + 1 < replacements.length
          ? replacements[i + 1]
          : '';
      if (pattern.trim().isEmpty) continue;
      try {
        final regex = RegExp(context.expand(pattern));
        text = replacement.isEmpty
            ? text.replaceAll(regex, '')
            : text.replaceAllMapped(
                regex,
                (match) => context.expand(replacement).replaceAllMapped(
                  RegExp(r'\$(\d+)'),
                  (group) {
                    final index = int.tryParse(group.group(1)!) ?? 0;
                    return index <= match.groupCount
                        ? (match.group(index) ?? '')
                        : '';
                  },
                ),
              );
      } catch (_) {
        // 规则里的正则写坏了不该让整次搜索失败。
      }
    }
    return RuleValue.strings([text.trim()]);
  }

  RuleValue _runSteps(String rule, Object root, RuleContext context) {
    if (rule.isEmpty) {
      final elements = _asElements(root);
      return RuleValue.elements(elements);
    }

    // 去掉可选前缀
    var text = rule;
    if (text.startsWith('@css:')) text = text.substring(5);
    if (text.startsWith('@')) text = text.substring(1);
    if (text.startsWith('+')) text = text.substring(1);

    Object current = root;
    for (final rawStep in text.split('@')) {
      final step = rawStep.trim();
      if (step.isEmpty) continue;

      if (valueSelectors.contains(step)) {
        final strings = _extract(_asElements(current), step, context);
        return RuleValue.strings(strings);
      }

      final parsed = ParsedSelector.parse(step);
      if (parsed == null) continue;

      final elements = <Element>[];
      if (current is Document) {
        elements.addAll(parsed.selectIn(current));
      } else if (current is Element) {
        elements.addAll(parsed.selectOn(current));
      } else if (current is List<Element>) {
        for (final element in current) {
          elements.addAll(parsed.selectOn(element));
        }
      }
      current = elements;
    }

    return RuleValue.elements(_asElements(current));
  }

  List<String> _extract(
    List<Element> elements,
    String selector,
    RuleContext context,
  ) {
    final result = <String>[];
    for (final element in elements) {
      final value = switch (selector) {
        'text' => element.text.trim(),
        'ownText' => element.nodes
            .whereType<Text>()
            .map((node) => node.text)
            .join()
            .trim(),
        'textNodes' => element.nodes
            .whereType<Text>()
            .map((node) => node.text.trim())
            .where((text) => text.isNotEmpty)
            .join('\n'),
        'html' => element.innerHtml.trim(),
        'all' => element.outerHtml,
        _ => element.attributes[selector]?.trim() ?? '',
      };
      if (value.isNotEmpty) result.add(context.expand(value));
    }
    return result;
  }

  List<Element> _asElements(Object value) => switch (value) {
    Document document => document.documentElement == null
        ? const []
        : [document.documentElement!],
    Element element => [element],
    List<Element> elements => elements,
    _ => const [],
  };

  /// 按分隔符切分，但跳过成对括号内的分隔符。规则的替换段里常出现 `|`、
  /// `&&` 之类字面量，直接 split 会把正则切碎。
  List<String> _splitTop(String source, String separator) {
    final result = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (char == '(' || char == '[' || char == '{') depth++;
      if (char == ')' || char == ']' || char == '}') {
        if (depth > 0) depth--;
      }
      if (depth == 0 && source.startsWith(separator, i)) {
        result.add(source.substring(start, i));
        start = i + separator.length;
        i = start - 1;
      }
    }
    result.add(source.substring(start));
    return result;
  }
}

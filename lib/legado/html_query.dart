/// legado 选择器 → `package:html` 可执行查询的适配层。
///
/// legado 在标准 CSS 之外加了几样东西，`querySelectorAll` 都不认，必须在这里
/// 拆出来处理：
///   * 前缀写法 `class.a b c` / `id.x` / `tag.div`
///   * 文本匹配 `text.下一页`（目录分页最常见）
///   * 尾部索引 `span[0]` / `tag.span.1`
///   * 伪类 `:contains(文字)` 与属性正则 `[href~=/re/]`
library;

import 'package:html/dom.dart';

/// 取值器：出现这些名字时表示"取属性/文本"，不是再去查 DOM。
const valueSelectors = <String>{
  'text',
  'textNodes',
  'ownText',
  'html',
  'all',
  'href',
  'src',
  'content',
  'title',
  'value',
  'alt',
};

/// 把 legado 的单个选择器步骤解析成能执行的形式。
class ParsedSelector {
  ParsedSelector({
    required this.css,
    this.index,
    this.contains = const [],
    this.attributeRegex = const [],
    this.textContains,
  });

  final String css;
  final int? index;
  final List<String> contains;
  final List<({String attribute, RegExp pattern})> attributeRegex;

  /// `text.下一页` 形态：按元素文本内容筛选。
  final String? textContains;

  bool get isEmpty =>
      css.trim().isEmpty &&
      contains.isEmpty &&
      attributeRegex.isEmpty &&
      (textContains == null || textContains!.isEmpty);

  /// 解析一步选择器。返回 null 表示这一步是取值器，不该走 DOM 查询。
  static ParsedSelector? parse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (valueSelectors.contains(text)) return null;

    // text.下一页 —— 按文本内容找元素，先摘出来
    String? textContains;
    if (text.startsWith('text.')) {
      textContains = text.substring(5).trim();
      text = '';
    }

    // tag.div.1 —— 末尾的 .数字 是索引
    var index = _trailingIndex(text);
    if (index != null) {
      text = text.substring(0, text.lastIndexOf('.'));
    }
    // span[0] —— 方括号索引
    final bracket = RegExp(r'\[(\d+)\]$').firstMatch(text);
    if (bracket != null && index == null) {
      index = int.tryParse(bracket.group(1)!);
      text = text.substring(0, bracket.start);
    }

    // :contains(...)
    final contains = <String>[];
    text = text.replaceAllMapped(RegExp(r':contains\(([^)]*)\)'), (match) {
      contains.add(_unquote(match.group(1)!));
      return '';
    });

    // [attr~=正则]
    final attrRegex = <({String attribute, RegExp pattern})>[];
    text = text.replaceAllMapped(
      RegExp(r'\[([A-Za-z_:][-A-Za-z0-9_:.]*)\s*~=\s*([^\]]+)\]'),
      (match) {
        final attribute = match.group(1)!;
        var body = match.group(2)!.trim();
        if (body.length >= 2 && body.startsWith('/') && body.endsWith('/')) {
          body = body.substring(1, body.length - 1);
        }
        attrRegex.add((
          attribute: attribute,
          pattern: RegExp(body.isNotEmpty ? body : '.*'),
        ));
        return '';
      },
    );

    return ParsedSelector(
      css: _normalizePrefix(text.trim()),
      index: index,
      contains: contains,
      attributeRegex: attrRegex,
      textContains: textContains,
    );
  }

  static int? _trailingIndex(String text) {
    final match = RegExp(r'\.(\d+)$').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static String _unquote(String value) {
    final text = value.trim();
    if (text.length >= 2 &&
        ((text.startsWith('"') && text.endsWith('"')) ||
            (text.startsWith("'") && text.endsWith("'")))) {
      return text.substring(1, text.length - 1);
    }
    return text;
  }

  /// `class.a b` → `.a.b`；`id.x` → `#x`；`tag.div` → `div`
  static String _normalizePrefix(String text) {
    if (text.isEmpty) return '';
    final classMatch = RegExp(r'^class\.(.+)$').firstMatch(text);
    if (classMatch != null) {
      final classes = classMatch
          .group(1)!
          .split(RegExp(r'\s+'))
          .where((value) => value.isNotEmpty)
          .map((value) => '.$value');
      return classes.join();
    }
    final idMatch = RegExp(r'^id\.(.+)$').firstMatch(text);
    if (idMatch != null) return '#${idMatch.group(1)!.trim()}';
    final tagMatch = RegExp(r'^tag\.([A-Za-z][-A-Za-z0-9]*)$').firstMatch(text);
    if (tagMatch != null) return tagMatch.group(1)!;
    return text;
  }

  /// 在给定根节点上执行。
  List<Element> selectOn(Element root) {
    if (_isTextOnly) {
      return _filter([root, ...root.querySelectorAll('*')]);
    }
    final candidates = css.isEmpty
        ? <Element>[root]
        : (() {
            try {
              return root.querySelectorAll(css);
            } catch (_) {
              return <Element>[];
            }
          })();
    return _filter(candidates);
  }

  List<Element> selectIn(Document root) {
    final documentElement = root.documentElement;
    if (documentElement == null) return const [];
    if (_isTextOnly) {
      return _filter([documentElement, ...root.querySelectorAll('*')]);
    }
    final candidates = css.isEmpty
        ? <Element>[documentElement]
        : (() {
            try {
              return root.querySelectorAll(css);
            } catch (_) {
              return <Element>[];
            }
          })();
    return _filter(candidates);
  }

  /// 只给了文本条件，没有 CSS 选择器。
  bool get _isTextOnly =>
      css.trim().isEmpty &&
      contains.isEmpty &&
      attributeRegex.isEmpty &&
      (textContains != null && textContains!.isNotEmpty);

  List<Element> _filter(List<Element> candidates) {
    var result = candidates;
    if (textContains case final needle? when needle.isNotEmpty) {
      result = result
          .where((element) => element.text.contains(needle))
          .toList(growable: false);
    }
    for (final needle in contains) {
      result = result
          .where((element) => element.text.contains(needle))
          .toList(growable: false);
    }
    for (final rule in attributeRegex) {
      result = result
          .where((element) {
            final value = element.attributes[rule.attribute];
            return value != null && rule.pattern.hasMatch(value);
          })
          .toList(growable: false);
    }
    if (index case final at?) {
      if (at < 0 || at >= result.length) return const [];
      return [result[at]];
    }
    return result;
  }
}

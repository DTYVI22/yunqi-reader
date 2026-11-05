// 临时诊断：验证 ## 替换与选择器解析
import 'package:html/parser.dart' as html_parser;
import 'package:wenku8_flutter/legado/html_query.dart';
import 'package:wenku8_flutter/legado/rule_engine.dart';

void main() {
  const html = '''
<html><body>
<div class="info">
  <span>类别：玄幻</span>
  <span>作者：花下灯</span>
</div>
<div class="librarylist"><li><div class="info"><span>X</span></div></li></div>
</body></html>''';
  final doc = html_parser.parse(html);
  const engine = RuleEngine();
  final context = RuleContext(baseUrl: 'http://example.com');

  // 1) 选择器解析
  for (final sel in ['class.info', 'tag.span.1', 'text']) {
    final parsed = ParsedSelector.parse(sel);
    print('parse("$sel") -> css=${parsed?.css} index=${parsed?.index} '
        'isValue=${parsed == null}');
  }

  // 2) 取值
  print('--- 取值 ---');
  print(engine.evaluate('class.info@tag.span.1@text', doc, context).strings);

  // 3) ## 替换
  print('--- 替换 ---');
  final value = engine.evaluate(
    'class.info@tag.span.1@text##作者：',
    doc,
    context,
  );
  print('结果: ${value.strings}');

  // 4) 带替换文本
  final renamed = engine.evaluate(
    'class.info@tag.span.1@text##(作者：)##AU:',
    doc,
    context,
  );
  print('带替换: ${renamed.strings}');
}

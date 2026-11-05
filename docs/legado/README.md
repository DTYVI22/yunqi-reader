# legado 书源规则参考

上游文档：<https://mgz0227.github.io/The-tutorial-of-Legado/Rule/source.html>
（作者 Celeter / 喵公子，更新时间 2024-02-27）

## 这里的文件

| 文件 | 用途 |
|---|---|
| `source-rule.html` | 原样存档，用浏览器打开，排版最好看 |
| `source-rule.md` | 纯文本版，用来 grep 检索 |
| `../tools/convert_legado_doc.py` | 把上面的 HTML 重新转成 md（文档更新时用） |

重新生成：

```powershell
# 注意用 DSH 自带的 python，系统 python 没装 lxml
& "C:\Users\<你>\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe" `
  tools/convert_legado_doc.py docs/legado/source-rule.html docs/legado/source-rule.md
```

## 怎么查

书源跑不出结果时，先按现象找下面这行，再 grep 文档里的关键词。

| 现象 | 先 grep 这些词 | 文档里的对应章节 |
|---|---|---|
| 搜索返回空 | `searchUrl` `POST请求` `key` `page` | 2、Legado的特殊规则 / 4、搜索 |
| 搜索要 POST 却发成了 GET | `method` `body` `charset` | 2、GET请求 / POST请求 |
| 列表一条都取不到 | `bookList` `JSOUP之Default` `位置` | 1、语法说明 / 4、搜索 |
| 取到的书名带多余文字 | `##正则表达式##替换内容` `替换内容为空` | 1、正则之净化 |
| 只要第一个匹配 | `###` `正则之OnlyOne` | 1、正则之OnlyOne |
| 章节列表倒序 | `首字符使用负号` `列表倒置` | 7、目录 / 1、语法说明 |
| 目录只有一页 | `nextTocUrl` `支持url数组` | 7、目录 |
| 正文取不全 | `content` `nextContentUrl` `webJs` | 8、正文 |
| 正文需要点开或解密 | `webJs` `WebViewJs` | 8、正文 |
| 中文乱码 | `charset` `gbk` | 2、URL必知必会 |
| 需要拼接变量 | `@put` `@get` `java.put` | 2、变量的put与get |
| 规则里要写条件判断 | `{{}}` `{}` `@@` 前缀 | 2、`{{}}`与`{}`规则 |
| 三个列表要交错取值 | `%%` | 1、自定义三种连接符号 |
| 要取数组切片 | `[start:end:step]` `[!index` | 1、JSOUP之Default |

查具体写法：

```powershell
# 在 md 里找某个规则怎么写
Select-String -Path docs/legado/source-rule.md -Pattern "nextTocUrl" | ForEach-Object { $_.Line }
```

## 本项目当前支持到哪

对照文档，`lib/legado/` 里已经实现的：

- JSOUP 默认规则：`class.` / `id.` / `tag.` / `text.` / 位置索引（含负数）/ `children`
- 取值器：`text` `textNodes` `ownText` `html` `all` 和任意属性名
- 正则净化：`##正则##替换`
- 连接符：`&&`、`||`
- 模板：`{{key}}`、`{{page}}`、`{{baseUrl}}`
- 选择器扩展：`:contains(...)`、`[attr~=正则]`
- URL 选项：`地址,{"method":"POST","body":"...","charset":"gbk","headers":{...}}`
- 目录分页：`nextTocUrl`（支持返回数组）
- 编码：响应头 → `<meta charset>` → 乱码回退 GBK

**还没实现**：

- 正则 AllInOne（`:` 开头，用 `$1` `$2` 取捕获组）——目录/列表常用，纯正则就能做
- `chapterList` 首字符 `-` 反序
- `%%` 交错取值、`[start:end:step]` 切片、`!` 排除索引
- `##正则##替换###`（只替换首个）
- `@put` / `@get` 变量
- `@XPath:` / `//` 开头的 XPath 规则
- 所有脚本：`@js:`、`<js>`、`java.*`、`{{js}}`
- `webView` / `webJs`（需要 WebView 渲染）
- `exploreUrl` 发现页

判断逻辑在 `LegadoBookSource`：

```dart
coreRuleFields = {bookList, name, bookUrl, chapterList, chapterName,
                  chapterUrl, content, tocUrl}   // 加 searchUrl

usesScriptInCore   // 核心字段用脚本 → 整个源不可用
degradesScriptFields // 只有边缘字段用脚本 → 源可用，那几项留空
```

## 一个容易误判的现象

书源站点抓的是原版站内容，而原版站做了防盗版混淆——正文里会混入别的小说的段落。这是源与站点层面的固有情况，不是规则解析错误，也不需要清洗。遇到就换源。

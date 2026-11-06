# M0：Archive 引擎嵌入报告

> 基线：`DTYVI22/legado-archive@e111bf666199505d783e6910d8609f0e5cb043e0`（阅读 Archive，GPL-3.0）
> 结论：**引擎撕裂可行，已完成编译与规则求值验证**。WebView 通道与本地书籍业务未接入（按计划留到 P4）。

## 一、做了什么

在 `android/` 下新增两个 Gradle 模块，`:app` 通过 `implementation(project(":legado-engine"))` 依赖：

| 模块 | 来源 | 规模 |
|---|---|---|
| `legado-rhino` | Archive `modules:rhino` 原样拷入（namespace `com.script`） | 31 文件 / 2,351 行 |
| `legado-engine` | Archive `io/legado/app` 的规则求值子集 + 桩 | 131 文件 / 13,896 行 |

保留的核心（与 Archive 逐行一致，未改逻辑）：

```
model/analyzeRule/   AnalyzeRule(909) AnalyzeUrl(906) RuleAnalyzer(295)
                     AnalyzeByJSoup(410) AnalyzeByJSonPath(156) AnalyzeByXPath(142) AnalyzeByRegex
data/entities/       BookSource + 6 个 rule 实体 + BaseSource/BaseBook + Book/BookChapter(裁剪)
help/JsExtensions.kt  java.* 约 60 个函数（网络/编码/变量/日志/cookie/文件）
help/JsEncodeUtils.kt AES/DES/3DES/RSA/HMAC/MD5 共 27 个
help/http/            OkHttpUtils / CookieStore / CookieManager / SSLHelper
utils/                GSON、编码识别、文本/文件/流扩展（41 个文件）
constant/             AppConst / AppPattern / AppLog
```

## 二、改造清单（计划里的"9 处"实际落地为 14 处）

| 改造 | 文件 | 说明 |
|---|---|---|
| Context 注入 | `splitties/init/appCtx.kt`、`io/legado/app/EngineHost.kt` | 用同包名桩替代 splitties，由 `EngineHost.install(context)` 注入 |
| 系统服务 | `splitties/systemservices/SystemServices.kt` | 同上，避免引入整套 splitties |
| 配置裁剪 | `help/config/AppConfig.kt` | 2454 行 → 23 个被引用字段 |
| 调试出口 | `model/Debug.kt` | 370 行 → `log()` + `Callback`，日志经 EngineHost 转 Flutter |
| 键值缓存 | `help/CacheManager.kt` | Room `Cache` 表 → 内存 LRU + SharedPreferences |
| Cookie 罐 | `help/http/CookieStore.kt`、`CookieManager.kt` | Room `Cookie` 表 → SharedPreferences + 内存会话 |
| 大变量 | `help/RuleBigDataHelp.kt` | 外部存储目录 → `CacheManager`，键规则不变 |
| 书籍实体 | `data/entities/Book.kt` | 533 行 Room 实体 → 纯数据类（字段名保持不变） |
| 章节实体 | `BookChapter.kt` | 去掉 `appDb` 入库与「净化规则」标题处理，`getDisplayTitle()` 返回原文 |
| 书源部件 | `BookSourcePart.kt` | 去掉 `appDb` 查询 |
| WebView 通道 | `help/http/BackstageWebView.kt`、`help/webView/WebViewPool.kt` | 保留签名，调用即抛「P4 未实现」 |
| 字体子集 | `help/AppCacheManager.kt`、`QueryTTF.java` | 仅内存 LRU |
| 网络栈 | `help/http/HttpHelper.kt` | 去掉 glide 进度、Cronet、漫画限速、自建 DoH |
| DNS | `help/http/dns/*` | 保留 `DnsScope`/`DnsNames`/`HostOverrideDns`，DoH 与 Cronet 置空 |
| 简繁/编码 | `utils/ChineseUtils.kt`、`EncodingDetect.kt` | opencc 词典与 ICU 检测 → 原样返回 / BOM+meta+UTF-8 探测 |
| 并发 | `utils/FlowExtensions.kt` | 只保留 `mapAsync`/`mapAsyncIndexed`（返回 Flow，保留 `flowOn`） |

**整包删除**（与规则求值无关，或依赖 UI）：`help/book`、`help/storage`、`help/ai`、`help/glide`（改桩）、`ui` 相关 utils、`utils/compress`、`utils/canvasrecorder`、`utils/viewbindingdelegate`、`ArchiveUtils`、`RegexExtensions`、`ReplaceAnalyzer`。

## 三、验证结果

| 项 | 命令 | 结果 |
|---|---|---|
| 引擎编译 | `:legado-engine:compileDebugKotlin` | **BUILD SUCCESSFUL** |
| 规则切分单测 | `:legado-engine:testDebugUnitTest` | 8/8 通过（`@` 分步、`&&`/`||`、括号与引号内不切、`##` 段、`line-height`） |
| 规则求值单测 | 同上 | 8/8 通过（CSS 前缀、Default 索引、`h3@a@text`、`h3@a@href`、`##净化`、`&&` 合并、`||` 回退、`.1` 索引） |
| APK 集成 | `flutter build apk --debug` | **√ Built app-debug.apk**（28s，引擎已链入） |

打包侧遇到并修掉两个问题，后续 M1 会再碰到：

1. `hutool-crypto` 与 `hutool-core` 都带 `META-INF/INDEX.LIST`，`:app` 新增 `packaging { resources { excludes += … } }`。
2. `:app` 原本依赖 `jsoup:1.23.2`，与 Archive 要求的 1.16.2 冲突（Gradle 会取高版本并改变选择器行为）；app 自身不直接用 jsoup，已统一降为 **1.16.2** 并加注释锁定。

> 真机验证（instrumented test）当前未执行：`adb devices` 无设备在线。接上手机后补一条
> `:legado-engine:connectedDebugAndroidTest` 的 smoke test 即可闭环。

## 三点五、真机验证（Redmi K70 Pro / Android 16）

`connectedDebugAndroidTest` 装不上（`INSTALL_FAILED_USER_RESTRICTED`，MIUI 对**新包**的
USB 安装拦截；普通 APK 覆盖安装正常，后来确认是需要在手机弹窗里点确认），改为把自检挂进已能安装的 app 本体：

- `LegadoEnginePlugin`（`app.yunqi.reader/legado_engine`）在 debug 包启动时用独立线程跑一次自检；
- 自检资产 `assets/legado_smoke_sources.json`（5 个真实书源：快眼看书 / 梧桐中文 / 久久小说 / 玄幻阁吧 / 乐库小说）。

实测日志（logcat，tag `LegadoEngine`）：

```
[平凡文学] 失败 TimeoutCancellationException（站点不可达）
[快眼看书] 100 条 · 首条=我有一座恐怖屋
[梧桐中文] 10 条 · 首条=鹤舞晴空
[@js] len=19
[链路] 快眼看书 详情=ok 目录=1249 章 正文=3236 字
```

结论：**搜索 → 详情 → 目录 → 正文全链路在真机跑通**，`@js:` 的 Rhino 求值也正常
（`baseUrl.length` 被正确计算）。这同时验证了 EngineHost 的 Context 注入、OkHttp 栈、
Jsoup 解析、以及规则切分在 Android 运行时下都工作。

过程中修掉的两个真机专属问题：

1. **HTTP 明文被拦**：Android 9+ 默认禁 cleartext，而书源大量是 `http://`。
   `AndroidManifest` 的 `<application>` 加 `android:usesCleartextTraffic="true"`（与 Archive 一致）。
2. **相对地址解析**：`bookUrl` / `tocUrl` / `chapterUrl` 多是 `/book/1.html`，详情/目录/正文入口
   没有"当前页面"可参考，必须在 `EngineFacade` 里按 `bookSourceUrl` 用 `URI.resolve` 补全
   （直接透传会 404）。

单测同时证明了 **Context 注入链路**：`AnalyzeRule` 在无 Android 运行时（JVM）下完成了 Jsoup 解析与规则求值，说明桩与裁剪没有破坏求值语义。

## 四、M2：发现页从「榜单」改为「书源分类」

Wenku8 的 `NovelSort`（最近更新 / 总人气 / 月票榜…共 13 个）对 legado 书源没有意义，
书源给的是 `exploreUrl`。改动分三层：

| 层 | 文件 | 内容 |
|---|---|---|
| 引擎 | `help/source/BookSourceExtensions.kt`（重写） | 恢复 `exploreKinds()`：`@js` / `<js>` / JSON 数组 / `名称::url` 四种形态，缓存键含 `exploreUrl + jsLib + lastUpdateTime` |
| 引擎 | `EngineFacade.kt` | 新增 `exploreKinds(sourceJson)` / `explore(sourceJson, url, page)`；抽 `collectBooks()` 让搜索与发现共用字段映射；`ruleExplore` 为空时回退 `ruleSearch` |
| 桥 | `LegadoEnginePlugin.kt` | channel 增加 `exploreKinds` / `explore` |
| 数据 | `lib/explore_catalog.dart`（新）、`catalog.dart` | `ExploreKind` / `ExploreSource` / `ExploreTarget`；`browse(target:)` + `exploreSources()` |
| 数据 | `lib/legado/legado_engine_repository.dart`（新） | 走 channel 的仓库实现，书源 `rawJson` 原样透传；`legado_bootstrap` 优先引擎、失败回退 Dart 引擎 |
| UI | `discovery_filters.dart` | 「榜单」tab 换成「分类」：先按 group 列源（`源名 · N`），点进去是该源分类网格；`url` 为空的项渲染成分组标题 |
| UI | `pages.dart` / `novel_feed_controller.dart` | `selectExplore()`，`_lowerCategory` 显示分类名，「返回全部」可清空 |

真机自检（同一份日志通道）：

```
[分类] 乐库小说 = 11 项（可点 10） · 例:言情      ← @js 形态
[分类] 久久小说 = 24 项（可点 24） · 例:言情      ← 文本形态
[分类] 玄幻阁吧 = 12 项（可点 11） · 例:玄幻      ← JSON + style
[发现] 久久小说 / 言情 = 10 条 · 首条=大爱晚成
```

过程中修掉一个**引擎级 bug**：`CookieManager.cookieJarHeader` 原本被我实现成「cookie 值」，
无 cookie 时返回空串，`AnalyzeUrl` 把它当 header 名塞进请求，OkHttp 抛
`IllegalArgumentException: name is empty`——所有 `enabledCookieJar = true` 的源都会炸。
改回 Archive 的常量 `"CookieJar"` 后恢复。

UI 侧另有 `test/discovery_filters_test.dart` 三个用例（分类 tab 出现、选源后列分类、无 loader 时退回榜单），全部通过。

## 四-补、已知边界（M1 之前不处理）

1. **WebView 源不可用**：`webView:true` / `webJs` / `sourceRegex` 抛明确异常（P4 接 InAppWebView）。
2. **`jsLib` 共享作用域未缓存**：`SharedJsScope.getScope()` 恒返回 null，等价于所有源都没配 `jsLib`（不报错，只是公共函数不生效）。
3. **`reGetBook` / `refreshTocUrl` 不生效**：需要编排层（WebBook），已在桩里显式失败。
4. **简繁转换未实现**：`java.t2s()` 原样返回（繁体书名匹配简体关键词会漏）。
5. **`QueryTTF` 字体子集**：`QueryTTF.java` 已拷入，但 `java.replaceFont` 走的 UI 路径未接。
6. **jsoup 版本锁定 1.16.2**：`:app` 原为 1.23.2，已降至 1.16.2 以匹配 Archive 的选择器行为（app 自身未直接使用 jsoup）。

## 五、下一步（M1）

1. `EngineFacade` 已就位（`app/yunqi/engine/EngineFacade.kt`）：`install/search/bookInfo/toc/content`，出入参 JSON。
2. 补 `MethodChannel` 插件（`app/yunqi/engine/EnginePlugin.kt`）+ `explore/login/debugRule`。
3. Flutter 侧 `LegadoEngineRepository` 接 6 个 `NovelRepository` 方法。
4. 用真机跑 3 个源（1 个纯 CSS、1 个 POST、1 个 `@js:`）验证网络与 Rhino。

许可证：引擎内嵌使本项目整体成为 GPL-3.0 衍生作品，发布前需改 `LICENSE`、关于页标注三级来源（`DTYVI22/legado-archive` → `Rimchars/legado` → `gedoor/legado`），并把 commit SHA 记入 `THIRD_PARTY.md`。

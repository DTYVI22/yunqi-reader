# 项目工作说明

给参与这个项目的人（包括 AI 助手）看的前置说明。读完这一页，你就不用再花时间重新踩一遍环境和源码的坑。

---

## 一、这个项目现在是什么

上游是 [mikufoxxx/Wenku8_Flutter](https://github.com/mikufoxxx/Wenku8_Flutter)（轻小说文库 Flutter 客户端，GPL-2.0）。

**重要前提：上游公开的源码是不完整快照，原样 clone 下来编译不过。**

上游用 `tools/check_public_source.py` 在发布时主动剔除了一批文件，但 import 语句没跟着改，导致 Dart 编译阶段直接报「找不到文件」。我们这边已经补齐了缺失部分，补齐方式是**写桩**（stub）：接口签名与调用点严格对齐，功能本身按「不可用」处理，界面上给明确提示，不会假装能用。

因此当前仓库的状态是：**能编译、能装、核心阅读流程可用，上游剔除掉的那部分功能是桩。**

### 上游剔除了什么（现已补桩）

| 类别 | Dart 侧 | Kotlin 侧 |
|---|---|---|
| 局域网续读/传书 | `lan_reading_sync.dart`、`lan_reading_page.dart`、`lan_handoff_widgets.dart` | `LanReadingConfigPlugin`、`LanDiscoveryPlugin` |
| 自定义 SSML 语音 | `listening/custom_tts.dart`、`custom_tts_page.dart` | `CustomSpeechConfigPlugin` |
| 播放增强 | `listening/enhancement.dart`、`enhancement_controls.dart` | `ListeningEnhancementPlugin` |
| 本地扫描/批量导入 | `local_import_batch.dart`、`local_book_scanner.dart`、`local_scan_page.dart`、`local_scan_selection.dart`、`local_book_batch_page.dart` | `BookArchiveImport`、`BookFolderScanner`、`BookMarkupImport`、`BookPdfImport` |
| 桌面小组件渲染 | `reading_widget_skin.dart`、`reading_widget_reference.dart`、`reading_widget_reference_capture.dart`、`reading_widget_skin_picker.dart` | — |
| 阅读报告页 | `reading_report_page.dart` | — |
| 翻页纸张几何 | `reader_paper_geometry.dart`（现为平面版） | — |
| 便携文档转换 | `portable_book_prepare.dart` | — |

桩文件顶部都有一行注释说明「公开快照未包含此文件」，看到就知道这里不是完整实现。

### 另外两处上游自身的不一致（已修）

- `pubspec.yaml` 声明了 `assets/reading_previews/` 和 `assets/report/`，但实际文件在 `assets/reading_art/`，后者目录根本不存在。已改成 `assets/reading_art/` 并同步改了 `reading_visual_theme.dart` 里的路径。
- `android/app/build.gradle.kts` 的 `minSdk` 是 24，但依赖里的 poi 5.5.1 用了 `MethodHandle.invoke`，D8 要求 `min-api >= 26`。已改成 26。

---

## 二、开发环境

本机已经配好，**新开终端即可直接构建**，不需要再做任何初始化。

| 组件 | 位置 / 版本 |
|---|---|
| Flutter | `E:\flutter`，3.41.5 stable，Dart 3.11.3（对应 `pubspec.yaml` 的 `sdk: ^3.11.3`） |
| JDK | `C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot`（`JAVA_HOME` 用户级已指向它） |
| Android SDK | `E:\Android\Sdk`（platform 35/36，build-tools 35/36） |
| NDK | 28.2.13676358（项目有 C++ native，等价于 `flutter.ndkVersion`） |
| CMake | 3.22.1 |
| Gradle 缓存 | `E:\gradle-home`（`GRADLE_USER_HOME` 已设，**不要让它回到 C 盘**，C 盘只剩 26G） |
| 测试机 | Redmi K70 Pro，Android 16 / API 36，arm64-v8a，`adb` serial `2f04bd2c` |

### 常用命令

```powershell
# 构建（在项目根目录）
flutter build apk --debug

# 只做静态检查（比 build 快得多，改完先跑这个）
flutter analyze --no-pub

# 跑书源引擎的端到端测试
flutter test test/legado_e2e_test.dart

# 装到手机并启动
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n app.yunqi.reader/org.mewx.wenku8_flutter.MainActivity
```

`applicationId` 是 `app.yunqi.reader`，应用名「云栖书架」，版本从 `0.1.1+112` 起。

---

## 三、环境层面的坑（都验证过，别再花时间重试）

### 1. Gradle 发行包下载会卡死

`services.gradle.org` 只是个跳板，真实文件在 **GitHub Releases**，本机直连会在 307 之后超时。

`android/gradle/wrapper/gradle-wrapper.properties` 已改成腾讯镜像：

```
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.14-all.zip
```

上游如果升级 Gradle 版本，记得同步改这一行。

### 2. Maven 依赖走 Cloudflare 会冻结

`maven.google.com` 本机实测 21 秒无响应；`plugins.gradle.org`、`repo.maven.apache.org` 在批量拉包时会挂住（实测 153 个连接零吞吐，30 分钟缓存不增长）。

解决办法是全局 init 脚本 `E:\gradle-home\init.d\mirrors.gradle`，把 `google()` / `mavenCentral()` / `gradlePluginPortal()` 的 URL 重写成阿里云同源镜像。**这个文件对所有 Gradle 项目生效**，删掉即恢复原状。

配好之后同一个构建从「30 分钟无进展」变成「62 秒完成」。

### 3. 强杀 Gradle 会留下损坏的缓存

报错长得像这样：

```
Could not move temporary workspace (...) to immutable location (...)
```

去 `E:\gradle-home\caches\8.14\transforms\` 下删掉名字带 `-<uuid>` 后缀的临时目录即可。

正常停 daemon 用这条（**必须带 `GRADLE_USER_HOME`**，否则 `--stop` 会去 `~/.gradle` 里找，报「没有 daemon 在跑」）：

```powershell
$env:GRADLE_USER_HOME='E:\gradle-home'
.\android\gradlew.bat --stop
```

### 4. 小米/红米装 APK 报 `INSTALL_FAILED_USER_RESTRICTED`

需要两步，缺一不可：

1. 开发者选项里打开 **「USB安装」**（默认关闭）
2. **`adb kill-server` 再 `adb start-server`**

第 2 步是关键——只打开关不重启 adb，照样失败，因为已运行的 adb 会话拿着旧状态。

改系统设置（`install_non_market_apps` 之类）对这个拦截无效，别浪费时间。

### 5. GitHub 大文件下载很慢

`codeload.github.com` 和 `api.github.com/tarball` 实测只有 26–31 KB/s。`gh-proxy.com` 约 84 KB/s。63MB 的仓库包建议走后者，或者直接开代理。

---

## 四、代码结构要点

### 数据层是「源中立」的

这是上游原本的设计，也是加新书源能这么顺的原因：

```dart
// lib/catalog.dart:280 —— 只有 6 个抽象方法，其余全有默认实现
abstract class NovelRepository {
  Future<List<Novel>> list();
  Future<Novel?> find(int id);
  Future<List<Novel>> search(String query);
  Future<Novel> detail(Novel novel);
  Future<List<NovelChapter>> chapters(int id);
  Future<String> chapterContent(int novelId, NovelChapter chapter);
}
```

`lib/app_repository.dart` 把远程源作为**参数注入**，`lib/main.dart` 决定注入哪一个。

### id 区间是区分书源的方式

```dart
// lib/book_identity.dart
const localBookIdStart = 0x60000000;
bool isLocalBook(int id) => id >= localBookIdStart;

// lib/legado/book_registry.dart
const legadoBookIdStart = 0x10000000;   // 必须 < localBookIdStart
```

**加新区间时一定要放在 `localBookIdStart` 之前。** 放后面会被 `isLocalBook()` 判成 true，App 转而去本地文件里找原书，界面上报「本地原书不存在」。这个坑只有在真机上才暴露，`flutter test` 里没有 `OfflineNovelRepository` 那层包装。

---

## 五、legado 书源引擎（`lib/legado/`）

> **书源规则出问题时，先查 `docs/legado/`。** 那里存了 legado 官方规则文档存档
> （`source-rule.html` 原文 + `source-rule.md` 可检索），还有一份按现象编排的
> 检索索引（`README.md`：什么现象该 grep 什么词，以及本项目已实现/未实现的
> 语法清单）。不要凭猜测改规则引擎。

为了给这个阅读器加「开源阅读」书源支持而写的，是新增模块，不属于上游。

```
book_source.dart          书源模型 + JSON 解析 + usesScript/isSupported 判定
html_query.dart           legado 选择器 → package:html 的适配层
rule_engine.dart          规则求值 + resolveUrl
legado_client.dart        HTTP 与编码识别
book_registry.dart        int id ↔ URL 映射（持久化在 SharedPreferences）
legado_repository.dart    NovelRepository 的六个方法
legado_bootstrap.dart     从 assets 装配
source_store.dart         内置源 + 导入源 + 启用状态
source_page.dart          书源管理界面（设置 → 书源）
```

配套：`assets/legado/` 是**空目录**——仓库不附带任何书源，理由与自定义方式见其中的 `README.md`。`tool/` 下有探针脚本（单源、批量、诊断），`docs/legado/` 是规则文档的本地参考（不入库）。

### 语法覆盖范围

基于 177 个书源、3693 个规则字段的统计与实测：

| 语法 | 占比 | 状态 |
|---|---|---|
| 纯 CSS 选择器（含 `class.` / `id.` / `tag.x.n` / `text.` 前缀、负数索引） | 74.5% | ✅ |
| `##正则##替换` | 14.6% | ✅ |
| `&&` / `\|\|` 组合 | 6.9% | ✅ |
| `{{}}` 模板、`{{baseUrl}}` | 3.7% | ✅ |
| `:contains()`、`[attr~=正则]` | — | ✅ |
| URL 选项 `地址,{"method":"POST","body":"..","charset":"gbk"}` | 57 个源 | ✅ |
| `nextTocUrl` 目录分页（含返回数组） | 35 个源 | ✅ |
| `@XPath:` | 0 个 | 不需要 |
| 正则 AllInOne（`:` 开头 + `$1`/`$2`）、`-` 反序、`%%`、`[start:end]`、`###`、`@put/@get` | — | ❌ 待做，都不需要 JS |
| `@js:` / `<js>` / `java.*` / `webView` / `webJs` / `exploreUrl` | — | ❌ 需要脚本或 WebView |

**可用率**：177 个源里 **111 个可执行**（其中 25 个是「仅边缘字段用脚本」，那几个字段留空），63 个核心字段依赖脚本、真的跑不了。

判断逻辑在 `LegadoBookSource`：

```dart
coreRuleFields = {bookList, name, bookUrl, chapterList, chapterName,
                  chapterUrl, content, tocUrl}   // 加上 searchUrl

usesScriptInCore     // 核心字段用脚本 → 整个源不可用
degradesScriptFields // 只有边缘字段用脚本 → 源可用，那几项留空
```

**别把过滤条件设成「任何字段含脚本就废掉」**——那会砍掉 34 个本来能用的源。

### 一个踩过的坑：POST 请求

`searchUrl` 可以是 `https://a.com/api,{"method":"POST","body":"key={{key}}"}`。如果把整串当 URL 去 GET，等于向带 JSON 的地址请求，**43 个源会静默返回空结果**（UI 上还显示「可用」）。

所以：先 `LegadoClient.splitOptions()` 拆出地址和选项，再 `resolveUrl` 解析地址，最后拼回去交给 `get()`。顺序反了 `Uri.resolve` 会把 JSON 当路径拼进 URL。

### 两个必须知道的实现细节

- **`resolveUrl` 必须用 `Uri.resolve`**，不能用字符串拼接。规则里的相对地址是相对**当前页面**的，页面路径可能很深（`/modules/article/search.php?...`），拼接会把查询串留在中间，拼出 `search.php?.../106386.html` 这种地址。
- **GBK 站点要真正解码**。Dart 内置只认 UTF-8/Latin-1，`package:charset` 提供 `gbk.decode`。判断顺序是：响应头 charset → `<meta charset>` → 试解 UTF-8 看替换字符比例。

### 正文里混进别的小说段落：不是 bug

部分书源站点抓取的是原版站内容，而**原版站做了防盗版混淆**——正文里会掺入别的小说的段落。这是源和站点层面的固有现象，不是规则解析错误，代码里不做清洗。遇到就换源。

### 搜索引擎的取舍

搜索是「首批必跑，够数或超时就收手」：并发 24、单源超时 8 秒、累计 15 条或超 15 秒就返回。168 个源全跑一遍要按分钟算，所以做了这个取舍。

代价是**速度快了结果会少**（同一关键词实测 105 秒/20 条 → 22 秒/3 条）。参数在 `LegadoRepository` 构造函数里：`searchConcurrency`、`sourceTimeout`，以及 `search()` 里的 `deadline` 和 `enough`。

---

## 六、行为约定

1. **不要自作主张 `git commit` / `git push`。** 改动完成后等明确指令。
2. **改动前先跑 `flutter analyze --no-pub`** 拿到基线，改完再跑一次对比。它比完整 build 快一个数量级。
3. **验证以真机为准。** 这个项目有多处「测试能过、真机报错」的情况（id 区间那次就是）。涉及界面和数据的改动，装到手机上点一遍。
4. **不要为了让某个界面消失而让接口报错。** 上游的 `offline_repository.dart` 依赖这些接口的一致性，一个 404 会连带整屏失效。
5. 桩文件里的「不可用」提示要保留。它们明确告诉用户「这个功能不在这份构建里」，不要改成静默失败。
6. 上游的 `tools/check_public_source.py` 会拒绝包含真实站点地址、密钥、局域网 IP 的提交。改动如果涉及这些内容，先跑一遍它。
---

## 七、发布到 GitHub 的注意事项

### 仓库里绝对不能出现的东西

`.gitignore` 已经覆盖，改动时别绕过：

| 路径 | 原因 |
|---|---|
| `android/key.properties`、`*.jks`、`*.keystore` | 签名材料。泄露等于任何人都能冒充发版；丢失则永远无法再发升级包 |
| `docs/legado/source-rule.html` / `.md` | legado 规则文档原作者的授权声明写明「禁止其他未获得本人授权的第三方软件使用」，随仓库分发属未授权使用。本地参考可以，入库不行 |
| `assets/legado/sources.json` | 书源指向的站点内容与可用性都不受控，随仓库分发既易过期也带来风险 |
| `legado-sources/` | 本地书源集合 |
| `build/`、`.dart_tool/` | 构建产物（`build/` 约 4.3 GB） |

### 为什么仓库不内置书源

上游自己的 `tools/check_public_source.py` 里就有 `CONNECTIVITY_PATTERNS` 专门拦真实站点地址——作者清楚这类内容的风险。我们沿用了同样的策略：应用装好是空书架，书源由使用者自行导入（`设置 → 书源 → 导入`）。

`assets/legado/` 是一个空目录，只放了一份 `README.md` 说明怎么自己内置一份。

### 签名

没有 `android/key.properties` 时，`build.gradle.kts` 会让 release 退回 **debug 签名**。这样发出去的包有两个问题：换机器后无法覆盖升级（签名不一致）、任何人都能用 debug 签名伪造同名包。

首次发布前生成一次，长期复用：

```powershell
keytool -genkeypair -v -keystore yunqi-release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias yunqi
```

`android/key.properties`：

```properties
storeFile=../yunqi-release.jks
storePassword=……
keyAlias=yunqi
keyPassword=……
```

`.jks` 和 `key.properties` **必须另存一份到仓库之外**。

### 版本号

`pubspec.yaml` 的 `version:` 与 `lib/updates/app_updates.dart` 的 `currentAppVersion` / `currentAppBuild` 要同步改。三处不一致会让「关于」页显示错版本。

当前：`0.1.1+112`。

### 更新检查

`lib/updates/app_updates.dart` 的 `officialUpdateRepository` 目前是**空字符串**，表示关闭更新检查——它是二开版本，跟进上游没有意义（包名、签名都不同，用户装了也覆盖不上）。

等自己的仓库建好后改回自己的：

```dart
const officialUpdateRepository = '<用户名>/<仓库名>';
```

`checksEnabled` 在仓库为空时返回 false，会一并隐藏「自动检查更新」和「项目介绍与下载」两个入口。

### 合规要点

- GPL-2.0 派生：保留 `LICENSE`，并在「关于」页与许可页标注「基于 Wenku8_Flutter 二次开发」+ 上游版权行。这几处是许可证要求，不能删
- README 只写「本地阅读器 + 支持 legado 书源格式」，不要写成「聚合全网小说」
- 明确「不内置、不运营任何在线书库」「书源由用户自行导入」

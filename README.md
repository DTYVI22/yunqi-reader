# 云栖书架

一个 Flutter 写的本地阅读器，支持导入开源阅读（legado）格式的书源。

基于 [Wenku8_Flutter](https://github.com/mikufoxxx/Wenku8_Flutter)（GPL-2.0）二次开发，
保留了它的阅读器、本地导入、听书、备份同步等能力，并把在线书源换成了 legado 规则引擎。

## 功能

- **本地导入**：TXT / EPUB，支持分卷、目录、章节跳转
- **阅读体验**：横排 / 竖排 / 滚动三种模式，按书保存字体、字号、行距、页边距
- **听书**：Edge 神经网络音色与系统 TTS，可缓存已生成的语音
- **书源**：导入 legado 格式书源，搜索、详情、目录、正文全链路
- **统计与备份**：阅读记录、书签、导出报告；本地备份与 S3 同步

## 书源

**本仓库不附带任何书源。** 应用装好后是空书架，需要自己导入：

1. 准备一份 legado 格式的书源（JSON 数组）
2. 打开「设置 → 书源 → 右上角导入」
3. 粘贴分享链接，或直接粘贴 JSON 文本

导入后的书源可以逐条启用或禁用。带脚本（`@js:` / `<js>` / `java.*`）的源会被标记出来：
核心字段依赖脚本的源无法执行，边缘字段（封面、分类、简介）依赖脚本的只是那几项留空。

本应用不运营任何在线书库，也不提供、不维护、不保证任何书源站点的可用性。

## 构建

环境：Flutter 3.41.5+（Dart 3.11.3）、JDK 17、Android SDK 36、NDK 28.2。

```bash
flutter pub get
flutter build apk --release
```

国内网络下 Gradle 发行包可能拉不下来，`android/gradle/wrapper/gradle-wrapper.properties`
已指向镜像；Maven 依赖走 Cloudflare 会挂住，可用全局 init 脚本重写仓库地址。

发布用的签名需要自备 `android/key.properties`（字段：`storeFile` / `storePassword` /
`keyAlias` / `keyPassword`），缺失时 release 会退回 debug 签名。

## 测试

测试用例不随仓库发布（沿用上游策略：测试留在开发树）。本地调试书源引擎时可以直接跑：

```bash
flutter test test/legado_e2e_test.dart
```

这些用例会读 `../legado-sources/source.json` 里的书源集合，需要自备。

## 许可

GPL-2.0，见 `LICENSE`。派生自 Wenku8_Flutter，上游版权归其贡献者所有；本仓库的修改同样以
GPL-2.0 发布。

第三方组件（音频、排版、字体、文档解析等）各自遵循其许可，完整清单见应用内
「设置 → 关于 → 开源许可与字体授权」。

## 免责

- 本项目是本地阅读工具，不运营在线书库，不发布、不附带小说文件
- 在线内容来自使用者自行导入的书源站点，其可用性、合规性以来源为准
- 小说、封面、插图归各自权利人所有；请仅阅读有权访问的内容，不得绕过访问限制或破解 DRM
- 本项目完全免费，没有任何付费版、激活码或解锁服务

上游项目的原始说明保留在 `README_ZH.md` / `README_EN.md`。

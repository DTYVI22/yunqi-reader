# 内置书源目录（可选）

这个目录是空的：仓库里不附带任何书源。

## 为什么不内置

书源指向的站点内容与可用性都不由本项目控制，随仓库分发一份书源列表既容易过期，
也会让项目承担不必要的风险。书源由使用者自行导入与维护。

## 想自己内置一份怎么做

把符合 legado 格式的书源数组存成 `sources.json` 放在这个目录，重新构建即可。
首启时会自动读取，之后仍可在「设置 → 书源」里逐条启用或禁用。

```json
[
  {
    "bookSourceName": "示例书源",
    "bookSourceUrl": "https://example.com",
    "bookSourceType": 0,
    "searchUrl": "/search?q={{key}}",
    "ruleSearch": { "bookList": ".item", "name": "h3@text", "bookUrl": "a@href" }
  }
]
```

只保留纯 CSS 规则的源最稳；核心字段（`bookList` / `name` / `bookUrl` /
`chapterList` / `chapterUrl` / `content` / `tocUrl` / `searchUrl`）用到脚本的源会被跳过，
边缘字段（封面、分类、简介）用到脚本则只是那几项留空。

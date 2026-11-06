package io.legado.app.help.http.dns

/**
 * 网络请求分组。Archive 用它给不同业务配不同的 DNS/DoH 策略；引擎不内置
 * DoH（Flutter 侧如需再接管），但保留枚举值，规则与限速逻辑按 scope 区分。
 */
enum class DnsScope(val key: String, val title: String) {
    READING("reading", "书源、搜索与正文"),
    IMAGE("image", "封面、漫画与正文图片"),
    AI("ai", "AI、MCP 与 AI 工具"),
    MEDIA("media", "HTTP 朗读与音视频"),
    WEBSOCKET("websocket", "脚本 WebSocket"),
    SYNC("sync", "WebDAV 与云同步"),
    IMPORT("import", "在线导入"),
    RELAY("relay", "远程分享与中继"),
    OTHER("other", "其它应用请求")
}

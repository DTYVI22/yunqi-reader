package io.legado.app.help.http

import io.legado.app.help.webView.WebViewPool

/**
 * 后台 WebView 通道（`webView: true` / `webJs` / `sourceRegex`）。
 *
 * Archive 用真实 WebView 加载页面、注入脚本、嗅探媒体资源。纯 Flutter 宿主里
 * 这需要 InAppWebView 配合（计划 P4）。第一阶段保留完整签名并显式失败：带
 * `webView` 选项的书源会得到明确的错误，而不是静默的空正文。
 */
class BackstageWebView(
    private val url: String? = null,
    private val html: String? = null,
    private val tag: String? = null,
    private val javaScript: String? = null,
    private val sourceRegex: String? = null,
    private val headerMap: Map<String, String>? = emptyMap(),
    private val delayTime: Long = 0L,
    private val poolScope: WebViewPool.Scope = WebViewPool.Scope.GLOBAL,
    private val cacheFirst: Boolean = false,
    private val timeout: Long = 10000L,
    private val result: String? = null,
    private val isRule: Boolean = false
) {

    fun getStr(): String? = error("webView 通道尚未接入（P4）")

    fun getStrResponse(): StrResponse = error("webView 通道尚未接入（P4）")
}

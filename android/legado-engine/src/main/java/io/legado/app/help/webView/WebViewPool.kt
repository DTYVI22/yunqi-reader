package io.legado.app.help.webView

/**
 * WebView 池的作用域标记。
 *
 * Archive 用它在后台维护若干隐藏 WebView 实例（登录、webJs 解密、资源嗅探）。
 * 引擎第一阶段不实现 WebView 通道（计划 P4），这里只保留枚举以对齐构造签名。
 */
object WebViewPool {

    enum class Scope {
        GLOBAL,
        LOGIN,
        DEBUG,
        SOURCE
    }
}

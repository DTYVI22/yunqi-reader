package io.legado.app.help.http

import okhttp3.Headers
import okhttp3.Request
import okhttp3.Response
import io.legado.app.utils.NetworkUtils
import java.net.HttpURLConnection

/**
 * 会话级 Cookie 与请求头注入。
 *
 * Archive 原实现同时处理 OkHttp 的 `Set-Cookie`、WebView 的 CookieManager 与
 * 「登录头」缓存。引擎只需要前两项，且 WebView 部分在 Flutter 侧由 InAppWebView
 * 自行管理，因此这里保留 HTTP 语义，去掉 WebView 同步。
 */
object CookieManager {

    /**
     * 标记 header：请求里带它表示「本次请求要走 cookie jar」。
     *
     * 与 Archive 一致，这是一个**header 名**（值为 `"1"`），由 `HttpHelper` 的
     * networkInterceptor 消费后移除。早期实现错误地把它写成了「cookie 值」，
     * 在没有 cookie 时返回空字符串，导致 OkHttp 抛出 `IllegalArgumentException: name is empty`。
     */
    const val cookieJarHeader = "CookieJar"

    private val sessionCookies = LinkedHashMap<String, MutableMap<String, String>>()

    fun saveResponse(response: Response) {
        val url = response.request.url
        saveCookiesFromHeaders(url.toString(), response.headers)
    }

    fun saveCookiesFromHeaders(url: String, headers: Headers) {
        val domain = NetworkUtils.getSubDomain(url)
        val jar = sessionCookies.getOrPut(domain) { mutableMapOf() }
        headers.values("Set-Cookie").forEach { header ->
            parseSetCookie(header).forEach { (k, v) -> jar[k] = v }
        }
    }

    /** 兼容 Jsoup 的 `Connection.Response`（WebView/抓包路径会用到）。 */
    fun saveResponse(response: org.jsoup.Connection.Response) {
        val headers = response.headers()
        val domain = NetworkUtils.getSubDomain(response.url().toString())
        val jar = sessionCookies.getOrPut(domain) { mutableMapOf() }
        headers.filterKeys { it.equals("Set-Cookie", true) }
            .values
            .forEach { header ->
                parseSetCookie(header).forEach { (k, v) -> jar[k] = v }
            }
    }

    fun loadRequest(request: Request): Request {
        val domain = NetworkUtils.getSubDomain(request.url.toString())
        val jar = sessionCookies[domain]
        if (jar.isNullOrEmpty()) return request
        val cookie = jar.entries.joinToString("; ") { "${it.key}=${it.value}" }
        return request.newBuilder().header("Cookie", cookie).build()
    }

    fun getSessionCookie(domain: String): String? {
        val jar = sessionCookies[domain] ?: return null
        if (jar.isEmpty()) return null
        return jar.entries.joinToString("; ") { "${it.key}=${it.value}" }
    }

    fun mergeCookies(vararg cookies: String?): String? {
        val map = mergeCookiesToMap(*cookies)
        if (map.isEmpty()) return null
        return map.entries.joinToString("; ") { "${it.key}=${it.value}" }
    }

    fun mergeCookiesToMap(vararg cookies: String?): MutableMap<String, String> {
        val map = mutableMapOf<String, String>()
        cookies.forEach { cookie ->
            if (cookie.isNullOrBlank()) return@forEach
            cookie.split(";").forEach { pair ->
                val cut = pair.indexOf('=')
                if (cut > 0 && cut < pair.length - 1) {
                    map[pair.substring(0, cut).trim()] = pair.substring(cut + 1).trim()
                }
            }
        }
        return map
    }

    fun removeCookie(url: String, key: String) {
        val domain = NetworkUtils.getSubDomain(url)
        val jar = sessionCookies[domain] ?: return
        if (key.isEmpty()) jar.clear() else jar.remove(key)
    }

    fun getCookieNoSession(url: String): String = CookieStore.getCookieNoSession(url)

    fun applyToWebView(url: String) {
        // Flutter 侧由 InAppWebView 的 CookieManager 负责，引擎内不做处理。
    }

    fun clearSession() {
        sessionCookies.clear()
    }

    private fun parseSetCookie(header: String): List<Pair<String, String>> {
        val first = header.substringBefore(';').trim()
        val cut = first.indexOf('=')
        if (cut <= 0) return emptyList()
        val key = first.substring(0, cut).trim()
        val value = first.substring(cut + 1).trim()
        if (value.equals("deleted", true)) return listOf(key to "")
        return listOf(key to value)
    }

    @Suppress("unused")
    private const val CONNECTION_TIMEOUT = HttpURLConnection.HTTP_OK
}

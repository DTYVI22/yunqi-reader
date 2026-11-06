package io.legado.app.help.http

import android.content.Context
import io.legado.app.help.http.api.CookieManagerInterface
import io.legado.app.utils.NetworkUtils
import io.legado.app.utils.splitNotBlank
import splitties.init.appCtx

/**
 * Cookie 存储，按「站点主域」持久化。
 *
 * Archive 原实现落在 Room `Cookie` 表。引擎不引数据库，改为 SharedPreferences，
 * 键仍是 `NetworkUtils.getSubDomain(url)`，因此同一域名下不同路径共享 cookie 的
 * 行为与原来一致。会话级 cookie 由 [CookieManager] 的内存表承载。
 */
object CookieStore : CookieManagerInterface {

    private const val EQUALS = "="

    private val prefs by lazy {
        appCtx.getSharedPreferences("legado_cookie", Context.MODE_PRIVATE)
    }

    override fun setCookie(url: String, cookie: String?) {
        val domain = NetworkUtils.getSubDomain(url)
        if (cookie.isNullOrBlank()) {
            prefs.edit().remove(domain).apply()
        } else {
            prefs.edit().putString(domain, cookie).apply()
        }
    }

    override fun replaceCookie(url: String, cookie: String) {
        setCookie(url, cookie)
    }

    override fun getCookie(url: String): String {
        val domain = NetworkUtils.getSubDomain(url)
        val base = getCookieNoSession(url)
        val session = CookieManager.getSessionCookie(domain)
        return CookieManager.mergeCookies(base, session) ?: ""
    }

    fun getKey(url: String, key: String): String {
        return cookieToMap(getCookie(url))[key] ?: ""
    }

    override fun removeCookie(url: String) {
        val domain = NetworkUtils.getSubDomain(url)
        prefs.edit().remove(domain).apply()
        CookieManager.removeCookie(url, "")
    }

    fun getCookieNoSession(url: String): String {
        val domain = NetworkUtils.getSubDomain(url)
        return prefs.getString(domain, "") ?: ""
    }

    override fun cookieToMap(cookie: String): MutableMap<String, String> {
        val map = mutableMapOf<String, String>()
        cookie.splitNotBlank(";").forEach { pair ->
            val cut = pair.indexOf(EQUALS)
            if (cut > 0 && cut < pair.length - 1) {
                map[pair.substring(0, cut).trim()] = pair.substring(cut + 1).trim()
            }
        }
        return map
    }

    override fun mapToCookie(cookieMap: Map<String, String>?): String? {
        if (cookieMap.isNullOrEmpty()) return null
        return cookieMap.entries.joinToString("; ") { "${it.key}=${it.value}" }
    }

    fun clear() {
        prefs.edit().clear().apply()
        CookieManager.clearSession()
    }
}

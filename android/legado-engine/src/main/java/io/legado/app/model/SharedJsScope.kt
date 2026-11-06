package io.legado.app.model

import io.legado.app.help.http.dns.DnsScope
import org.mozilla.javascript.Scriptable
import kotlin.coroutines.CoroutineContext

/**
 * `jsLib` 共享作用域。
 *
 * Archive 会把书源的 `jsLib` 编译成一个 Rhino 作用域并缓存，供同一书源的所有
 * 规则共享（书源作者常用它放公共函数）。第一版引擎先不缓存，返回 null 表示
 * 「没有共享作用域」，各规则仍在自己的 bindings 里执行——语义上等价于未配置
 * jsLib 的源，不会影响其它规则。后续接 jsLib 时在这里实现编译与缓存即可。
 */
object SharedJsScope {

    private val scopes = HashMap<String, Scriptable>()

    fun getScope(
        jsLib: String?,
        coroutineContext: CoroutineContext? = null,
        dnsScope: DnsScope = DnsScope.READING
    ): Scriptable? {
        if (jsLib.isNullOrBlank()) return null
        return scopes[jsLib]
    }

    fun putScope(jsLib: String, scope: Scriptable) {
        scopes[jsLib] = scope
    }

    fun remove(jsLib: String?) {
        if (jsLib == null) return
        scopes.remove(jsLib)
    }

    fun clear() = scopes.clear()
}

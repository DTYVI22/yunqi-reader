package io.legado.app.help.http.dns

import java.net.IDN

/**
 * 域名规范化：规则里比较 host 时忽略大小写、IDN 与末尾点。
 *
 * Archive 的实现在 `NetworkDnsConfig.kt` 里，同时带 DoH 配置解析；引擎只保留
 * 域名比较需要的那三个函数。
 */
object DnsNames {

    fun host(raw: String?): String? {
        val value = raw?.trim()?.trimEnd('.')?.lowercase() ?: return null
        if (value.isEmpty()) return null
        return runCatching { IDN.toASCII(value) }.getOrNull()
    }

    fun literal(host: String?): String? {
        val value = host ?: return null
        return if (value.matches(Regex("^\\d{1,3}(\\.\\d{1,3}){3}$"))) value else null
    }

    fun matches(pattern: String, host: String): Boolean {
        val p = host(pattern) ?: return false
        val h = host(host) ?: return false
        return if (p.startsWith("*.")) {
            h.endsWith(p.substring(1)) && h != p.substring(2)
        } else {
            h == p
        }
    }
}

package io.legado.app.help.http.dns

import okhttp3.Dns
import java.net.InetAddress

/**
 * DNS 固定：书源里可以写 `,{"dnsIp":"1.2.3.4,5.6.7.8"}` 强制指定解析结果
 * （常用于被墙或 DNS 污染的站点）。Archive 的原实现在 NetworkDnsConfig 里，
 * 这里只保留「指定 host 走指定 IP」这一层语义。
 */
class HostOverrideDns(
    private val targetHost: String,
    private val ips: List<String>,
    private val delegate: Dns?
) : Dns {

    override fun lookup(hostname: String): List<InetAddress> {
        if (hostname.equals(targetHost, ignoreCase = true) && ips.isNotEmpty()) {
            return ips.map { InetAddress.getByName(it) }
        }
        return delegate?.lookup(hostname) ?: Dns.SYSTEM.lookup(hostname)
    }
}

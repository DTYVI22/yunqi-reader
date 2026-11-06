package io.legado.app.help.http.dns

import okhttp3.OkHttpClient

/**
 * 网络栈开关占位。
 *
 * Archive 里 DoH 与 Cronet 都是可选项，通过 builder 扩展切换。引擎不内置这两条
 * 通道（交给系统的 DNS / Flutter 侧代理），这里保留同名扩展，保证书源代理与
 * DNS 覆盖的调用链不改动。
 */
fun OkHttpClient.Builder.withDnsScope(scope: DnsScope): OkHttpClient.Builder = this

fun OkHttpClient.Builder.withoutCronet(): OkHttpClient.Builder = this

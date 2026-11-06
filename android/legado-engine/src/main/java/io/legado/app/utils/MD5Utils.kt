package io.legado.app.utils

import java.io.InputStream
import java.security.MessageDigest
import kotlin.concurrent.getOrSet

/**
 * MD5 工具。
 *
 * 原实现走 hutool 的 `DigestUtil.digester("MD5")`。hutool 在检测到 classpath 里有
 * BouncyCastle 时，会用 BC provider 构造 `MessageDigest`；而 release 包经 R8 裁剪后
 * BC 的 MD5 实现不完整，运行时报
 * `NoSuchAlgorithmException: no such algorithm: MD5 for provider BC`——
 * 书源分类的缓存键正好用它，于是**所有源一次都解析不出来**（debug 包不受影响）。
 *
 * 这里改用 JDK 自带的 `MessageDigest.getInstance("MD5")`（Android 平台一定有），
 * 不再依赖任何第三方 provider，release / debug 行为一致。
 */
object MD5Utils {

    private val digestHolder = ThreadLocal<MessageDigest>()

    private val digester: MessageDigest
        get() = digestHolder.getOrSet { MessageDigest.getInstance("MD5") }

    fun md5Encode(str: String?): String {
        val digest = digester
        digest.reset()
        return hex(digest.digest((str ?: "").toByteArray(Charsets.UTF_8)))
    }

    fun md5Encode(inputStream: InputStream): String {
        val digest = digester
        digest.reset()
        val buffer = ByteArray(8 * 1024)
        while (true) {
            val read = inputStream.read(buffer)
            if (read <= 0) break
            digest.update(buffer, 0, read)
        }
        return hex(digest.digest())
    }

    fun md5Encode16(str: String): String {
        val full = md5Encode(str)
        return if (full.length >= 24) full.substring(8, 24) else full
    }

    private fun hex(bytes: ByteArray): String {
        val chars = CharArray(bytes.size * 2)
        val digits = "0123456789abcdef"
        bytes.forEachIndexed { index, byte ->
            val value = byte.toInt() and 0xFF
            chars[index * 2] = digits[value ushr 4]
            chars[index * 2 + 1] = digits[value and 0x0F]
        }
        return String(chars)
    }
}

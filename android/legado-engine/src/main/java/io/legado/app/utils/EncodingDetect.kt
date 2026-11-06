package io.legado.app.utils

import java.io.File

/**
 * 编码识别。
 *
 * Archive 用 ICU 的 `CharsetDetector` 做统计识别。引擎侧沿用 Flutter 前端已有的
 * 策略：BOM → `<meta charset>` → UTF-8 试解 → 回退 GBK。识别失败时返回 UTF-8，
 * 由调用方按替换字符比例决定是否重解。
 */
object EncodingDetect {

    private val metaRegex = Regex(
        """charset\s*=\s*["']?\s*([A-Za-z0-9_\-]+)""",
        RegexOption.IGNORE_CASE
    )

    fun getHtmlEncode(bytes: ByteArray): String {
        bomCharset(bytes)?.let { return it }
        val head = String(bytes, 0, minOf(bytes.size, 2048), Charsets.ISO_8859_1)
        metaRegex.find(head)?.groupValues?.get(1)?.let { return normalize(it) }
        return if (looksLikeUtf8(bytes)) "UTF-8" else "GBK"
    }

    fun getEncode(file: File): String =
        runCatching { getHtmlEncode(file.readBytes()) }.getOrDefault("UTF-8")

    fun getEncode(bytes: ByteArray): String = getHtmlEncode(bytes)

    private fun bomCharset(bytes: ByteArray): String? = when {
        bytes.size >= 3 && bytes[0] == 0xEF.toByte() && bytes[1] == 0xBB.toByte() &&
            bytes[2] == 0xBF.toByte() -> "UTF-8"

        bytes.size >= 2 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xFE.toByte() -> "UTF-16LE"
        bytes.size >= 2 && bytes[0] == 0xFE.toByte() && bytes[1] == 0xFF.toByte() -> "UTF-16BE"
        else -> null
    }

    private fun normalize(raw: String): String = when (raw.lowercase()) {
        "gb2312", "gbk", "gb18030", "gb" -> "GBK"
        "utf8", "utf-8" -> "UTF-8"
        else -> raw.uppercase()
    }

    private fun looksLikeUtf8(bytes: ByteArray): Boolean {
        var i = 0
        while (i < bytes.size) {
            val b = bytes[i].toInt() and 0xFF
            val extra = when {
                b < 0x80 -> 0
                b in 0xC2..0xDF -> 1
                b in 0xE0..0xEF -> 2
                b in 0xF0..0xF4 -> 3
                else -> return false
            }
            if (i + extra >= bytes.size) return true
            repeat(extra) { k ->
                val next = bytes[i + 1 + k].toInt() and 0xFF
                if (next !in 0x80..0xBF) return false
            }
            i += extra + 1
        }
        return true
    }
}

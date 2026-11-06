package io.legado.app.utils

/**
 * 简繁转换。
 *
 * Archive 依赖 opencc 词典（`com.github.houbb` / 字库资源）做真正的转换。引擎不
 * 打包词典，这里保留 API 但原样返回：书源里 `java.t2s()` 主要用于书名对比，
 * 不转换的后果是「繁体书名匹配不到简体关键词」，不会导致规则报错。
 * 需要真转换时再接入 opencc 数据资产。
 */
object ChineseUtils {

    var chineseConverterType: Int = 0

    fun t2s(text: String): String = text

    fun s2t(text: String): String = text

    fun preLoad() {}

    fun unLoad() {}

    fun loadExcludeDict() {}
}

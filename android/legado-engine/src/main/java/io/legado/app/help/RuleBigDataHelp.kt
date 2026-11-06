package io.legado.app.help

import io.legado.app.utils.MD5Utils

/**
 * 大文本变量（正文级缓存）。
 *
 * Archive 原实现把它落到外部存储的 `ruleData/` 目录并用 `appDb` 做过期清理。
 * 引擎不带数据库也不主动清理存储，这里改为写入 [CacheManager]（内存 + SP），
 * 键规则保持一致：`book/<md5(bookUrl)>/<md5(key)>`。
 */
object RuleBigDataHelp {

    private const val BOOK = "ruleData/book/"
    private const val CHAPTER = "ruleData/chapter/"
    private const val RSS = "ruleData/rss/"

    private fun bookKey(bookUrl: String, key: String?): String =
        BOOK + MD5Utils.md5Encode(bookUrl) + "/" + MD5Utils.md5Encode(key ?: "")

    private fun chapterKey(bookUrl: String, chapterUrl: String, key: String?): String =
        CHAPTER + MD5Utils.md5Encode(bookUrl) + "/" +
            MD5Utils.md5Encode(chapterUrl) + "/" + MD5Utils.md5Encode(key ?: "")

    private fun rssKey(origin: String, link: String, key: String?): String =
        RSS + MD5Utils.md5Encode(origin) + "/" + MD5Utils.md5Encode(link) + "/" +
            MD5Utils.md5Encode(key ?: "")

    fun putBookVariable(bookUrl: String, key: String, value: String?) {
        val k = bookKey(bookUrl, key)
        if (value == null) CacheManager.delete(k) else CacheManager.put(k, value)
    }

    fun getBookVariable(bookUrl: String, key: String?): String? =
        CacheManager.get(bookKey(bookUrl, key))

    fun hasBookVariable(bookUrl: String, key: String): Boolean =
        CacheManager.get(bookKey(bookUrl, key)) != null

    fun putChapterVariable(bookUrl: String, chapterUrl: String, key: String, value: String?) {
        val k = chapterKey(bookUrl, chapterUrl, key)
        if (value == null) CacheManager.delete(k) else CacheManager.put(k, value)
    }

    fun getChapterVariable(bookUrl: String, chapterUrl: String, key: String): String? =
        CacheManager.get(chapterKey(bookUrl, chapterUrl, key))

    fun putRssVariable(origin: String, link: String, key: String, value: String?) {
        val k = rssKey(origin, link, key)
        if (value == null) CacheManager.delete(k) else CacheManager.put(k, value)
    }

    fun getRssVariable(origin: String, link: String, key: String): String? =
        CacheManager.get(rssKey(origin, link, key))
}

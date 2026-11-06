package io.legado.app.help

import io.legado.app.model.analyzeRule.QueryTTF

/**
 * 字体子集缓存（`java.queryTTF` / `java.replaceFont` 用）。
 *
 * Archive 原实现与 [CacheManager] 同文件，落 Room 的 `Cache` 表。这里只保留内存
 * LRU：自定义字体的子集结果是一次性的，进程重启重算即可。
 */
object AppCacheManager {

    private val ttfCache = object : LinkedHashMap<String, QueryTTF>(8, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, QueryTTF>?): Boolean =
            size > 4
    }

    fun getQueryTTF(key: String): QueryTTF? = ttfCache[key]

    fun put(key: String, queryTTF: QueryTTF) {
        ttfCache[key] = queryTTF
    }

    fun clear() = ttfCache.clear()
}

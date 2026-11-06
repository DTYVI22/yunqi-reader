package io.legado.app.help

import android.webkit.JavascriptInterface
import splitties.init.appCtx

/**
 * 键值缓存，供 `java.put/get`、`cache.*`、书源变量与登录信息使用。
 *
 * Archive 原实现是「内存 LruCache + Room `Cache` 表 + ACache 文件」三层。引擎
 * 不引数据库，这里收敛为「内存 LruCache + SharedPreferences」：语义一致（同 key
 * 同值、delete 后取到 null），只是不再做过期清理与文件落盘。`saveTime` 参数保留
 * 以对齐调用签名，暂不生效。
 */
object CacheManager {

    private const val PREFIX = "legado.cache."

    private val memory = object : LinkedHashMap<String, Any>(256, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Any>?): Boolean =
            size > 512
    }

    private val prefs by lazy {
        appCtx.getSharedPreferences("legado_cache", android.content.Context.MODE_PRIVATE)
    }

    @Synchronized
    fun put(key: String, value: Any, saveTime: Int = 0) {
        when (value) {
            is String -> {
                memory[key] = value
                prefs.edit().putString(PREFIX + key, value).apply()
            }

            is ByteArray -> memory[key] = value
            else -> memory[key] = value.toString()
        }
    }

    @Synchronized
    fun putMemory(key: String, value: Any) {
        memory[key] = value
    }

    fun getFromMemory(key: String): Any? = memory[key]

    @Synchronized
    fun deleteMemory(key: String) {
        memory.remove(key)
    }

    @Synchronized
    fun get(key: String): String? {
        (memory[key] as? String)?.let { return it }
        val cached = prefs.getString(PREFIX + key, null)
        if (cached != null) memory[key] = cached
        return cached
    }

    fun get(key: String, onlyDisk: Boolean): String? = if (onlyDisk) {
        prefs.getString(PREFIX + key, null)
    } else {
        get(key)
    }

    fun getInt(key: String): Int? = get(key)?.toIntOrNull()

    fun getLong(key: String): Long? = get(key)?.toLongOrNull()

    fun getDouble(key: String): Double? = get(key)?.toDoubleOrNull()

    fun getFloat(key: String): Float? = get(key)?.toFloatOrNull()

    fun getByteArray(key: String): ByteArray? = memory[key] as? ByteArray

    fun putFile(key: String, value: String, saveTime: Int = 0) = put(key, value, saveTime)

    fun getFile(key: String): String? = get(key)

    @Synchronized
    fun delete(key: String) {
        memory.remove(key)
        prefs.edit().remove(PREFIX + key).apply()
    }

    @Synchronized
    fun clearSourceVariables() {
        memory.keys.filter { it.startsWith("sourceVariable_") }.forEach { memory.remove(it) }
        prefs.edit().apply {
            prefs.all.keys
                .filter { it.startsWith(PREFIX + "sourceVariable_") }
                .forEach { remove(it) }
        }.apply()
    }

    // JS 侧 java.* 反射调用要求区分重载，@JavascriptInterface 只是标记，保留签名即可。
    @JavascriptInterface
    fun putJs(key: String, value: String, saveTime: Int = 0) = put(key, value, saveTime)

    @JavascriptInterface
    fun getJs(key: String): String? = get(key)

    @JavascriptInterface
    fun deleteJs(key: String) = delete(key)
}

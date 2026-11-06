package io.legado.app.help.source

import com.script.rhino.runScriptWithContext
import io.legado.app.data.entities.BaseSource
import io.legado.app.data.entities.BookSource
import io.legado.app.data.entities.rule.ExploreKind
import io.legado.app.help.CacheManager
import io.legado.app.help.http.dns.DnsScope
import io.legado.app.model.SharedJsScope
import io.legado.app.utils.GSON
import io.legado.app.utils.InfoMap
import io.legado.app.utils.MD5Utils
import io.legado.app.utils.fromJsonArray
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.mozilla.javascript.Scriptable
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.CoroutineContext

/**
 * 书源扩展：共享 JS 作用域 + 发现分类解析。
 *
 * Archive 原文件除了这两个还带 `clearExploreKindsCache`（UI 用）与 `getBookType`，
 * 引擎只保留求值侧需要的部分。`exploreKinds()` 的三种形态与解析规则与上游一致：
 *
 * - `@js:` / `<js>`：执行脚本产出分类文本（脚本里可以用 `infoMap` 做交互状态）；
 * - JSON 数组：`[{"title":"玄幻","url":"/xuanhuan","style":{"layout_flexGrow":1}}]`；
 * - 文本行：`名称::地址`，用换行或 `&&` 分隔；`url` 为空表示分组标题。
 */
fun BaseSource.getShareScope(
    coroutineContext: CoroutineContext? = null,
    dnsScope: DnsScope = getNetworkDnsScope()
): Scriptable? {
    return SharedJsScope.getScope(jsLib, coroutineContext, dnsScope)
}

private val exploreKindsMap = ConcurrentHashMap<String, List<ExploreKind>>()
private val exploreInfoMap = ConcurrentHashMap<String, InfoMap>()
private val mutexMap = HashMap<String, Mutex>()

private fun BookSource.exploreKindsKey(): String = MD5Utils.md5Encode(
    listOf(
        bookSourceUrl,
        exploreUrl.orEmpty(),
        jsLib.orEmpty(),
        lastUpdateTime.toString()
    ).joinToString("\n")
)

/**
 * 解析 `exploreUrl` 为分类列表。结果按「书源 + exploreUrl + jsLib + 更新时间」缓存，
 * 脚本产出的文本额外落 [CacheManager]，避免每次进发现页都跑一遍 Rhino。
 */
suspend fun BookSource.exploreKinds(): List<ExploreKind> {
    val exploreUrl = exploreUrl
    if (exploreUrl.isNullOrBlank()) return emptyList()

    val key = exploreKindsKey()
    exploreKindsMap[key]?.let { return it }

    val mutex = mutexMap[bookSourceUrl] ?: Mutex().apply { mutexMap[bookSourceUrl] = this }
    return mutex.withLock {
        exploreKindsMap[key]?.let { return@withLock it }
        val kinds = arrayListOf<ExploreKind>()
        withContext(Dispatchers.IO) {
            runCatching {
                val ruleStr = when {
                    exploreUrl.startsWith("@js:", true) ->
                        CacheManager.get(SCRIPT_CACHE_PREFIX + key)
                            ?: evalExploreScript(exploreUrl.substring(4))
                                .also { cacheScriptResult(key, it) }

                    exploreUrl.startsWith("<js>", true) ->
                        CacheManager.get(SCRIPT_CACHE_PREFIX + key)
                            ?: evalExploreScript(
                                exploreUrl.substring(4, exploreUrl.lastIndexOf("<"))
                            ).also { cacheScriptResult(key, it) }

                    else -> exploreUrl
                }
                if (!ruleStr.isValidExploreKindsRule()) return@runCatching
                if (ruleStr.trimStart().startsWith("[")) {
                    kinds.addAll(GSON.fromJsonArray<ExploreKind>(ruleStr).getOrThrow())
                } else {
                    ruleStr.split(Regex("(&&|\\n)+")).forEach { line ->
                        val text = line.trim()
                        if (text.isEmpty()) return@forEach
                        val parts = text.split("::", limit = 2)
                        kinds.add(ExploreKind(parts[0].trim(), parts.getOrNull(1)?.trim()))
                    }
                }
            }.onFailure {
                // 解析失败不抛给调用方：返回 ERROR 项，UI 显示「该源分类不可用」
                kinds.add(ExploreKind("ERROR:${it.javaClass.simpleName}", null))
            }
        }
        exploreKindsMap[key] = kinds
        kinds
    }
}

/** 交互式分类（`infoMap`）在引擎内是进程级状态，与 Archive 的 ExploreAdapter 等价。 */
fun BookSource.exploreInfoMap(): InfoMap =
    exploreInfoMap.getOrPut(bookSourceUrl) { InfoMap(bookSourceUrl) }

private suspend fun BookSource.evalExploreScript(js: String): String {
    val infoMap = exploreInfoMap()
    return runScriptWithContext {
        evalJS(js) {
            put("infoMap", infoMap)
        }?.toString()?.trim().orEmpty()
    }
}

private fun cacheScriptResult(key: String, rule: String) {
    if (rule.isValidExploreKindsRule()) {
        CacheManager.put(SCRIPT_CACHE_PREFIX + key, rule)
    }
}

private fun String.isValidExploreKindsRule(): Boolean {
    val rule = trim()
    if (rule.isEmpty()) return false
    if (rule.equals("null", true) || rule.equals("undefined", true)) return false
    return true
}

/** 清缓存：书源变量或 URL 变化后由 [exploreKindsKey] 自然失效，这里供手动刷新用。 */
fun BookSource.clearExploreKindsCache() {
    val key = exploreKindsKey()
    exploreKindsMap.remove(key)
    CacheManager.delete(SCRIPT_CACHE_PREFIX + key)
}

private const val SCRIPT_CACHE_PREFIX = "exploreKinds:"

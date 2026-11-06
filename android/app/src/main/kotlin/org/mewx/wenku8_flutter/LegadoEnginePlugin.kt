package org.mewx.wenku8_flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import app.yunqi.engine.EngineFacade
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

/**
 * 书源引擎的 Flutter 桥。
 *
 * 引擎本体在 `:legado-engine`（Archive 规则求值 + Rhino），这里只做三件事：
 * 1. 把 Application Context 注入引擎；
 * 2. 用 MethodChannel 暴露 search / bookInfo / toc / content，出入参都是 JSON 字符串；
 * 3. debug 包启动时跑一次自检（`assets/legado_smoke_sources.json`），结果打
 *    logcat，方便在没有 UI 的情况下确认真机能不能跑书源。
 *
 * 线程约定：所有引擎调用在 IO 线程执行，`result` 回主线程投递——`AnalyzeUrl`
 * 内部会 `runBlocking` 等网络，绝不能让它占用主线程。
 */
class LegadoEnginePlugin : FlutterPlugin {

    private var channel: MethodChannel? = null
    private var scope: CoroutineScope? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        Log.i(TAG, "onAttachedToEngine")
        engineContext = context
        EngineFacade.install(context)
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        channel = MethodChannel(
            binding.binaryMessenger,
            CHANNEL
        ).also { ch ->
            ch.setMethodCallHandler { call, result -> dispatch(call, result) }
        }
        val debuggable = (context.applicationInfo.flags and
            android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (debuggable) {
            // 自检不能挂在 plugin 的 scope 上：Engine 可能被 Activity 重建后 detach，
            // 那样会 cancel 掉协程，日志就永远等不到。用独立线程跑完为止。
            Thread {
                val report = runCatching {
                    kotlinx.coroutines.runBlocking { runSelfTestBlocking() }
                }.getOrElse {
                    "selfTest error: ${it.javaClass.simpleName}: ${it.message}"
                }
                Log.i(TAG, "自检结果：\n$report")
            }.apply { isDaemon = true }.start()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        scope?.cancel()
        scope = null
    }

    private fun dispatch(call: MethodCall, result: MethodChannel.Result) {
        val engineScope = scope ?: run {
            result.error("ENGINE_DETACHED", "引擎未挂载", null)
            return
        }
        when (call.method) {
            "ready" -> result.success(EngineFacade.isReady)

            "search" -> {
                val source = call.argument<String>("source") ?: return missing(result, "source")
                val key = call.argument<String>("key") ?: return missing(result, "key")
                val page = call.argument<Int>("page") ?: 1
                engineScope.launch {
                    settle(result) { EngineFacade.search(source, key, page) }
                }
            }

            "bookInfo" -> {
                val source = call.argument<String>("source") ?: return missing(result, "source")
                val bookUrl = call.argument<String>("bookUrl") ?: return missing(result, "bookUrl")
                engineScope.launch { settle(result) { EngineFacade.bookInfo(source, bookUrl) } }
            }

            "toc" -> {
                val source = call.argument<String>("source") ?: return missing(result, "source")
                val tocUrl = call.argument<String>("tocUrl") ?: return missing(result, "tocUrl")
                engineScope.launch { settle(result) { EngineFacade.toc(source, tocUrl) } }
            }

            "content" -> {
                val source = call.argument<String>("source") ?: return missing(result, "source")
                val chapterUrl =
                    call.argument<String>("chapterUrl") ?: return missing(result, "chapterUrl")
                engineScope.launch { settle(result) { EngineFacade.content(source, chapterUrl) } }
            }

            "exploreKinds" -> {
                val source = call.argument<String>("source") ?: return missing(result, "source")
                engineScope.launch { settle(result) { EngineFacade.exploreKinds(source) } }
            }

            "explore" -> {
                val source = call.argument<String>("source") ?: return missing(result, "source")
                val url = call.argument<String>("url") ?: return missing(result, "url")
                val page = call.argument<Int>("page") ?: 1
                engineScope.launch { settle(result) { EngineFacade.explore(source, url, page) } }
            }

            "selfTest" -> engineScope.launch {
                settle(result) { runSelfTestBlocking() }
            }

            else -> result.notImplemented()
        }
    }

    private suspend fun settle(result: MethodChannel.Result, block: suspend () -> Any?) {
        runCatching { block() }
            .onSuccess { value -> mainHandler.post { result.success(value) } }
            .onFailure { error ->
                Log.w(TAG, "引擎调用失败", error)
                mainHandler.post {
                    result.error(
                        "ENGINE_ERROR",
                        "${error.javaClass.simpleName}: ${error.message}",
                        null
                    )
                }
            }
    }

    private fun missing(result: MethodChannel.Result, name: String) {
        result.error("MISSING_ARG", "缺少参数 $name", null)
    }

    /**
     * 真机自检：
     * 1. 两个搜索型源各跑一次真实搜索；
     * 2. 三个 `exploreUrl` 源解析分类（文本 / JSON / `@js` 三种形态各一）；
     * 3. 用第一个可点分类拉一页，验证发现链路；
     * 4. `@js` 求值；
     * 5. 搜索源跑 详情 → 目录 → 正文。
     */
    private suspend fun runSelfTestBlocking(): String {
        val context = engineContext ?: error("context 未注入")
        val json = context.assets.open("legado_smoke_sources.json")
            .bufferedReader().use { it.readText() }
        val sources = JSONArray(json)
        val keyword = "我有一座恐怖屋"
        val report = StringBuilder()

        // 1) 搜索（跳过带 exploreUrl 的源，避免重复耗时）
        for (i in 0 until sources.length()) {
            val item = sources.getJSONObject(i)
            if (item.optString("exploreUrl").isNotBlank()) continue
            val name = item.optString("bookSourceName")
            Log.i(TAG, "自检: 搜索 $name")
            val outcome = runCatching {
                kotlinx.coroutines.withTimeout(20_000) {
                    EngineFacade.search(item.toString(), keyword, 1)
                }
            }
            if (outcome.isSuccess) {
                val hits = JSONArray(outcome.getOrThrow())
                val first = if (hits.length() > 0) hits.getJSONObject(0).optString("name") else "-"
                report.append("\n  [搜索] $name = ${hits.length()} 条 · 首条=$first")
            } else {
                val e = outcome.exceptionOrNull()
                report.append("\n  [搜索] $name 失败 ${e?.javaClass?.simpleName}: ${e?.message}")
            }
        }

        // 2) 发现分类
        for (i in 0 until sources.length()) {
            val item = sources.getJSONObject(i)
            if (item.optString("exploreUrl").isBlank()) continue
            val name = item.optString("bookSourceName")
            Log.i(TAG, "自检: 分类 $name")
            val outcome = runCatching {
                kotlinx.coroutines.withTimeout(20_000) {
                    JSONArray(EngineFacade.exploreKinds(item.toString()))
                }
            }
            val kinds = outcome.getOrNull()
            if (kinds == null) {
                val e = outcome.exceptionOrNull()
                report.append("\n  [分类] $name 失败 ${e?.javaClass?.simpleName}: ${e?.message}")
                continue
            }
            val usable = (0 until kinds.length())
                .map { kinds.getJSONObject(it) }
                .filter { it.optString("url").isNotBlank() }
            val sample = usable.firstOrNull()?.optString("title").orEmpty()
            report.append("\n  [分类] $name = ${kinds.length()} 项（可点 ${usable.size}）")
            if (sample.isNotEmpty()) report.append(" · 例:$sample")
        }

        // 3) 每个源都用它的第一个可点分类拉一页（一个失败不影响其它源）
        for (i in 0 until sources.length()) {
            val item = sources.getJSONObject(i)
            if (item.optString("exploreUrl").isBlank()) continue
            val name = item.optString("bookSourceName")
            val kinds = runCatching {
                kotlinx.coroutines.withTimeout(20_000) {
                    JSONArray(EngineFacade.exploreKinds(item.toString()))
                }
            }.getOrNull() ?: continue
            val usable = (0 until kinds.length())
                .map { kinds.getJSONObject(it) }
                .firstOrNull { it.optString("url").isNotBlank() } ?: continue
            val title = usable.optString("title")
            val url = usable.optString("url")
            val page = runCatching {
                kotlinx.coroutines.withTimeout(20_000) {
                    JSONArray(EngineFacade.explore(item.toString(), url, 1))
                }
            }
            val hits = page.getOrNull()
            if (hits != null) {
                val first = if (hits.length() > 0) hits.getJSONObject(0).optString("name") else "-"
                report.append("\n  [发现] $name / $title = ${hits.length()} 条 · 首条=$first")
            } else {
                val e = page.exceptionOrNull()
                Log.w(TAG, "发现失败 $name / $title", e)
                report.append("\n  [发现] $name / $title 失败 ${e?.javaClass?.simpleName}: ${e?.message}")
            }
        }

        // 4) @js：Rhino + java.* 绑定是否可用（离线）
        val jsResult = runCatching {
            io.legado.app.model.analyzeRule.AnalyzeRule(null)
                .setContent("<div id='c'>abc</div>", "http://example.com/")
                .getString("@js:'len='+baseUrl.length")
        }
        report.append(
            "\n  [@js] " + jsResult.getOrElse {
                "失败 ${it.javaClass.simpleName}: ${it.message}"
            }
        )

        // 5) 完整链路：拿第一个搜索源的首条结果跑 详情 → 目录 → 首章正文
        chain@ for (i in 0 until sources.length()) {
            val item = sources.getJSONObject(i)
            if (item.optString("exploreUrl").isNotBlank()) continue
            val sourceJson = item.toString()
            val hits = runCatching {
                kotlinx.coroutines.withTimeout(20_000) {
                    JSONArray(EngineFacade.search(sourceJson, keyword, 1))
                }
            }.getOrNull() ?: continue
            if (hits.length() == 0) continue
            val bookUrl = hits.getJSONObject(0).optString("bookUrl")
            if (bookUrl.isBlank()) continue
            val stepReport = StringBuilder("\n  [链路] ${item.optString("bookSourceName")}")
            val info = runCatching {
                kotlinx.coroutines.withTimeout(20_000) { EngineFacade.bookInfo(sourceJson, bookUrl) }
            }
            stepReport.append(" 详情=" + if (info.isSuccess) "ok" else "失败")
            val tocUrl = info.getOrNull()
                ?.let { JSONObject(it).optString("tocUrl") }
                ?.takeIf { it.isNotBlank() } ?: bookUrl
            val toc = runCatching {
                kotlinx.coroutines.withTimeout(20_000) { JSONArray(EngineFacade.toc(sourceJson, tocUrl)) }
            }
            stepReport.append(" 目录=" + (toc.getOrNull()?.length() ?: 0) + " 章")
            val chapterUrl = toc.getOrNull()
                ?.takeIf { it.length() > 0 }
                ?.getJSONObject(0)
                ?.optString("url")
                ?.takeIf { it.isNotBlank() }
            if (chapterUrl != null) {
                val body = runCatching {
                    kotlinx.coroutines.withTimeout(20_000) {
                        EngineFacade.content(sourceJson, chapterUrl)
                    }
                }
                stepReport.append(" 正文=" + (body.getOrNull()?.length ?: 0) + " 字")
            }
            report.append(stepReport)
            break@chain
        }
        return report.toString()
    }

    private var engineContext: Context? = null

    companion object {
        private const val TAG = "LegadoEngine"
        private const val CHANNEL = "app.yunqi.reader/legado_engine"
    }
}

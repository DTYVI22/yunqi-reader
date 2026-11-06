package app.yunqi.engine

import android.content.Context
import io.legado.app.EngineHost
import io.legado.app.data.entities.BookSource
import io.legado.app.data.entities.rule.BookListRule
import io.legado.app.help.source.exploreKinds
import io.legado.app.model.analyzeRule.AnalyzeRule
import io.legado.app.model.analyzeRule.AnalyzeUrl
import io.legado.app.utils.GSON
import kotlinx.coroutines.Dispatchers
import org.json.JSONArray
import org.json.JSONObject

/**
 * 书源引擎门面：Flutter ↔ Archive 规则引擎的唯一入口。
 *
 * 设计约束：
 * 1. 出入参全部用 JSON 字符串，避免 MethodChannel 的类型映射地狱；
 * 2. 每个方法都在 IO 线程上跑（`AnalyzeUrl` 内部会 `runBlocking` 等网络，
 *    绝不能在主线程调用）；
 * 3. 任何规则异常都收敛成「该项为空」，由 Flutter 侧决定提示，不让一个源拖垮
 *    整次搜索——与 Archive 的行为一致。
 */
object EngineFacade {

    fun install(context: Context) {
        EngineHost.install(context)
    }

    val isReady: Boolean get() = EngineHost.isInstalled

    /** 搜索：返回 `[{name,author,bookUrl,coverUrl,intro,kind,lastChapter,wordCount}]`。 */
    suspend fun search(sourceJson: String, key: String, page: Int = 1): String =
        withSource(sourceJson) { source ->
            val rule = load(
                source = source,
                spec = source.searchUrl ?: return@withSource "[]",
                key = key,
                page = page
            )
            collectBooks(rule, source.ruleSearch ?: return@withSource "[]")
        }

    /** 发现分类：解析 `exploreUrl`（文本行 / JSON 数组 / `@js` 三种形态）。 */
    suspend fun exploreKinds(sourceJson: String): String =
        withSource(sourceJson) { source ->
            val array = JSONArray()
            source.exploreKinds().forEach { kind ->
                array.put(
                    JSONObject().apply {
                        put("title", kind.title)
                        put("url", kind.url)
                        put("type", kind.type)
                        put("action", kind.action)
                        kind.style?.let { style ->
                            put(
                                "style",
                                JSONObject().apply {
                                    put("flexGrow", style.layout_flexGrow)
                                    put("flexBasisPercent", style.layout_flexBasisPercent)
                                    put("wrapBefore", style.layout_wrapBefore)
                                }
                            )
                        }
                    }
                )
            }
            array.toString()
        }

    /** 发现列表：按某个分类地址拉一页。`{{page}}` 由调用方或本方法按 [page] 替换。 */
    suspend fun explore(sourceJson: String, url: String, page: Int = 1): String =
        withSource(sourceJson) { source ->
            val raw = url.replace("{{page}}", page.toString())
            val absolute = absoluteUrl(source, raw)
            val analyzeUrl = AnalyzeUrl(absolute, source = source)
            val body = analyzeUrl.getStrResponseAwait().body ?: ""
            val rule = AnalyzeRule(null, source).setContent(body, analyzeUrl.url)
            // 书源可以只写 ruleSearch：发现页的分类地址与搜索页结构一致时，
            // Archive 也允许共用一套列表规则，这里做同样兜底。
            val spec = source.ruleExplore
                ?.takeIf { !it.bookList.isNullOrBlank() }
                ?: source.ruleSearch
                ?: return@withSource "[]"
            collectBooks(rule, spec)
        }

    /** 统一的列表字段映射：搜索与发现共用一套（Archive 的 `BookListRule`）。 */
    private fun collectBooks(rule: AnalyzeRule, spec: BookListRule): String {
        val listRule = spec.bookList ?: return "[]"
        val rows = rule.getElements(listRule)
        val array = JSONArray()
        rows.forEach { row ->
            val link = rule.getString(spec.bookUrl, row)
            if (link.isNullOrBlank()) return@forEach
            array.put(
                JSONObject().apply {
                    put("name", rule.getString(spec.name, row))
                    put("author", rule.getString(spec.author, row))
                    put("bookUrl", link)
                    put("coverUrl", rule.getString(spec.coverUrl, row))
                    put("intro", rule.getString(spec.intro, row))
                    put("kind", rule.getString(spec.kind, row))
                    put("lastChapter", rule.getString(spec.lastChapter, row))
                    put("wordCount", rule.getString(spec.wordCount, row))
                }
            )
        }
        return array.toString()
    }

    /** 详情：补齐书名、作者、简介、封面与目录地址。 */
    suspend fun bookInfo(sourceJson: String, bookUrl: String): String =
        withSource(sourceJson) { source ->
            val absolute = absoluteUrl(source, bookUrl)
            val rule = load(source, absolute, null, 1, direct = true)
            val info = source.ruleBookInfo
            JSONObject().apply {
                put("name", rule.getString(info?.name))
                put("author", rule.getString(info?.author))
                put("intro", rule.getString(info?.intro))
                put("kind", rule.getString(info?.kind))
                put("coverUrl", rule.getString(info?.coverUrl))
                put("lastChapter", rule.getString(info?.lastChapter))
                put("wordCount", rule.getString(info?.wordCount))
                put("tocUrl", rule.getString(info?.tocUrl))
            }.toString()
        }

    /** 目录：返回 `[{title,url}]`，已按 `chapterList` 的顺序（含 `-` 反序）。 */
    suspend fun toc(sourceJson: String, tocUrl: String): String =
        withSource(sourceJson) { source ->
            val absolute = absoluteUrl(source, tocUrl)
            val rule = load(source, absolute, null, 1, direct = true)
            val toc = source.ruleToc
            val rows = rule.getElements(toc?.chapterList ?: return@withSource "[]")
            val array = JSONArray()
            rows.forEach { row ->
                val link = rule.getString(toc?.chapterUrl, row)
                if (link.isNullOrBlank()) return@forEach
                array.put(
                    JSONObject().apply {
                        put("title", rule.getString(toc?.chapterName, row))
                        put("url", link)
                    }
                )
            }
            array.toString()
        }

    /**
     * 正文：按 `nextContentUrl` 逐页合并后返回。
     *
     * 51 个本地书源的正文是分页的（`{{page}}` 或「下一页」链接），只取第一页会截断。
     * 合并上限 [MAX_CONTENT_PAGES] 页，`visited` 防环。`replaceRegex` 是独立的净化
     * 规则（`##正则##替换`），必须作用在**合并后的全文**上，不能拼进 DOM 规则里。
     */
    suspend fun content(sourceJson: String, chapterUrl: String): String =
        withSource(sourceJson) { source ->
            val contentRule = source.ruleContent
            val buffer = StringBuilder()
            val visited = mutableSetOf<String>()
            var url = absoluteUrl(source, chapterUrl)
            var pages = 0
            while (url.isNotBlank() && visited.add(url) && pages < MAX_CONTENT_PAGES) {
                pages++
                val analyzeUrl = AnalyzeUrl(url, source = source)
                val body = analyzeUrl.getStrResponseAwait().body ?: break
                val rule = AnalyzeRule(null, source).setContent(body, analyzeUrl.url)
                val text = rule.getString(contentRule?.content)
                if (text.isBlank()) break
                if (buffer.isNotEmpty()) buffer.append('\n')
                buffer.append(text)

                val nextRule = contentRule?.nextContentUrl
                if (nextRule.isNullOrBlank()) break
                val next = rule
                    .getStringList(nextRule)
                    ?.firstOrNull { it.isNotBlank() }
                    ?: break
                url = absoluteUrl(analyzeUrl.url, next)
            }
            applyReplace(buffer.toString(), contentRule?.replaceRegex)
        }

    /**
     * 应用 `##正则##替换` 净化规则。
     *
     * 规则可能是多段（`##a##b##c##d`），奇数位是正则、偶数位是替换文本；`###` 结尾
     * 表示只替换首个匹配。写坏的正则按「不替换」处理，不让整章正文失败。
     */
    private fun applyReplace(text: String, rule: String?): String {
        if (rule.isNullOrBlank() || text.isEmpty()) return text
        if (!rule.startsWith("##")) {
            // 只有正则没有 `##` 包裹：按「删除匹配」处理，与 Archive 的宽松写法一致
            return runCatching { text.replace(Regex(rule), "") }.getOrDefault(text)
        }
        val onlyOne = rule.endsWith("###")
        val body = if (onlyOne) rule.dropLast(3) else rule
        val segments = body.split("##")
        var out = text
        var index = 1
        while (index < segments.size) {
            val pattern = segments[index]
            val replacement = segments.getOrNull(index + 1) ?: ""
            if (pattern.isNotBlank()) {
                out = runCatching {
                    if (onlyOne) {
                        out.replaceFirst(Regex(pattern), replacement)
                    } else {
                        out.replace(Regex(pattern), replacement)
                    }
                }.getOrDefault(out)
            }
            index += 2
        }
        return out
    }

    // ---- 内部 ----

    /** 正文分页合并上限，防止规则写错时无限翻页。 */
    private const val MAX_CONTENT_PAGES = 12



    /**
     * 把书源规则产出的相对地址补成绝对地址。
     *
     * 书源的 `bookUrl` / `tocUrl` / `chapterUrl` 大多写成 `/book/1.html` 这种相对路径，
     * 而详情、目录、正文三个入口拿到的是「字符串地址」，没有当前页面可参考，因此
     * 统一按 `bookSourceUrl` 解析。`Uri.resolve` 会处理查询串与路径深度，不能用字符串拼接。
     */
    private fun absoluteUrl(source: BookSource, url: String): String =
        absoluteUrl(source.bookSourceUrl.substringBefore('#').trim(), url)

    /** 按给定页面地址解析相对链接（正文分页要用「当前页」而不是书源根地址）。 */
    private fun absoluteUrl(baseUrl: String, url: String): String {
        val text = url.trim()
        if (text.isEmpty()) return text
        if (text.startsWith("http://") || text.startsWith("https://")) return text
        if (baseUrl.isBlank()) return text
        return runCatching {
            java.net.URI(baseUrl).resolve(text).toString()
        }.getOrElse { text }
    }

    private suspend fun <T> withSource(sourceJson: String, block: suspend (BookSource) -> T): T {
        val source = GSON.fromJson(sourceJson, BookSource::class.java)
            ?: error("书源 JSON 解析失败")
        return kotlinx.coroutines.withContext(Dispatchers.IO) { block(source) }
    }

    /**
     * 抓页面并绑定规则作用域。
     *
     * [direct] 为 true 时把 [spec] 当作完整地址（详情/目录/正文），否则按
     * 「书源 searchUrl + key/page」组装并解析相对地址。
     */
    private suspend fun load(
        source: BookSource,
        spec: String,
        key: String?,
        page: Int,
        direct: Boolean = false
    ): AnalyzeRule {
        val analyzeUrl = if (direct) {
            AnalyzeUrl(spec, source = source)
        } else {
            AnalyzeUrl(spec, key = key, page = page, source = source)
        }
        val response = analyzeUrl.getStrResponseAwait()
        val body = response.body ?: ""
        return AnalyzeRule(null, source).setContent(body, analyzeUrl.url)
    }
}

package io.legado.app.help

import android.webkit.JavascriptInterface
import android.webkit.WebSettings
import androidx.annotation.Keep
import cn.hutool.core.codec.Base64
import cn.hutool.core.util.HexUtil
import com.script.rhino.rhinoContext
import com.script.rhino.rhinoContextOrNull
import io.legado.app.constant.AppConst
import io.legado.app.constant.AppConst.dateFormat
import io.legado.app.constant.AppLog
import io.legado.app.constant.AppPattern
import io.legado.app.data.entities.BaseSource
import io.legado.app.data.entities.HttpTTS
import io.legado.app.exception.NoStackTraceException
import io.legado.app.help.config.AppConfig
import io.legado.app.help.http.CookieManager.cookieJarHeader
import io.legado.app.help.http.CookieStore
import io.legado.app.help.http.SSLHelper
import io.legado.app.help.http.StrResponse
import io.legado.app.help.http.dns.DnsRequestContext
import io.legado.app.help.http.dns.DnsScope
import io.legado.app.model.Debug
import io.legado.app.model.analyzeRule.AnalyzeUrl
import io.legado.app.model.analyzeRule.QueryTTF
import io.legado.app.utils.ChineseUtils
import io.legado.app.utils.EncoderUtils
import io.legado.app.utils.EncodingDetect
import io.legado.app.utils.FileUtils
import io.legado.app.utils.GSON
import io.legado.app.utils.HtmlFormatter
import io.legado.app.utils.JsURL
import io.legado.app.utils.MD5Utils
import io.legado.app.utils.StringUtils
import io.legado.app.utils.UrlUtil
import io.legado.app.utils.fromJsonObject
import io.legado.app.utils.isAbsUrl
import io.legado.app.utils.isMainThread
import io.legado.app.utils.longToastOnUi
import io.legado.app.utils.stackTraceStr
import io.legado.app.utils.toStringArray
import io.legado.app.utils.toastOnUi
import kotlinx.coroutines.Dispatchers.IO
import kotlinx.coroutines.flow.asFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking
import io.legado.app.utils.createFileReplace
import io.legado.app.utils.externalCache
import io.legado.app.utils.isSameOrSubFileOf
import io.legado.app.utils.mapAsync
import org.json.JSONObject
import okio.use
import org.jsoup.Connection
import org.jsoup.Jsoup
import splitties.init.appCtx
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.URLEncoder
import java.nio.charset.Charset
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.SimpleTimeZone
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import kotlin.coroutines.CoroutineContext
import kotlin.coroutines.EmptyCoroutineContext
import androidx.core.net.toUri

/**
 * js扩展类, 在js中通过java变量调用
 * 添加方法，请更新文档/legado/app/src/main/assets/help/JsHelp.md
 * 所有对于文件的读写删操作都是相对路径,只能操作阅读缓存内的文件
 * /android/data/{package}/cache/...
 */
@Keep
@Suppress("unused")
interface JsExtensions : JsEncodeUtils {

    fun getSource(): BaseSource?
    fun getNetworkDnsScope(): DnsScope = if (getSource() is HttpTTS) DnsScope.MEDIA else DnsScope.READING
    fun getTag(): String?
    fun isWebSocketAllowed(): Boolean = false

    private val context: CoroutineContext
        get() = rhinoContextOrNull?.coroutineContext ?: EmptyCoroutineContext

    private fun webSocketScopeKey(): String {
        val source = getSource()
        return source?.getKey()?.takeIf { it.isNotBlank() }
            ?: getTag()?.takeIf { it.isNotBlank() }
            ?: "default"
    }

    private fun requireWebSocketAllowed() {
        if (!isWebSocketAllowed()) {
            throw NoStackTraceException("WebSocket is only available in read aloud synthesis JS")
        }
    }

    fun wsOpen(id: String, url: String): String {
        return wsOpen(id, url, null, 15_000L)
    }

    fun wsOpen(id: String, url: String, headerJson: String?): String {
        return wsOpen(id, url, headerJson, 15_000L)
    }

    fun wsOpen(id: String, url: String, headerJson: String?, timeoutMs: Long): String {
        requireWebSocketAllowed()
        return JsWebSocketManager.open(webSocketScopeKey(), id, url, headerJson, timeoutMs)
    }

    fun wsSend(id: String, text: String): String {
        requireWebSocketAllowed()
        return JsWebSocketManager.sendText(webSocketScopeKey(), id, text)
    }

    fun wsSendBase64(id: String, base64: String): String {
        requireWebSocketAllowed()
        return JsWebSocketManager.sendBase64(webSocketScopeKey(), id, base64)
    }

    fun wsLock(id: String): String {
        return wsLock(id, 30_000L)
    }

    fun wsLock(id: String, timeoutMs: Long): String {
        requireWebSocketAllowed()
        return JsWebSocketManager.lock(webSocketScopeKey(), id, timeoutMs)
    }

    fun wsUnlock(id: String): String {
        requireWebSocketAllowed()
        return JsWebSocketManager.unlock(webSocketScopeKey(), id)
    }

    fun wsRead(id: String): String {
        return wsRead(id, 30_000L)
    }

    fun wsRead(id: String, timeoutMs: Long): String {
        requireWebSocketAllowed()
        return JsWebSocketManager.read(webSocketScopeKey(), id, timeoutMs)
    }

    fun wsClose(id: String): String {
        requireWebSocketAllowed()
        return JsWebSocketManager.close(webSocketScopeKey(), id)
    }

    /**
     * 访问网络,返回String
     */
    fun ajax(url: Any): String? {
        return ajax(url, null)
    }

    fun ajax(url: Any, callTimeout: Long?): String? {
        val urlStr = if (url is List<*>) {
            url.firstOrNull().toString()
        } else {
            url.toString()
        }
        val analyzeUrl = AnalyzeUrl(urlStr, dnsScope = getNetworkDnsScope(), source = getSource(), callTimeout = callTimeout, coroutineContext = context)
        return kotlin.runCatching {
            analyzeUrl.getStrResponse().body
        }.onFailure {
            rhinoContextOrNull?.ensureActive()
            AppLog.put("ajax(${urlStr}) error\n${it.localizedMessage}", it)
        }.getOrElse {
            it.stackTraceStr
        }
    }

    /**
     * 并发访问网络
     */
    fun ajaxAll(urlList: Array<String>): Array<StrResponse> {
        return ajaxAll(urlList, false)
    }
    fun ajaxAll(urlList: Array<String>, skipRateLimit: Boolean): Array<StrResponse> {
        return runBlocking(context) {
            urlList.asFlow().mapAsync(AppConfig.threadCount) { url ->
                val analyzeUrl = AnalyzeUrl(
                    url, dnsScope = getNetworkDnsScope(),
                    source = getSource(),
                    coroutineContext = coroutineContext
                )
                analyzeUrl.getStrResponseAwait(skipRateLimit = skipRateLimit)
            }.flowOn(IO).toList().toTypedArray()
        }
    }

    /**
     * 并发测试网络
     */
    fun ajaxTestAll(urlList: Array<String>, timeout: Int): Array<StrResponse> {
        return ajaxTestAll(urlList, timeout, false)
    }
    fun ajaxTestAll(urlList: Array<String>, timeout: Int, skipRateLimit: Boolean): Array<StrResponse> {
        return runBlocking(context) {
            urlList.asFlow().mapAsync(AppConfig.threadCount) { url ->
                val analyzeUrl = AnalyzeUrl(
                    url, dnsScope = getNetworkDnsScope(),
                    source = getSource(),
                    coroutineContext = coroutineContext,
                    callTimeout = timeout.toLong()
                )
                analyzeUrl.getStrResponseAwait(isTest = true, skipRateLimit = skipRateLimit)
            }.flowOn(IO).toList().toTypedArray()
        }
    }


    /**
     * 访问网络,返回Response<String>
     */
    fun connect(urlStr: String): StrResponse {
        val analyzeUrl = AnalyzeUrl(
            urlStr, dnsScope = getNetworkDnsScope(),
            source = getSource(),
            coroutineContext = context
        )
        return kotlin.runCatching {
            analyzeUrl.getStrResponse()
        }.onFailure {
            rhinoContextOrNull?.ensureActive()
            AppLog.put("connect(${urlStr}) error\n${it.localizedMessage}", it)
        }.getOrElse {
            StrResponse(analyzeUrl.url, it.stackTraceStr)
        }
    }

    fun connect(urlStr: String, header: String?): StrResponse {
        return connect(urlStr, header, null)
    }

    fun connect(urlStr: String, header: String?, callTimeout: Long?): StrResponse {
        val headerMap = GSON.fromJsonObject<Map<String, String>>(header).getOrNull()
        val analyzeUrl = AnalyzeUrl(
            urlStr, dnsScope = getNetworkDnsScope(),
            headerMapF = headerMap,
            source = getSource(),
            callTimeout = callTimeout,
            coroutineContext = context
        )
        return kotlin.runCatching {
            analyzeUrl.getStrResponse()
        }.onFailure {
            rhinoContextOrNull?.ensureActive()
            AppLog.put("connect($urlStr,$header) error\n${it.localizedMessage}", it)
        }.getOrElse {
            StrResponse(analyzeUrl.url, it.stackTraceStr)
        }
    }

    /**
     *js实现读取cookie
     */
    @JavascriptInterface
    fun getCookie(tag: String): String {
        return getCookie(tag, null)
    }

    @JavascriptInterface
    fun getCookie(tag: String, key: String?): String {
        return if (key != null) {
            CookieStore.getKey(tag, key)
        } else {
            CookieStore.getCookie(tag)
        }
    }

    /**
     * 下载文件
     * @param url 下载地址:可带参数type
     * @return 下载的文件相对路径
     */
    @JavascriptInterface
    fun downloadFile(url: String): String {
        rhinoContextOrNull?.ensureActive()
        val analyzeUrl = AnalyzeUrl(url, dnsScope = getNetworkDnsScope(), source = getSource(), coroutineContext = context)
        val type = analyzeUrl.type ?: UrlUtil.getSuffix(url)
        val path = FileUtils.getPath(
            File(FileUtils.getCachePath()),
            "${MD5Utils.md5Encode16(url)}.${type}"
        )
        val file = File(path)
        file.delete()
        analyzeUrl.getInputStream().use { iStream ->
            file.createFileReplace()
            try {
                file.outputStream().buffered().use { oStream ->
                    iStream.copyTo(oStream)
                }
            } catch (e: Throwable) {
                file.delete()
                throw e
            }
        }
        return path.substring(FileUtils.getCachePath().length)
    }


    /**
     * 实现16进制字符串转文件
     * @param content 需要转成文件的16进制字符串
     * @param url 通过url里的参数来判断文件类型
     * @return 相对路径
     */
    @Deprecated(
        "Deprecated",
        ReplaceWith("downloadFile(url)")
    )
    @JavascriptInterface
    fun downloadFile(content: String, url: String): String {
        rhinoContextOrNull?.ensureActive()
        val type = AnalyzeUrl(url, dnsScope = getNetworkDnsScope(), source = getSource(), coroutineContext = context).type
            ?: return ""
        val path = FileUtils.getPath(
            FileUtils.createFolderIfNotExist(FileUtils.getCachePath()),
            "${MD5Utils.md5Encode16(url)}.${type}"
        )
        val file = File(path)
        file.createFileReplace()
        HexUtil.decodeHex(content).let {
            if (it.isNotEmpty()) {
                file.writeBytes(it)
            }
        }
        return path.substring(FileUtils.getCachePath().length)
    }

    /**
     * js实现重定向拦截,网络访问get
     */
    fun get(urlStr: String, headers: Map<String, String>): Connection.Response {
        return get(urlStr, headers, null)
    }

    fun get(urlStr: String, headers: Map<String, String>, timeout: Int?): Connection.Response {
        val requestHeaders = if (getSource()?.enabledCookieJar == true) {
            headers.toMutableMap().apply { put(cookieJarHeader, "1") }
        } else headers
        val rateLimiter = ConcurrentRateLimiter(getSource())
        val response = rateLimiter.withLimitBlocking {
            DnsRequestContext.withScope(getNetworkDnsScope()) {
                rhinoContextOrNull?.ensureActive()
                Jsoup.connect(urlStr)
                    .sslSocketFactory(SSLHelper.unsafeSSLSocketFactory)
                    .timeout(timeout ?: 30000)
                    .ignoreContentType(true)
                    .followRedirects(false)
                    .headers(requestHeaders)
                    .method(Connection.Method.GET)
                    .execute()
            }
        }
        return response
    }

    /**
     * js实现重定向拦截,网络访问head,不返回Response Body更省流量
     */
    fun head(urlStr: String, headers: Map<String, String>): Connection.Response {
        return head(urlStr, headers, null)
    }

    fun head(urlStr: String, headers: Map<String, String>, timeout: Int?): Connection.Response {
        val requestHeaders = if (getSource()?.enabledCookieJar == true) {
            headers.toMutableMap().apply { put(cookieJarHeader, "1") }
        } else headers
        val rateLimiter = ConcurrentRateLimiter(getSource())
        val response = rateLimiter.withLimitBlocking {
            DnsRequestContext.withScope(getNetworkDnsScope()) {
                rhinoContextOrNull?.ensureActive()
                Jsoup.connect(urlStr)
                    .sslSocketFactory(SSLHelper.unsafeSSLSocketFactory)
                    .timeout(timeout ?: 30000)
                    .ignoreContentType(true)
                    .followRedirects(false)
                    .headers(requestHeaders)
                    .method(Connection.Method.HEAD)
                    .execute()
            }
        }
        return response
    }

    /**
     * 网络访问post
     */
    fun post(urlStr: String, body: String, headers: Map<String, String>): Connection.Response {
        return post(urlStr, body, headers, null)
    }

    fun post(urlStr: String, body: String, headers: Map<String, String>, timeout: Int?): Connection.Response {
        val requestHeaders = if (getSource()?.enabledCookieJar == true) {
            headers.toMutableMap().apply { put(cookieJarHeader, "1") }
        } else headers
        val rateLimiter = ConcurrentRateLimiter(getSource())
        val response = rateLimiter.withLimitBlocking {
            DnsRequestContext.withScope(getNetworkDnsScope()) {
                rhinoContextOrNull?.ensureActive()
                Jsoup.connect(urlStr)
                    .sslSocketFactory(SSLHelper.unsafeSSLSocketFactory)
                    .timeout(timeout ?: 30000)
                    .ignoreContentType(true)
                    .followRedirects(false)
                    .requestBody(body)
                    .headers(requestHeaders)
                    .method(Connection.Method.POST)
                    .execute()
            }
        }
        return response
    }

    /* Str转ByteArray */
    fun strToBytes(str: String): ByteArray {
        return str.toByteArray(charset("UTF-8"))
    }

    fun strToBytes(str: String, charset: String): ByteArray {
        return str.toByteArray(charset(charset))
    }

    /* ByteArray转Str */
    fun bytesToStr(bytes: ByteArray): String {
        return String(bytes, charset("UTF-8"))
    }

    fun bytesToStr(bytes: ByteArray, charset: String): String {
        return String(bytes, charset(charset))
    }

    /**
     * js实现base64解码,不能删
     */
    @JavascriptInterface
    fun base64Decode(str: String?): String {
        return Base64.decodeStr(str)
    }

    @JavascriptInterface
    fun base64Decode(str: String?, charset: String): String {
        return Base64.decodeStr(str, charset(charset))
    }

    @JavascriptInterface
    fun base64Decode(str: String, flags: Int): String {
        return EncoderUtils.base64Decode(str, flags)
    }

    fun base64DecodeToByteArray(str: String?): ByteArray? {
        if (str.isNullOrBlank()) {
            return null
        }
        return EncoderUtils.base64DecodeToByteArray(str, 0)
    }

    fun base64DecodeToByteArray(str: String?, flags: Int): ByteArray? {
        if (str.isNullOrBlank()) {
            return null
        }
        return EncoderUtils.base64DecodeToByteArray(str, flags)
    }

    @JavascriptInterface
    fun base64Encode(str: String): String? {
        return EncoderUtils.base64Encode(str, 2)
    }

    @JavascriptInterface
    fun base64Encode(str: String, flags: Int): String? {
        return EncoderUtils.base64Encode(str, flags)
    }

    /* HexString 解码为字节数组 */
    fun hexDecodeToByteArray(hex: String): ByteArray? {
        return HexUtil.decodeHex(hex)
    }

    /* hexString 解码为utf8String*/
    @JavascriptInterface
    fun hexDecodeToString(hex: String): String? {
        return HexUtil.decodeHexStr(hex)
    }

    /* utf8 编码为hexString */
    @JavascriptInterface
    fun hexEncodeToString(utf8: String): String? {
        return HexUtil.encodeHexStr(utf8)
    }

    /**
     * 格式化时间
     */
    @JavascriptInterface
    fun timeFormatUTC(time: Long, format: String, sh: Int): String? {
        val utc = SimpleTimeZone(sh, "UTC")
        return SimpleDateFormat(format, Locale.getDefault()).run {
            timeZone = utc
            format(Date(time))
        }
    }

    /**
     * 时间格式化
     */
    @JavascriptInterface
    fun timeFormat(time: Long): String {
        return dateFormat.format(Date(time))
    }

    @JavascriptInterface
    fun encodeURI(str: String): String {
        return try {
            URLEncoder.encode(str, "UTF-8")
        } catch (e: Exception) {
            ""
        }
    }

    @JavascriptInterface
    fun encodeURI(str: String, enc: String): String {
        return try {
            URLEncoder.encode(str, enc)
        } catch (e: Exception) {
            ""
        }
    }

    @JavascriptInterface
    fun htmlFormat(str: String): String {
        return HtmlFormatter.formatKeepImg(str)
    }

    @JavascriptInterface
    fun t2s(text: String): String {
        return ChineseUtils.t2s(text)
    }

    @JavascriptInterface
    fun s2t(text: String): String {
        return ChineseUtils.s2t(text)
    }

    @JavascriptInterface
    fun getWebViewUA(): String {
        return WebSettings.getDefaultUserAgent(appCtx)
    }

//****************文件操作******************//

    /**
     * 获取本地文件
     * @param path 相对路径
     * @return File
     */
    fun getFile(path: String): File {
        val cachePath = appCtx.externalCache.absolutePath
        val aPath = if (path.startsWith(File.separator)) {
            cachePath + path
        } else {
            cachePath + File.separator + path
        }
        val file = File(aPath)
        val safeDir = File(appCtx.externalCache.parent!!)
        if (!file.isSameOrSubFileOf(safeDir)) {
            throw SecurityException("非法路径")
        }
        return file
    }

    fun readFile(path: String): ByteArray? {
        val file = getFile(path)
        if (file.exists()) {
            return file.readBytes()
        }
        return null
    }

    @JavascriptInterface
    fun readTxtFile(path: String): String {
        val file = getFile(path)
        if (file.exists()) {
            val charsetName = EncodingDetect.getEncode(file)
            return String(file.readBytes(), charset(charsetName))
        }
        return ""
    }

    @JavascriptInterface
    fun readTxtFile(path: String, charsetName: String): String {
        val file = getFile(path)
        if (file.exists()) {
            return String(file.readBytes(), charset(charsetName))
        }
        return ""
    }

    /**
     * 删除本地文件
     */
    @JavascriptInterface
    fun deleteFile(path: String): Boolean {
        val file = getFile(path)
        return FileUtils.delete(file, true)
    }


//******************文件操作************************//

    /**
     * 解析字体Base64数据,返回字体解析类
     */
    @Deprecated(
        "Deprecated",
        ReplaceWith("queryTTF(data)")
    )
    fun queryBase64TTF(data: String?): QueryTTF? {
        log("queryBase64TTF(String)方法已过时,并将在未来删除；请无脑使用queryTTF(Any)替代，新方法支持传入 url、本地文件、base64、ByteArray 自动判断&自动缓存，特殊情况需禁用缓存请传入第二可选参数false:Boolean")
        return queryTTF(data)
    }

    /**
     * 返回字体解析类
     * @param data 支持url,本地文件,base64,ByteArray,自动判断,自动缓存
     * @param useCache 可选开关缓存,不传入该值默认开启缓存
     */
    @OptIn(ExperimentalStdlibApi::class)
    fun queryTTF(data: Any?, useCache: Boolean): QueryTTF? {
        try {
            var key: String? = null
            var qTTF: QueryTTF?
            when (data) {
                is String -> {
                    if (useCache) {
                        key = MessageDigest.getInstance("SHA-256").digest(data.toByteArray())
                            .toHexString()
                        qTTF = AppCacheManager.getQueryTTF(key)
                        if (qTTF != null) return qTTF
                    }
                    val font: ByteArray? = when {
                        data.isAbsUrl() -> AnalyzeUrl(
                            data, dnsScope = getNetworkDnsScope(),
                            source = getSource(),
                            coroutineContext = context
                        ).getByteArray()

                        else -> base64DecodeToByteArray(data)
                    }
                    font ?: return null
                    qTTF = QueryTTF(font)
                }

                is ByteArray -> {
                    if (useCache) {
                        key = MessageDigest.getInstance("SHA-256").digest(data).toHexString()
                        qTTF = AppCacheManager.getQueryTTF(key)
                        if (qTTF != null) return qTTF
                    }
                    qTTF = QueryTTF(data)
                }

                else -> return null
            }
            if (key != null) AppCacheManager.put(key, qTTF)
            return qTTF
        } catch (e: Exception) {
            AppLog.put("[queryTTF] 获取字体处理类出错", e)
            throw e
        }
    }

    fun queryTTF(data: Any?): QueryTTF? {
        return queryTTF(data, true)
    }


    /**
     * 章节数转数字
     */
    @JavascriptInterface
    fun toNumChapter(s: String?): String? {
        s ?: return null
        val matcher = AppPattern.titleNumPattern.matcher(s)
        if (matcher.find()) {
            val intStr = StringUtils.stringToInt(matcher.group(2))
            return "${matcher.group(1)}${intStr}${matcher.group(3)}"
        }
        return s
    }


    fun toURL(urlStr: String): JsURL {
        return JsURL(urlStr)
    }

    fun toURL(url: String, baseUrl: String? = null): JsURL {
        return JsURL(url, baseUrl)
    }

    /**
     * 弹窗提示
     */
    fun toast(msg: Any?) {
        rhinoContextOrNull?.ensureActive()
        appCtx.toastOnUi("${getTag()}: ${msg.toString()}")
    }

    /**
     * 弹窗提示 停留时间较长
     */
    fun longToast(msg: Any?) {
        rhinoContextOrNull?.ensureActive()
        appCtx.longToastOnUi("${getTag()}: ${msg.toString()}")
    }

    /**
     * 输出调试日志
     */
    fun log(msg: Any?): Any? {
        rhinoContextOrNull?.ensureActive()
        getSource()?.let {
            Debug.log(it.getKey(), msg.toString())
        } ?: Debug.log(msg.toString())
        AppLog.putDebug("${getTag() ?: "源"}调试输出: $msg")
        return msg
    }

    /**
     * 输出对象类型
     */
    fun logType(any: Any?) {
        if (any == null) {
            log("null")
        } else {
            log(any.javaClass.name)
        }
    }

    /**
     * 生成UUID
     */
    @JavascriptInterface
    fun randomUUID(): String {
        return UUID.randomUUID().toString()
    }

    @JavascriptInterface
    fun androidId(): String {
        return AppConst.androidId
    }

}

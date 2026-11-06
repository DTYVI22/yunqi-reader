package io.legado.app.help.glide

import com.bumptech.glide.load.model.Headers
import com.bumptech.glide.load.model.LazyHeaders

/**
 * 把书源解析出的请求头转成 Glide 的 `Headers`，让封面请求带 Referer/UA。
 * Archive 原实现还处理了一些图床的特殊要求，引擎只需要标准映射。
 */
@Suppress("FunctionName")
fun GlideHeaders(headerMap: Map<String, String>): Headers {
    val builder = LazyHeaders.Builder()
    headerMap.forEach { (key, value) -> builder.addHeader(key, value) }
    return builder.build()
}

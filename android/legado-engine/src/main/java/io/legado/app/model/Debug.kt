package io.legado.app.model

/**
 * Archive `model/Debug.kt` 的裁剪版。
 *
 * 原实现（370 行）把调试信息写进 UI 层的 DebugActivity，并依赖 WebBook/Rss 做
 * 「整源调试」。规则求值链路只需要 `log(...)` 与 `Callback`，因此这里只保留
 * 这两项，消息转给 [EngineHost] 注册的监听器，由 Flutter 侧订阅展示。
 */
object Debug {

    interface Callback {
        fun printLog(state: Int, msg: String)
    }

    var callback: Callback? = null

    var isChecking: Boolean = false

    val debugMessageMap = HashMap<String, String>()

    private val timeFormat = java.text.SimpleDateFormat("[mm:ss.SSS]", java.util.Locale.getDefault())

    private val startTime: Long = System.currentTimeMillis()

    @Synchronized
    fun log(
        sourceUrl: String?,
        msg: String = "",
        print: Boolean = true,
        isHtml: Boolean = false,
        showTime: Boolean = true,
        state: Int = 1
    ) {
        val body = when {
            isHtml -> msg
            showTime -> "${timeFormat.format(System.currentTimeMillis() - startTime)}$msg"
            else -> msg
        }
        if (sourceUrl != null) {
            debugMessageMap[sourceUrl] = body
        }
        if (print) {
            callback?.printLog(state, body)
        }
    }

    fun log(msg: String?) {
        if (msg == null) return
        callback?.printLog(1, msg)
    }

    fun getRespondTime(sourceUrl: String): Long = 0L

    fun updateFinalMessage(sourceUrl: String, state: String) {
        debugMessageMap[sourceUrl] = state
    }

    fun clearCheckingCache() {
        debugMessageMap.clear()
    }
}

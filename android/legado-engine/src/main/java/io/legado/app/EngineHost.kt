package io.legado.app

import android.content.Context
import splitties.init.AppCtxHolder

/**
 * 引擎宿主：把 Android Context 注入 Archive 引擎，并暴露日志出口。
 *
 * 原工程由 `App : Application` 在 `onCreate` 里完成这些事，并把 Context 交给
 * splitties 的全局 `appCtx`。Flutter 侧没有这个 Application 子类，因此改成
 * 显式安装：FlutterPlugin 的 `onAttachedToEngine` 里调一次 [install] 即可。
 */
object EngineHost {

    @Volatile
    private var installed = false

    val isInstalled: Boolean get() = installed

    /** 规则调试日志出口，由 facade 接到 MethodChannel。 */
    @Volatile
    var logSink: ((state: Int, message: String) -> Unit)? = null

    fun install(context: Context) {
        if (installed) return
        AppCtxHolder.context = context.applicationContext
        io.legado.app.model.Debug.callback =
            object : io.legado.app.model.Debug.Callback {
                override fun printLog(state: Int, msg: String) {
                    logSink?.invoke(state, msg)
                }
            }
        installed = true
    }
}

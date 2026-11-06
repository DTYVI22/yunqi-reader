package splitties.init

import android.annotation.SuppressLint
import android.content.Context

/**
 * `splitties` 的 `appCtx` 的最小替代实现。
 *
 * Archive 用 splitties 的全局 Application Context。引入整套 splitties 只为拿一个
 * Context 不划算，这里提供同包名同语义的全局持有者，由 [io.legado.app.EngineHost]
 * 在初始化时注入。
 */
@SuppressLint("StaticFieldLeak")
object AppCtxHolder {
    @Volatile
    var context: Context? = null
}

val appCtx: Context
    get() = AppCtxHolder.context
        ?: error("EngineHost.install(context) 未调用：书源引擎尚未初始化")

package io.legado.app.utils

import android.content.Context
import android.util.Log
import android.widget.Toast

/**
 * Toast 的引擎版：主线程直接弹，非主线程退回日志。
 *
 * Archive 用 `Handler` 切主线程弹 Toast。引擎多数调用发生在 IO 线程，而 Toast 只能在
 * 有 Looper 的线程弹，因此非主线程一律降级为日志，避免引擎在后台抛异常。
 */
fun Context.toastOnUi(message: String) {
    if (isMainThread) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    } else {
        Log.i("LegadoEngine", message)
    }
}

fun Context.longToastOnUi(message: String) {
    if (isMainThread) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    } else {
        Log.i("LegadoEngine", message)
    }
}

package io.legado.app.utils

import android.os.Looper

/** 是否运行在主线程。原实现在 ThreadUtils 中，引擎只需要这一个判断。 */
val isMainThread: Boolean
    get() = Looper.myLooper() == Looper.getMainLooper()

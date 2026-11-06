package org.mewx.wenku8_flutter

import android.app.Application
import app.yunqi.engine.EngineFacade
import com.ryanheise.audioservice.AudioServicePlugin

/** Attach app bridges even when Android creates the shared engine for a media service first. */
class WenkuApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // 书源引擎只需要 Application Context；提前注入，避免插件未 attach 时 @js 里的
        // java.* 调用拿到空的 appCtx。
        EngineFacade.install(this)
        attachWenkuEnginePlugins(AudioServicePlugin.getFlutterEngine(this))
    }
}

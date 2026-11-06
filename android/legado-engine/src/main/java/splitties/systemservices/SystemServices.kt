package splitties.systemservices

import android.app.DownloadManager
import android.app.UiModeManager
import android.content.ClipboardManager
import android.content.Context
import android.hardware.display.DisplayManager
import android.net.ConnectivityManager
import android.os.PowerManager
import android.view.LayoutInflater
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import splitties.init.appCtx

/**
 * `splitties.systemservices` 的最小替代：只提供引擎实际用到的系统服务全局。
 *
 * 引入整套 splitties 只为几个 `getSystemService` 不值得，这里按同包名、同名称
 * 提供，语义完全一致（都是 Application Context 上的系统服务）。
 */

val Context.connectivityManager: ConnectivityManager
    get() = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

val connectivityManager: ConnectivityManager get() = appCtx.connectivityManager

val Context.clipboardManager: ClipboardManager
    get() = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

val clipboardManager: ClipboardManager get() = appCtx.clipboardManager

val Context.displayManager: DisplayManager
    get() = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

val displayManager: DisplayManager get() = appCtx.displayManager

val Context.downloadManager: DownloadManager
    get() = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

val downloadManager: DownloadManager get() = appCtx.downloadManager

val Context.powerManager: PowerManager
    get() = getSystemService(Context.POWER_SERVICE) as PowerManager

val powerManager: PowerManager get() = appCtx.powerManager

val Context.uiModeManager: UiModeManager
    get() = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager

val uiModeManager: UiModeManager get() = appCtx.uiModeManager

val Context.windowManager: WindowManager
    get() = getSystemService(Context.WINDOW_SERVICE) as WindowManager

val windowManager: WindowManager get() = appCtx.windowManager

val Context.inputMethodManager: InputMethodManager
    get() = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager

val inputMethodManager: InputMethodManager get() = appCtx.inputMethodManager

val Context.layoutInflater: LayoutInflater get() = LayoutInflater.from(this)

val layoutInflater: LayoutInflater get() = appCtx.layoutInflater

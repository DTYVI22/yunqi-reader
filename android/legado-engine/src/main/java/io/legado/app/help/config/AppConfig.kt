package io.legado.app.help.config

/**
 * 引擎用到的配置项裁剪版。
 *
 * 原实现（Archive `help/config/AppConfig.kt`，2454 行）绑定整套 UI 设置与
 * MMKV/SharedPreferences，这里只保留规则求值、网络请求与导出路径真正读取的字段，
 * 其余全部去掉。字段名与语义保持一致，方便以后需要时逐个恢复。
 */
object AppConfig {

    /** 默认 UA：与 Archive 的 `AppConst` 默认一致，书源站点按此识别移动端。 */
    const val DEFAULT_USER_AGENT =
        "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

    var userAgent: String = DEFAULT_USER_AGENT

    var threadCount: Int = 8

    var themeMode: String = "0"

    var isEInkMode: Boolean = false

    var isNightTheme: Boolean = false

    val isCronet: Boolean = false

    var optimizeRender: Boolean = false

    var recordLog: Boolean = false

    var adaptSpecialStyle: Boolean = true

    var tocCountWords: Boolean = false

    var chineseConverterType: Int = 0

    var textReadEngine: String = "text"

    val useEpubCore: Boolean = false

    val showMangaUi: Boolean = true

    val replaceEnableDefault: Boolean = true

    var preDownloadNum: Int = 3

    var imageRetainNum: Int = 3

    var exportType: Int = 0

    var enableCustomExport: Boolean = true

    var bookExportFileName: String? = null

    var episodeExportFileName: String? = null

    var importBookPath: String? = null

    var defaultBookTreeUri: String? = null
}

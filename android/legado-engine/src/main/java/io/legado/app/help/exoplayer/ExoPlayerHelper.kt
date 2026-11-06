package io.legado.app.help.exoplayer

import androidx.media3.common.MediaItem

/**
 * 音频书源（`bookSourceType = 1`）的播放地址构造。
 *
 * Archive 直接对接 ExoPlayer 并用 `media3-datasource-okhttp` 注入请求头。引擎把
 * 播放交给 Flutter 侧（`just_audio`），这里只负责算出「地址 + 请求头」，供
 * `LegadoEngineRepository` 回传给 Dart。
 */
object ExoPlayerHelper {

    data class MediaRequest(
        val url: String,
        val headerMap: Map<String, String>
    )

    fun createMediaItem(url: String, headerMap: Map<String, String>): MediaItem =
        MediaItem.fromUri(url)

    fun createMediaRequest(url: String, headerMap: Map<String, String>): MediaRequest =
        MediaRequest(url, headerMap)
}

package org.mewx.wenku8_flutter

import android.app.Activity
import android.net.Uri
import java.io.File

/**
 * Document converters omitted from the public snapshot. The boundary is kept so
 * the channel wiring and its call sites keep compiling; every conversion
 * reports the format as unavailable instead of silently producing empty books.
 */
internal class BookMarkupImport(
    private val root: File,
    private val readPdf: (File) -> String?,
) {
    @Suppress("unused")
    fun markup(name: String): String? = null
}

internal class BookPdfImport(private val activity: Activity, private val root: File) {
    fun read(file: File): String? = null
}

internal class BookArchiveImport(private val root: File) {
    var documents: BookMarkupImport? = null

    fun prepare(name: String, input: BookDocumentInput): List<Map<String, Any?>> =
        unavailable(name)

    fun prepare(name: String, source: File): List<Map<String, Any?>> =
        unavailable(name)

    private fun unavailable(name: String) = listOf(
        mapOf<String, Any?>(
            "name" to name,
            "error" to "此源码构建未包含该格式的文档转换",
        ),
    )

    companion object {
        const val MAX_ARCHIVE: Long = 512L * 1024 * 1024

        fun supported(name: String): Boolean = false

        fun limit(name: String): Long = MAX_ARCHIVE
    }
}

/**
 * Folder scanner omitted from the public snapshot. Every query reports an empty
 * library so the import entry point degrades to "no files found" instead of
 * throwing.
 */
internal class BookFolderScanner(private val activity: Activity) {
    fun canReadAll(): Boolean = false

    fun selectAll() {}

    fun info(): Map<String, Any?>? = null

    fun select(uri: Uri, flags: Int): Map<String, Any?>? = null

    fun setAutomatic(value: Boolean) {}

    fun disconnect() {}

    fun scan(): Map<String, Any?> = mapOf(
        "books" to emptyList<Any>(),
        "total" to 0,
        "unchanged" to 0,
        "warnings" to emptyList<String>(),
    )

    fun formats(): Set<String> = emptySet()

    fun setFormats(extensions: List<String>) {}

    fun stage(token: String, root: File, copy: (Uri, File, Long) -> Unit) {}

    fun link(
        token: String,
        links: BookTextLinks,
        root: File,
        copy: (Uri, File, Long) -> Unit,
    ) {}

    fun markImported(token: String) {}

    fun finish() {}
}

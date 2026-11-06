package io.legado.app.utils

import android.content.Context
import splitties.init.appCtx
import java.io.File

/** 应用外部缓存目录（无外部存储时退回内部缓存）。 */
val Context.externalCache: File
    get() = externalCacheDir ?: cacheDir

val externalCache: File
    get() = appCtx.externalCache

/**
 * 生成「同名 .tmp」的临时文件，写入完成后再替换目标文件，避免半截文件被读到。
 */
fun File.createFileReplace(): File {
    val parent = parentFile ?: return this
    if (!parent.exists()) parent.mkdirs()
    val tmp = File(parent, "$name.tmp")
    if (tmp.exists()) tmp.delete()
    tmp.createNewFile()
    return tmp
}

/** this 是否是 [parent] 自身或其子路径。 */
fun File.isSameOrSubFileOf(parent: File): Boolean {
    val self = runCatching { canonicalPath }.getOrNull() ?: absolutePath
    val root = runCatching { parent.canonicalPath }.getOrNull() ?: parent.absolutePath
    return self == root || self.startsWith(root.trimEnd(File.separatorChar) + File.separatorChar)
}

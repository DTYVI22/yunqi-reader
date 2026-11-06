package io.legado.app.utils

import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.toList

/**
 * 并发映射。
 *
 * Archive 的 `FlowExtensions.kt` 同时提供书架/数据库的 Flow 辅助（依赖 appDb 与
 * 生命周期感知），引擎只需要这两个纯函数。返回 `Flow` 而不是 `List`，因为调用点
 * 后面还要 `.flowOn(Dispatchers.IO)`：一旦在这里 collect 成 List，就无法再切线程。
 * 并发窗口内保序（`awaitAll` 按输入顺序返回）。
 */
fun <T, R> Flow<T>.mapAsync(
    concurrency: Int,
    block: suspend (T) -> R
): Flow<R> = flow {
    val window = concurrency.coerceIn(1, 64)
    toList().chunked(window).forEach { chunk ->
        coroutineScope {
            chunk.map { item -> async { block(item) } }.awaitAll()
        }.forEach { emit(it) }
    }
}

fun <T, R> Flow<T>.mapAsyncIndexed(
    concurrency: Int,
    block: suspend (Int, T) -> R
): Flow<R> = flow {
    val window = concurrency.coerceIn(1, 64)
    toList().withIndex().chunked(window).forEach { chunk ->
        coroutineScope {
            chunk.map { (index, item) -> async { block(index, item) } }.awaitAll()
        }.forEach { emit(it) }
    }
}

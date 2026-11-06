package io.legado.app.model.webBook

import io.legado.app.data.entities.Book
import io.legado.app.data.entities.BookSource

/**
 * 书源驱动的高层动作（搜书、刷新详情、换源）。
 *
 * Archive 的 `WebBook` 是把 AnalyzeUrl + AnalyzeRule 串成完整流程的编排层，
 * 依赖数据库、书架与缓存。引擎第一阶段只提供规则求值，编排留在 Flutter 侧
 * （`LegadoEngineRepository`），因此这里只保留 `@js` 里会直接调到的两个入口，
 * 并显式失败——它们在书源脚本里出现频率极低（主要是 `reGetBook`）。
 */
object WebBook {

    fun preciseSearchAwait(
        source: BookSource,
        name: String,
        author: String
    ): Result<Book> = Result.failure(
        UnsupportedOperationException("reGetBook 需要编排层，引擎内暂不支持")
    )

    fun getBookInfoAwait(source: BookSource, book: Book, reverse: Boolean): Boolean = false
}

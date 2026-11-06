package io.legado.app.data.entities

/**
 * 书源链路的书籍数据载体。
 *
 * Archive 的 `Book`（533 行）是 Room 实体，额外绑定本地文件、阅读进度、净化规则、
 * 分组管理等业务。规则求值与书籍元信息只需要 [BaseBook] 约定的字段，因此这里
 * 提供一个纯数据实现：字段名与 `Book` 保持一致，JSON 序列化后与书源互通。
 */
data class Book(
    override var name: String = "",
    override var author: String = "",
    override var bookUrl: String = "",
    override var kind: String? = null,
    override var wordCount: String? = null,
    override var variable: String? = null,
    override var infoHtml: String? = null,
    override var tocHtml: String? = null,
    override val variableMap: HashMap<String, String> = hashMapOf(),
    var tocUrl: String = "",
    var origin: String = "",
    var originName: String = "",
    var customTag: String? = null,
    var coverUrl: String? = null,
    var customCoverUrl: String? = null,
    var intro: String? = null,
    var customIntro: String? = null,
    var charset: String? = null,
    var type: Int = 0,
    var group: Long = 0L,
    var latestChapterTitle: String? = null,
    var latestChapterTime: Long = 0L,
    var lastCheckTime: Long = 0L,
    var lastCheckCount: Int = 0,
    var totalChapterNum: Int = 0,
    var durChapterTitle: String? = null,
    var durChapterIndex: Int = 0,
    var durChapterPos: Int = 0,
    var durChapterTime: Long = 0L,
    var canUpdate: Boolean = true,
    var order: Int = 0,
    var originOrder: Int = 0,
    var downloadUrls: List<String>? = null
) : BaseBook {

    val lastChapterIndex: Int get() = totalChapterNum - 1
}


package io.legado.app.help.update

/** App 变体标记，原实现用于签名校验与更新通道选择，引擎内只需枚举值。 */
enum class AppVariant {
    UNKNOWN,
    OFFICIAL,
    BETA_RELEASE,
    BETA_RELEASEA,
    BETA_RELEASES
}

/// 书源的「发现」分类模型。
///
/// 与 Archive 的 `ExploreKind` 对齐：`exploreUrl` 可以让分类带布局权重
/// （`style.layout_flexGrow` / `layout_flexBasisPercent`），也可以只写一个标题
/// 当分组用（`url` 为空）。
library;

class ExploreKind {
  const ExploreKind({
    required this.title,
    this.url,
    this.type = 'url',
    this.action,
    this.flexGrow = 0,
    this.flexBasisPercent = -1,
  });

  factory ExploreKind.fromMap(Map<String, dynamic> map) {
    final style = map['style'];
    return ExploreKind(
      title: '${map['title'] ?? ''}',
      url: (map['url'] as String?)?.trim(),
      type: '${map['type'] ?? 'url'}',
      action: map['action'] as String?,
      flexGrow: style is Map ? (style['flexGrow'] as num?)?.toDouble() ?? 0 : 0,
      flexBasisPercent: style is Map
          ? (style['flexBasisPercent'] as num?)?.toDouble() ?? -1
          : -1,
    );
  }

  final String title;

  /// 相对或绝对地址；为空表示这是一个分组标题。
  final String? url;

  /// archive 的分类类型：url / text / button / toggle / select。本次只消费 url。
  final String type;
  final String? action;
  final double flexGrow;
  final double flexBasisPercent;

  bool get isGroupTitle => (url ?? '').isEmpty;

  /// 需要独占一行（`layout_flexGrow >= 1` 或 `layout_flexBasisPercent >= 1`）。
  bool get isFullRow => flexGrow >= 1 || flexBasisPercent >= 1;
}

class ExploreSource {
  const ExploreSource({
    required this.key,
    required this.name,
    required this.group,
    required this.type,
    required this.kinds,
    this.error,
  });

  /// `bookSourceUrl`，作为引擎调用的唯一标识。
  final String key;
  final String name;
  final String group;

  /// 0 文本 / 1 音频 / 2 图片 / 4 视频。
  final int type;
  final List<ExploreKind> kinds;

  /// 解析失败原因（`@js` 跑挂、站点返回空等）。
  final String? error;

  bool get hasKinds => kinds.any((kind) => !kind.isGroupTitle);

  int get usableCount => kinds.where((kind) => !kind.isGroupTitle).length;
}

class ExploreTarget {
  const ExploreTarget({
    required this.sourceKey,
    required this.sourceName,
    required this.title,
    required this.url,
  });

  final String sourceKey;
  final String sourceName;
  final String title;
  final String url;

  @override
  bool operator ==(Object other) =>
      other is ExploreTarget &&
      other.sourceKey == sourceKey &&
      other.url == url;

  @override
  int get hashCode => Object.hash(sourceKey, url);
}

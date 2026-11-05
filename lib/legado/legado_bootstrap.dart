/// 书源启动装配：从随包资源读出书源列表，构造可直接使用的 legado 仓库。
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../legacy_cover.dart';
import 'book_registry.dart';
import 'legado_client.dart';
import 'legado_repository.dart';
import 'source_store.dart';

/// 随包书源路径。文件由 `tool/legado_bundle.dart` 从书源 JSON 里筛出可执行的源。
const legadoAssetPath = 'assets/legado/sources.json';

/// 读取书源并构造仓库。资源缺失或全部不可用时返回 null，调用方继续用原有源。
///
/// 这里走 [LegadoSourceStore]，所以用户在设置里禁用的源、导入的源都会生效。
Future<LegadoRepository?> openLegadoRepository({
  String assetPath = legadoAssetPath,
}) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final store = LegadoSourceStore(preferences: preferences);
    await store.load(assetPath: assetPath);

    final registry = LegadoBookRegistry(preferences: preferences);
    await registry.load();
    final repository = LegadoRepository(
      sources: () => store.enabled,
      registry: registry,
    );

    // 上游把封面加载器抽空了（legacy_cover.dart 里写死 unavailableOnline），
    // 这里补一个真正能下载的实现。封面地址来自书源规则，实测不需要 Referer。
    final coverClient = LegadoClient(timeout: const Duration(seconds: 10));
    LegacyCover.useRemoteLoader(coverClient.getBytes);

    return repository;
  } catch (_) {
    LegacyCover.useRemoteLoader(null);
    return null;
  }
}

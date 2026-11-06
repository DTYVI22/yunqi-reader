/// 书源启动装配：从随包资源读出书源列表，构造可直接使用的仓库。
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../catalog.dart';
import '../legacy_cover.dart';
import 'book_registry.dart';
import 'legado_client.dart';
import 'legado_engine_repository.dart';
import 'legado_repository.dart';
import 'source_store.dart';

/// 随包书源路径。文件由 `tool/legado_bundle.dart` 从书源 JSON 里筛出可执行的源。
const legadoAssetPath = 'assets/legado/sources.json';

/// 读取书源并构造仓库。资源缺失或全部不可用时返回 null，调用方继续用原有源。
///
/// 优先用 Android 引擎（Archive 的规则求值 + Rhino，支持 `@js` / JSONPath / XPath /
/// 正文分页）；引擎不可用（非 Android、通道未注册、Rhino 初始化失败）时回落到
/// 纯 Dart 引擎，保证至少有「纯 CSS 源」能跑。
Future<NovelRepository?> openLegadoRepository({
  String assetPath = legadoAssetPath,
}) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final store = LegadoSourceStore(preferences: preferences);
    await store.load(assetPath: assetPath);

    final registry = LegadoBookRegistry(preferences: preferences);
    await registry.load();

    final engine = LegadoEngineRepository(
      sources: () => store.enabled,
      registry: registry,
    );
    final lite = LegadoRepository(
      sources: () => store.enabled,
      registry: registry,
    );

    // 封面加载器：Dart 侧统一实现，两个仓库共用。
    final coverClient = LegadoClient(timeout: const Duration(seconds: 10));
    LegacyCover.useRemoteLoader(coverClient.getBytes);

    if (await engine.isAvailable()) return engine;
    return lite;
  } catch (_) {
    LegacyCover.useRemoteLoader(null);
    return null;
  }
}

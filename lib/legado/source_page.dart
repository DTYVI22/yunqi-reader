/// 书源管理页：查看随包书源、导入自己的书源、启用或禁用。
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_language.dart';
import 'book_source.dart';
import 'source_store.dart';

class LegadoSourcePage extends StatefulWidget {
  const LegadoSourcePage({super.key});

  @override
  State<LegadoSourcePage> createState() => _LegadoSourcePageState();
}

class _LegadoSourcePageState extends State<LegadoSourcePage> {
  LegadoSourceStore? _store;
  bool _busy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final preferences = await SharedPreferences.getInstance();
    final store = LegadoSourceStore(preferences: preferences);
    await store.load();
    if (!mounted) return;
    setState(() => _store = store);
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入书源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '粘贴书源 JSON，或填写书源分享链接（http/https 开头）。',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'https://…….json',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || input.isEmpty) return;

    setState(() {
      _busy = true;
      _notice = null;
    });
    final store = _store;
    ImportResult result;
    if (input.startsWith('http://') || input.startsWith('https://')) {
      result = await store!.importUrl(input);
    } else {
      result = await store!.importJson(input);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = result.summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        actions: [
          IconButton(
            tooltip: '导入书源',
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.add_link),
          ),
        ],
      ),
      body: store == null
          ? const Center(child: CircularProgressIndicator())
          : _busy
          ? const Center(child: CircularProgressIndicator())
          : _body(store, colors),
    );
  }

  Widget _body(LegadoSourceStore store, ColorScheme colors) {
    final all = store.all;
    final enabled = store.enabled.length;
    final unsupported = store.unsupported.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (_notice case final notice?)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              notice,
              style: TextStyle(fontSize: 13, color: colors.primary),
            ),
          ),
        Text(
          '共 ${all.length} 个 · 可用 $enabled · 不支持 $unsupported',
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          '带有脚本规则（@js / <js>）的源当前引擎不执行，已自动跳过。'
          '禁用的源不会参与搜索。',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: colors.onSurfaceVariant.withValues(alpha: .8),
          ),
        ),
        const SizedBox(height: 16),
        for (final source in all) _tile(source, store, colors),
      ],
    );
  }

  Widget _tile(
    LegadoBookSource source,
    LegadoSourceStore store,
    ColorScheme colors,
  ) {
    final supported = source.isSupported;
    final on = store.isEnabled(source);
    final subtitle = <String>[
      if (source.group.isNotEmpty) source.group,
      if (!supported) '核心规则需要脚本，无法执行',
      if (supported && source.degradesScriptFields) '封面/分类等需脚本，已留空',
      if (store.user.any((item) => item.baseUrl == source.baseUrl)) '已导入',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: AppText(
          source.name,
          maxLines: 1,
          style: TextStyle(
            fontSize: 14,
            color: supported ? colors.onSurface : colors.onSurfaceVariant,
          ),
        ),
        subtitle: subtitle.isEmpty
            ? null
            : AppText(
                subtitle,
                maxLines: 1,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (store.user.any((item) => item.baseUrl == source.baseUrl))
              IconButton(
                tooltip: '移除',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => store.removeUserSource(source),
              ),
            Switch(
              value: on,
              onChanged: supported
                  ? (value) => store.setEnabled(source, value)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

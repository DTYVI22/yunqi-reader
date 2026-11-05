import 'package:flutter/material.dart';

/// Picker for the files a device scan found. The public snapshot omits the
/// selection UI; the page reports that scanning is unavailable and returns
/// nothing, which the caller already treats as "user cancelled".
class LocalScanSelection extends StatelessWidget {
  const LocalScanSelection({super.key, required this.snapshot});

  final Object snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('扫描本地书籍')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_off_outlined, size: 44, color: colors.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                '此源码构建未包含本地扫描',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '可通过「导入书籍」选择文件导入。',
                style: TextStyle(fontSize: 13, height: 1.6, color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

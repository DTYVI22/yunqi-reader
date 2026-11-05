import 'package:flutter/material.dart';

import 'book_documents.dart';
import 'local_book_scanner.dart';

/// Status page for a device scan. The public snapshot omits the scanner UI, so
/// this page keeps the entry-point contract and explains the missing feature.
class LocalScanPage extends StatelessWidget {
  const LocalScanPage({
    super.key,
    required this.documents,
    this.changes,
    this.isBusy,
    this.progress,
    this.result,
    this.failure,
    this.onScan,
  });

  final BookDocuments documents;
  final Object? changes;
  final bool Function()? isBusy;
  final Object? Function()? progress;
  final LocalScanResult? Function()? result;
  final String? Function()? failure;
  final Future<void> Function(BuildContext page)? onScan;

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
              Icon(Icons.manage_search, size: 44, color: colors.onSurfaceVariant),
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
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'catalog.dart';
import 'library_state.dart';

/// Reading report page. The public snapshot omits the report renderer, so this
/// page keeps the navigation contract and explains the missing feature.
class ReadingReportPage extends StatelessWidget {
  const ReadingReportPage({
    super.key,
    required this.state,
    required this.repository,
    this.now,
    this.initialRange,
  });

  final LibraryState state;
  final NovelRepository repository;
  final DateTime? now;
  final Object? initialRange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('阅读报告')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_outlined, size: 44, color: colors.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                '此源码构建未包含阅读报告',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '阅读统计页的图表与摘录仍可使用。',
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

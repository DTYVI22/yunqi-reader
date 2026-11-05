import 'book_documents.dart';
import 'local_import_batch.dart';

/// Result of a device scan: what was found, what stayed unchanged, and which
/// warnings the scan could not resolve on its own.
class LocalScanResult {
  const LocalScanResult({
    required this.report,
    required this.total,
    required this.unchanged,
    this.warnings = const [],
    this.pending = 0,
  });

  final LocalImportReport report;
  final int total;
  final int unchanged;
  final List<String> warnings;
  final int pending;

  int get skipped => warnings.length;

  String get summary {
    final parts = <String>[
      if (total > 0) '扫描到 $total 个文件',
      if (report.imported > 0) '导入 ${report.imported} 本',
      if (unchanged > 0) '未变化 $unchanged 个',
      if (report.failures.isNotEmpty) '失败 ${report.failures.length} 本',
      if (warnings.isNotEmpty) '${warnings.length} 个需要注意',
    ];
    return parts.isEmpty ? '没有发现可导入的文件' : parts.join(' · ');
  }
}

/// Imports the tokens the user selected from a scan snapshot.
Future<LocalScanResult> scanLocalBooks({
  required BookDocuments documents,
  required Object snapshot,
  required Set<String> selectedTokens,
  required bool linkText,
  required Future<LocalImportReport> Function(BookDocumentSelection source)
  importSource,
  bool Function()? current,
  void Function(int done, int total)? onProgress,
}) async =>
    const LocalScanResult(
      report: LocalImportReport(bookIds: [], added: 0, existing: 0),
      total: 0,
      unchanged: 0,
    );

import 'book_documents.dart';
import 'local_books.dart';

/// A non-fatal notice produced after an import, e.g. a category that could not
/// be saved while the book itself imported fine.
typedef LocalImportNotice = ({String name, String message});

class LocalImportFailure {
  const LocalImportFailure({required this.name, this.message = '导入失败'});

  final String name;
  final String message;
}

/// Outcome of one import run. Shared by the picker, the scanner and the review
/// page, so it stays a plain value object.
class LocalImportReport {
  const LocalImportReport({
    required this.bookIds,
    required this.added,
    required this.existing,
    this.failures = const [],
    this.notices = const [],
  });

  final List<int> bookIds;
  final int added;
  final int existing;
  final List<LocalImportFailure> failures;
  final List<LocalImportNotice> notices;

  int get imported => added + existing;

  bool get hasFailure => failures.isNotEmpty;

  String get summary {
    final parts = <String>[
      if (added > 0) '新增 $added 本',
      if (existing > 0) '已在书架 $existing 本',
      if (failures.isNotEmpty) '失败 ${failures.length} 本',
    ];
    return parts.isEmpty ? '没有新的书籍' : parts.join(' · ');
  }
}

/// A group of imported volumes that looks like one series and can be merged.
class LocalImportGroup {
  const LocalImportGroup({
    required this.seed,
    required this.title,
    this.targetId,
    this.volumes = const [],
  });

  final int seed;
  final String title;
  final int? targetId;
  final List<({int bookId, String title})> volumes;

  bool get needsTarget => targetId == null;
}

/// Series candidates among the imported ids. Local-only heuristic; returns an
/// empty list when the batch has no obvious grouping.
List<LocalImportGroup> localImportGroups(
  LocalBookStore books,
  List<int> bookIds,
) => const [];

/// Imports every prepared selection. The per-file callbacks stay in
/// [LocalBookImporter] because they differ per entry point.
Future<LocalImportReport> importLocalDocuments({
  required List<BookDocumentSelection> selections,
  required BookDocuments documents,
  required LocalBookStore books,
  required Future<Object?> Function(String name, String path) importFile,
  required Future<Object?> Function(BookDocumentSelection selection)
  importSelection,
  bool releaseSources = false,
  void Function(Iterable<BookDocumentSelection> selections)? onCleanupFailed,
  void Function(int done, int total)? onProgress,
  bool Function()? current,
}) async =>
    const LocalImportReport(bookIds: [], added: 0, existing: 0);

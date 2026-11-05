import 'dart:io';
import 'dart:ui' show RootIsolateToken;

/// One converted document produced by the portable (native) converter.
typedef PreparedBookDocument = ({String name, String? path, String? error});

/// Wraps the platform converter that turns MOBI/AZW3/PDF into readable text.
/// The public snapshot omits the converter itself; the boundary is kept so the
/// import pipeline keeps its contract and reports conversion as unavailable.
class PortableBookPreparer {
  PortableBookPreparer({
    required this.directory,
    required this.textCodecToken,
    required this.decodeNames,
    required this.convert,
    required this.extractKindle,
    this.extractPdf,
  });

  final Directory directory;
  final RootIsolateToken textCodecToken;
  final Future<List<String>> Function(List<String> names) decodeNames;
  final Future<List<PreparedBookDocument>> Function(String name, String path)
  convert;
  final Future<int> Function(String source, String output) extractKindle;
  final Future<void> Function(String name, String source, String output)?
  extractPdf;

  Future<void> releasePaths(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // A staged copy that is already gone must not fail the batch.
      }
    }
  }

  Future<List<PreparedBookDocument>> prepare(String name, String path) =>
      convert(name, path);

  static Future<void> clearPreviousRuns(Directory directory) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // A leftover temporary file must not block a new import.
      }
    }
  }
}

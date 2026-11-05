import 'package:flutter/material.dart';

import 'library_state.dart';
import 'local_books.dart';

/// Batch maintenance entry for local books. The public snapshot omits the real
/// batch editor; this reports the state without changing any book.
Future<void> openLocalBookBatch(
  BuildContext context, {
  required LocalBookStore books,
  required LibraryState library,
  Set<int>? selected,
}) async {
  final colors = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('批量整理'),
      content: Text(
        '此源码构建未包含本地书批量整理，可逐本使用书籍菜单操作。',
        style: TextStyle(fontSize: 14, height: 1.6, color: colors.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).maybePop(),
          child: const Text('好'),
        ),
      ],
    ),
  );
}

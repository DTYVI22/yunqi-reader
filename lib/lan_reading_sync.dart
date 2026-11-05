import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'library_state.dart';
import 'local_books.dart';

/// A nearby-reading invitation sent by another device. The public snapshot
/// omits the LAN transport, so this type carries only what the UI contract
/// needs: an identity and the optional online handoff marker.
class LanHandoffReceipt {
  const LanHandoffReceipt({this.online, this.deviceName = ''});

  final Object? online;
  final String deviceName;
}

/// A resolved handoff: which book to open and where to resume.
class LanHandoffReading {
  const LanHandoffReading({required this.book, required this.position});

  final Novel book;
  final ReadingPosition position;
}

class LanHandoff {
  LanHandoff();

  LanHandoffReceipt? _received;

  LanHandoffReceipt? get received => _received;

  Future<LanHandoffReading> resolveReceipt(LanHandoffReceipt receipt) async {
    throw const FormatException('此源码构建未包含局域网续读接收端');
  }

  void dismissReceipt() {
    _received = null;
  }
}

class LanReadingSync extends ChangeNotifier {
  LanReadingSync({
    required this.state,
    required this.preferences,
    this.books,
    required this.repository,
  });

  final LibraryState state;
  final SharedPreferences preferences;
  final LocalBookStore? books;
  final NovelRepository repository;

  final LanHandoff handoff = LanHandoff();

  /// The public snapshot omits the discovery/broadcast transport.
  bool get available => false;

  Future<void> initialize() async {}

  @override
  void dispose() {
    super.dispose();
  }
}

class LanSyncScope extends InheritedWidget {
  const LanSyncScope({super.key, required this.sync, required super.child});

  final LanReadingSync? sync;

  static LanReadingSync? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanSyncScope>()?.sync;

  @override
  bool updateShouldNotify(LanSyncScope oldWidget) => sync != oldWidget.sync;
}

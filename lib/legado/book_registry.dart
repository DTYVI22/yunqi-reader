/// 书源书籍与 int id 之间的映射。
///
/// 项目的 [Novel.id] 与 [NovelChapter.id] 都是 int，而 legado 用 URL 标识书与
/// 章节。这里维护一张持久表：第一次见到某个 (书源, 书籍 URL) 时分配递增 id，
/// 之后的 find/chapters/chapterContent 都靠它找回原始地址。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// legado 书源占用的 id 区间。
///
/// 必须落在 `book_identity.dart` 的 `localBookIdStart`（0x60000000）**之前**：
/// 项目用 `isLocalBook(id) => id >= localBookIdStart` 判断"这是本地文件"，书源
/// 的书必须是 false 才会走在线取书路径，否则会被当成缺失的本地文件。
const legadoBookIdStart = 0x10000000;

/// 单本书在某个书源里的定位信息。
class LegadoBookRef {
  const LegadoBookRef({
    required this.id,
    required this.sourceUrl,
    required this.bookUrl,
    required this.title,
    this.tocUrl,
  });

  final int id;
  final String sourceUrl;
  final String bookUrl;
  final String title;

  /// 详情页解析出的目录地址，命中后缓存，避免每次重新进详情页。
  final String? tocUrl;

  LegadoBookRef copyWith({String? title, String? tocUrl}) => LegadoBookRef(
    id: id,
    sourceUrl: sourceUrl,
    bookUrl: bookUrl,
    title: title ?? this.title,
    tocUrl: tocUrl ?? this.tocUrl,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'source': sourceUrl,
    'book': bookUrl,
    'title': title,
    if (tocUrl != null) 'toc': tocUrl,
  };

  static LegadoBookRef? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final source = json['source'];
    final book = json['book'];
    if (id is! int || source is! String || book is! String) return null;
    return LegadoBookRef(
      id: id,
      sourceUrl: source,
      bookUrl: book,
      title: json['title'] is String ? json['title'] as String : '',
      tocUrl: json['toc'] is String ? json['toc'] as String : null,
    );
  }
}

/// 章节 id 与章节地址的映射，按书籍分组存。
class LegadoChapterRef {
  const LegadoChapterRef({
    required this.id,
    required this.url,
    required this.title,
  });

  final int id;
  final String url;
  final String title;

  Map<String, Object?> toJson() => {'id': id, 'url': url, 'title': title};

  static LegadoChapterRef? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final url = json['url'];
    if (id is! int || url is! String) return null;
    return LegadoChapterRef(
      id: id,
      url: url,
      title: json['title'] is String ? json['title'] as String : '',
    );
  }
}

class LegadoBookRegistry {
  LegadoBookRegistry({this.preferences});

  /// 为空时退化成纯内存表，进程重启后重新分配 id。
  final SharedPreferences? preferences;

  static const _booksKey = 'legado.books.v1';
  static const _chaptersKey = 'legado.chapters.v1';

  final Map<int, LegadoBookRef> _byId = {};
  final Map<String, int> _idByKey = {};
  final Map<int, List<LegadoChapterRef>> _chapters = {};
  final Map<String, int> _chapterIdByKey = {};

  int _nextBookId = legadoBookIdStart + 1;
  int _nextChapterId = 1;

  bool _loaded = false;

  static String _keyOf(String sourceUrl, String bookUrl) =>
      '$sourceUrl\u0000$bookUrl';

  static String _chapterKeyOf(int bookId, String chapterUrl) =>
      '$bookId\u0000$chapterUrl';

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final store = preferences;
    if (store == null) return;

    final rawBooks = store.getString(_booksKey);
    if (rawBooks != null) {
      try {
        for (final item in jsonDecode(rawBooks) as List<dynamic>) {
          if (item is! Map) continue;
          final ref = LegadoBookRef.fromJson(Map<String, dynamic>.from(item));
          if (ref == null) continue;
          _byId[ref.id] = ref;
          _idByKey[_keyOf(ref.sourceUrl, ref.bookUrl)] = ref.id;
          if (ref.id >= _nextBookId) _nextBookId = ref.id + 1;
        }
      } catch (_) {
        // 损坏的映射表只影响历史书签，不能挡住新搜索。
      }
    }

    final rawChapters = store.getString(_chaptersKey);
    if (rawChapters != null) {
      try {
        final decoded = jsonDecode(rawChapters) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          final bookId = int.tryParse(key);
          if (bookId == null || value is! List) return;
          final refs = <LegadoChapterRef>[];
          for (final item in value) {
            if (item is! Map) continue;
            final ref = LegadoChapterRef.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (ref == null) continue;
            refs.add(ref);
            _chapterIdByKey[_chapterKeyOf(bookId, ref.url)] = ref.id;
            if (ref.id >= _nextChapterId) _nextChapterId = ref.id + 1;
          }
          _chapters[bookId] = refs;
        });
      } catch (_) {
        // 同上：章节映射丢失只会导致重新抓一次目录。
      }
    }
  }

  Future<int> idFor(
    String sourceUrl,
    String bookUrl, {
    String title = '',
  }) async {
    await load();
    final key = _keyOf(sourceUrl, bookUrl);
    final existing = _idByKey[key];
    if (existing != null) {
      final ref = _byId[existing]!;
      if (title.isNotEmpty && ref.title != title) {
        _byId[existing] = ref.copyWith(title: title);
        await _persistBooks();
      }
      return existing;
    }
    final id = _nextBookId++;
    final ref = LegadoBookRef(
      id: id,
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      title: title,
    );
    _byId[id] = ref;
    _idByKey[key] = id;
    await _persistBooks();
    return id;
  }

  LegadoBookRef? lookup(int id) => _byId[id];

  Future<void> cacheTocUrl(int bookId, String tocUrl) async {
    final ref = _byId[bookId];
    if (ref == null || ref.tocUrl == tocUrl) return;
    _byId[bookId] = ref.copyWith(tocUrl: tocUrl);
    await _persistBooks();
  }

  /// 把一章登记成稳定 id；已存在时保留原 id。
  Future<int> chapterIdFor(int bookId, String chapterUrl) async {
    final key = _chapterKeyOf(bookId, chapterUrl);
    final existing = _chapterIdByKey[key];
    if (existing != null) return existing;
    final id = _nextChapterId++;
    _chapterIdByKey[key] = id;
    return id;
  }

  String? chapterUrlFor(int bookId, int chapterId) {
    for (final ref in _chapters[bookId] ?? const <LegadoChapterRef>[]) {
      if (ref.id == chapterId) return ref.url;
    }
    return null;
  }

  /// 目录刷新后整体替换，保持标题与地址同步。
  Future<void> replaceChapters(int bookId, List<LegadoChapterRef> refs) async {
    _chapters[bookId] = refs;
    for (final ref in refs) {
      _chapterIdByKey[_chapterKeyOf(bookId, ref.url)] = ref.id;
      if (ref.id >= _nextChapterId) _nextChapterId = ref.id + 1;
    }
    await _persistChapters();
  }

  List<LegadoChapterRef> chaptersOf(int bookId) =>
      _chapters[bookId] ?? const [];

  Future<void> _persistBooks() async {
    final store = preferences;
    if (store == null) return;
    final payload = [for (final ref in _byId.values) ref.toJson()];
    await store.setString(_booksKey, jsonEncode(payload));
  }

  Future<void> _persistChapters() async {
    final store = preferences;
    if (store == null) return;
    final payload = <String, Object?>{
      for (final entry in _chapters.entries)
        '${entry.key}': [for (final ref in entry.value) ref.toJson()],
    };
    await store.setString(_chaptersKey, jsonEncode(payload));
  }
}

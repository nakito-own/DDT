import 'package:flutter/widgets.dart';

import 'notes_api.dart';

enum NoteKindFilter {
  all('Все'),
  notes('Заметки'),
  folders('Папки');

  const NoteKindFilter(this.label);

  final String label;
}

enum NoteDateFilter {
  any('Все даты'),
  today('Сегодня'),
  week('Последние 7 дней'),
  month('Последние 30 дней');

  const NoteDateFilter(this.label);

  final String label;
}

enum NoteSort {
  createdDesc('Сначала новые'),
  createdAsc('Сначала старые'),
  title('По названию'),
  updatedDesc('По изменению');

  const NoteSort(this.label);

  final String label;
}

class NotesController extends ChangeNotifier {
  NotesController({NotesApi? api}) : _api = api ?? notesApi {
    _pending = _load();
  }

  final NotesApi _api;

  final List<NoteItem> _items = [];
  Map<String, NoteItem> _index = {};
  Future<void>? _pending;
  var _loadEpoch = 0;
  var _loaded = false;
  var _loading = true;
  var _disposed = false;
  String? _error;
  String? _browsingFolderId;
  String _query = '';
  String _author = '';
  NoteKindFilter _kind = NoteKindFilter.all;
  NoteDateFilter _date = NoteDateFilter.any;
  NoteSort _sort = NoteSort.createdDesc;

  List<NoteItem> get items => _items;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  String? get browsingFolderId => _browsingFolderId;
  String get query => _query;
  String get author => _author;
  NoteKindFilter get kind => _kind;
  NoteDateFilter get date => _date;
  NoteSort get sort => _sort;

  List<String> get authors {
    final names = {for (final item in _items) item.authorLabel};
    final sorted = names.toList()..sort();
    return sorted;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await (_pending ??= _load());
    if (!_loaded) {
      throw NotesApiException(_error ?? 'Не удалось загрузить заметки');
    }
  }

  Future<void> retry() async {
    _loaded = false;
    _loading = true;
    _pending = null;
    if (!_disposed) notifyListeners();
    await (_pending ??= _load());
  }

  Future<NoteItem> fetch(String id) => _api.get(id);

  Future<NoteItem> create({
    required String title,
    required NoteKind kind,
    String? parentId,
  }) async {
    await ensureLoaded();
    final created = await _api.create(
      title: title,
      kind: kind,
      parentId: parentId,
    );
    if (!_disposed) apply(created);
    return created;
  }

  Future<void> rename(String id, String title) async {
    await ensureLoaded();
    final saved = await _api.update(id, title: title);
    if (!_disposed) apply(saved);
  }

  Future<void> move(String id, String? parentId) async {
    await ensureLoaded();
    final saved = await _api.update(id, parentId: parentId, parentSet: true);
    if (!_disposed) apply(saved);
  }

  Future<void> save(
    String id, {
    required String title,
    required String body,
  }) async {
    try {
      await ensureLoaded();
    } catch (error) {
      if (!_disposed) rethrow;
    }
    final saved = await _api.update(id, title: title, body: body);
    if (!_disposed) apply(saved);
  }

  Future<void> delete(String id) async {
    await ensureLoaded();
    await _api.delete(id);
    if (_disposed) return;
    _removeTree(id);
  }

  void apply(NoteItem item) {
    if (_disposed) return;
    final next = [..._items];
    final index = next.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    _setItems(next);
    _error = null;
    notifyListeners();
  }

  void setBrowsingFolder(String? folderId) {
    final next = folderId == null || folderId.isEmpty ? null : folderId;
    if (next == _browsingFolderId) return;
    _browsingFolderId = next;
    if (!_disposed) notifyListeners();
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    if (!_disposed) notifyListeners();
  }

  void setAuthor(String value) {
    if (value == _author) return;
    _author = value;
    if (!_disposed) notifyListeners();
  }

  void setKind(NoteKindFilter value) {
    if (value == _kind) return;
    _kind = value;
    if (!_disposed) notifyListeners();
  }

  void setDate(NoteDateFilter value) {
    if (value == _date) return;
    _date = value;
    if (!_disposed) notifyListeners();
  }

  void setSort(NoteSort value) {
    if (value == _sort) return;
    _sort = value;
    if (!_disposed) notifyListeners();
  }

  String? existingFolder(String? folderId) {
    if (folderId == null || folderId.isEmpty) return null;
    final folder = _index[folderId];
    if (folder == null || !folder.isFolder) return null;
    return folderId;
  }

  NoteItem? byId(String id) => _index[id];

  int childCount(String id) {
    var count = 0;
    for (final item in _items) {
      if (item.parentId == id) count++;
    }
    return count;
  }

  int descendantCount(String id) {
    final drop = <String>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final item in _items) {
        final parent = item.parentId;
        if (parent != null && drop.contains(parent) && drop.add(item.id)) {
          changed = true;
        }
      }
    }
    return drop.length - 1;
  }

  List<NoteItem> breadcrumbs(String? folderId) {
    final start = existingFolder(folderId);
    if (start == null) return const [];
    final chain = <NoteItem>[];
    final seen = <String>{};
    NoteItem? current = _index[start];
    while (current != null && seen.add(current.id)) {
      chain.add(current);
      final parentId = current.parentId;
      current = parentId == null ? null : _index[parentId];
    }
    return chain.reversed.toList();
  }

  String pathLabel(String? folderId) {
    return breadcrumbs(folderId).map((item) => item.title).join(' / ');
  }

  int depthOf(String id) {
    var depth = 0;
    final seen = <String>{};
    var current = _index[id]?.parentId;
    while (current != null && seen.add(current)) {
      depth++;
      current = _index[current]?.parentId;
    }
    return depth;
  }

  List<NoteItem> get folders {
    final list = [
      for (final item in _items)
        if (item.isFolder) item,
    ];
    list.sort(
      (a, b) => pathLabel(
        a.id,
      ).toLowerCase().compareTo(pathLabel(b.id).toLowerCase()),
    );
    return list;
  }

  bool get filtersActive =>
      _query.trim().isNotEmpty ||
      _author.isNotEmpty ||
      _kind != NoteKindFilter.all ||
      _date != NoteDateFilter.any;

  int get matchCount {
    if (!filtersActive) return _items.length;
    var count = 0;
    for (final item in _items) {
      if (_nodeMatches(item)) count++;
    }
    return count;
  }

  Set<String> foldersHoldingMatches() {
    if (!filtersActive) return const {};
    final ids = <String>{};
    for (final item in _items) {
      if (!_nodeMatches(item)) continue;
      final seen = <String>{};
      var current = item.parentId;
      while (current != null && seen.add(current)) {
        ids.add(current);
        current = _index[current]?.parentId;
      }
    }
    return ids;
  }

  List<NoteItem> childrenOf(String? parentId) {
    final holders = foldersHoldingMatches();
    final filtering = filtersActive;
    final result = [
      for (final item in _items)
        if (item.parentId == parentId &&
            (!filtering ||
                _nodeMatches(item) ||
                (item.isFolder && holders.contains(item.id))))
          item,
    ];
    _sortItems(result);
    return result;
  }

  bool canPlace(NoteItem item, String? parentId) {
    if (parentId != null && existingFolder(parentId) == null) return false;
    if (parentId == item.id) return false;
    if (item.isFolder && parentId != null && _contains(item.id, parentId)) {
      return false;
    }
    return true;
  }

  void _sortItems(List<NoteItem> result) {
    result.sort((a, b) {
      final byKind = (a.isFolder ? 0 : 1).compareTo(b.isFolder ? 0 : 1);
      if (byKind != 0) return byKind;
      return switch (_sort) {
        NoteSort.createdDesc => b.createdAt.compareTo(a.createdAt),
        NoteSort.createdAsc => a.createdAt.compareTo(b.createdAt),
        NoteSort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        NoteSort.updatedDesc => b.updatedAt.compareTo(a.updatedAt),
      };
    });
  }

  bool _nodeMatches(NoteItem item) {
    final query = _query.trim().toLowerCase();
    if (_kind == NoteKindFilter.notes && item.isFolder) return false;
    if (_kind == NoteKindFilter.folders && !item.isFolder) return false;
    if (_author.isNotEmpty && item.authorLabel != _author) return false;
    if (query.isNotEmpty &&
        !'${item.title} ${item.preview}'.toLowerCase().contains(query)) {
      return false;
    }
    return _matchesCreated(item.createdAt.toLocal(), DateTime.now());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    List<NoteItem>? list;
    Object? failure;
    try {
      list = await _api.list();
    } catch (error) {
      failure = error;
    }
    if (_disposed || epoch != _loadEpoch) return;
    if (list != null) {
      _setItems(list);
      _error = null;
      _loaded = true;
    } else {
      final error = failure;
      _error = error is NotesApiException
          ? error.message
          : 'Не удалось загрузить заметки';
      _loaded = false;
    }
    _pending = null;
    _loading = false;
    notifyListeners();
  }

  void _setItems(List<NoteItem> items) {
    _items
      ..clear()
      ..addAll(items);
    _index = {for (final item in _items) item.id: item};
  }

  void _removeTree(String id) {
    final drop = <String>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final item in _items) {
        final parent = item.parentId;
        if (parent != null && drop.contains(parent) && drop.add(item.id)) {
          changed = true;
        }
      }
    }
    _setItems([
      for (final item in _items)
        if (!drop.contains(item.id)) item,
    ]);
    notifyListeners();
  }

  bool _contains(String ancestorId, String nodeId) {
    final seen = <String>{};
    var current = _index[nodeId]?.parentId;
    while (current != null && seen.add(current)) {
      if (current == ancestorId) return true;
      current = _index[current]?.parentId;
    }
    return false;
  }

  bool _matchesCreated(DateTime created, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    return switch (_date) {
      NoteDateFilter.any => true,
      NoteDateFilter.today => !created.isBefore(startOfToday),
      NoteDateFilter.week => !created.isBefore(
        startOfToday.subtract(const Duration(days: 6)),
      ),
      NoteDateFilter.month => !created.isBefore(
        startOfToday.subtract(const Duration(days: 29)),
      ),
    };
  }
}

abstract final class NotesCommands {
  static NotesController? _current;

  static NotesController? get current => _current;

  static void attach(NotesController controller) => _current = controller;

  static void detach(NotesController controller) {
    if (identical(_current, controller)) _current = null;
  }
}

class NotesScope extends InheritedNotifier<NotesController> {
  const NotesScope({
    super.key,
    required NotesController controller,
    required super.child,
  }) : super(notifier: controller);

  static NotesController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<NotesScope>();
    final scope = element?.widget as NotesScope?;
    assert(scope != null, 'NotesScope not found');
    return scope!.notifier!;
  }
}

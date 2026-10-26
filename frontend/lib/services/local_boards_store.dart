import 'package:get_storage/get_storage.dart';

/// Локальная доска. Диаграмма хранится в формате проекта nodeline.
class DiagramBoard {
  const DiagramBoard({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.author = '',
    this.project,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String author;
  final Map<String, dynamic>? project;

  String get authorLabel => author.trim().isEmpty ? 'Не указан' : author.trim();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (author.isNotEmpty) 'author': author,
    if (project != null) 'project': project,
  };

  factory DiagramBoard.fromJson(Map<String, dynamic> json) {
    final project = _asStringMap(json['project']);
    final updatedAt =
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now();
    return DiagramBoard(
      id: json['id'] as String,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Доска',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? updatedAt,
      updatedAt: updatedAt,
      author: json['author'] as String? ?? '',
      project: project,
    );
  }
}

Map<String, dynamic>? _asStringMap(Object? value) {
  final normalized = _normalize(value);
  if (normalized is Map<String, dynamic>) return normalized;
  return null;
}

Object? _normalize(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _normalize(entry.value),
    };
  }
  if (value is List) {
    return <Object?>[for (final item in value) _normalize(item)];
  }
  return value;
}

/// Хранит доски в GetStorage, пока нет серверного API.
class LocalBoardsStore {
  LocalBoardsStore();

  static final instance = LocalBoardsStore();

  static const _boxName = 'ddt_boards';
  static const _key = 'boards';

  GetStorage? _box;
  Future<void>? _opening;

  Future<void> prepare() {
    return _opening ??= _open();
  }

  Future<void> _open() async {
    await GetStorage.init(_boxName);
    _box = GetStorage(_boxName);
  }

  GetStorage get _storage {
    final box = _box;
    if (box == null) {
      throw StateError('LocalBoardsStore.prepare() was not called');
    }
    return box;
  }

  List<DiagramBoard> list() {
    final boards = _read();
    boards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return boards;
  }

  DiagramBoard? find(String id) {
    for (final board in _read()) {
      if (board.id == id) return board;
    }
    return null;
  }

  Future<DiagramBoard> create({String? title, String author = ''}) async {
    final boards = _read();
    final name = title?.trim();
    final now = DateTime.now();
    final board = DiagramBoard(
      id: 'board-${now.microsecondsSinceEpoch}',
      title: name == null || name.isEmpty ? 'Доска ${boards.length + 1}' : name,
      createdAt: now,
      updatedAt: now,
      author: author.trim(),
    );
    boards.add(board);
    await _write(boards);
    return board;
  }

  Future<void> rename(String id, String title) async {
    final name = title.trim();
    if (name.isEmpty) return;
    final boards = _read();
    final index = boards.indexWhere((board) => board.id == id);
    if (index < 0) return;
    final current = boards[index];
    boards[index] = DiagramBoard(
      id: current.id,
      title: name,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      author: current.author,
      project: current.project,
    );
    await _write(boards);
  }

  Future<void> delete(String id) async {
    final boards = _read()..removeWhere((board) => board.id == id);
    await _write(boards);
  }

  Future<void> saveProject(String id, Map<String, dynamic> project) async {
    final boards = _read();
    final index = boards.indexWhere((board) => board.id == id);
    if (index < 0) return;
    final current = boards[index];
    boards[index] = DiagramBoard(
      id: current.id,
      title: current.title,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      author: current.author,
      project: project,
    );
    await _write(boards);
  }

  List<DiagramBoard> _read() {
    final raw = _storage.read(_key);
    if (raw is! List) return [];
    final boards = <DiagramBoard>[];
    for (final item in raw) {
      final json = _asStringMap(item);
      if (json == null || json['id'] is! String) continue;
      boards.add(DiagramBoard.fromJson(json));
    }
    return boards;
  }

  Future<void> _write(List<DiagramBoard> boards) {
    return _storage.write(_key, boards.map((board) => board.toJson()).toList());
  }
}

import 'boards_api.dart';

export 'boards_api.dart' show BoardsApiException, DiagramBoard;

/// Облачное хранилище досок. Список общий для всех вошедших пользователей.
class BoardsStore {
  BoardsStore({BoardsApi? api}) : _api = api ?? boardsApi;

  static final instance = BoardsStore();

  final BoardsApi _api;

  Future<List<DiagramBoard>> list() => _api.list();

  Future<DiagramBoard?> find(String id) => _api.find(id);

  Future<DiagramBoard> create({required String title}) => _api.create(title);

  Future<void> rename(String id, String title) => _api.rename(id, title);

  Future<void> delete(String id) => _api.delete(id);

  Future<void> saveProject(String id, Map<String, dynamic> project) =>
      _api.saveProject(id, project);
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

enum NoteKind { folder, note }

class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.preview = '',
    this.body = '',
    this.author = '',
  });

  final String id;
  final String? parentId;
  final NoteKind kind;
  final String title;
  final String preview;
  final String body;
  final String author;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFolder => kind == NoteKind.folder;

  String get authorLabel => author.trim().isEmpty ? 'Не указан' : author.trim();

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    final updatedAt =
        DateTime.tryParse('${json['updated_at'] ?? json['updatedAt']}') ??
        DateTime.now();
    final title = (json['title'] as String?)?.trim();
    final parent = json['parent_id'] ?? json['parentId'];
    return NoteItem(
      id: '${json['id']}',
      parentId: parent == null || '$parent'.isEmpty ? null : '$parent',
      kind: json['kind'] == 'folder' ? NoteKind.folder : NoteKind.note,
      title: title == null || title.isEmpty ? 'Без названия' : title,
      preview: '${json['preview'] ?? ''}',
      body: json['body'] is String ? json['body'] as String : '',
      author: '${json['author_name'] ?? json['author'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? json['createdAt']}') ??
          updatedAt,
      updatedAt: updatedAt,
    );
  }
}

class NotesApiException implements Exception {
  NotesApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotesApi {
  NotesApi({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<List<NoteItem>> list() async {
    final response = await _client.get('/api/notes');
    _ensure(response, 'Не удалось загрузить заметки');
    return ApiClient.decodeList(response).map(NoteItem.fromJson).toList();
  }

  Future<NoteItem> get(String id) async {
    final response = await _client.get('/api/notes/$id');
    if (response.statusCode == 404) {
      throw NotesApiException('Заметка не найдена');
    }
    _ensure(response, 'Не удалось открыть заметку');
    return NoteItem.fromJson(ApiClient.decodeMap(response));
  }

  Future<NoteItem> create({
    required String title,
    required NoteKind kind,
    String? parentId,
  }) async {
    final response = await _client.post(
      '/api/notes',
      body: {
        'title': title,
        'kind': kind == NoteKind.folder ? 'folder' : 'note',
        if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
      },
    );
    _ensure(response, 'Не удалось создать');
    return NoteItem.fromJson(ApiClient.decodeMap(response));
  }

  Future<NoteItem> update(
    String id, {
    String? title,
    String? body,
    String? parentId,
    bool parentSet = false,
  }) async {
    final payload = <String, dynamic>{
      'title': ?title,
      'body': ?body,
      if (parentSet) 'parent_id': parentId,
    };
    final response = await _client.patch('/api/notes/$id', body: payload);
    _ensure(response, 'Не удалось сохранить заметку');
    return NoteItem.fromJson(ApiClient.decodeMap(response));
  }

  Future<void> delete(String id) async {
    final response = await _client.delete('/api/notes/$id');
    if (response.statusCode == 404) {
      throw NotesApiException('Заметка не найдена');
    }
    _ensure(response, 'Не удалось удалить');
  }

  void _ensure(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw NotesApiException(_detail(response) ?? fallback);
  }

  String? _detail(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
    } catch (_) {}
    return null;
  }
}

final notesApi = NotesApi();

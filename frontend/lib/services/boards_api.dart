import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Доска в облаке. Диаграмма хранится JSON-проектом nodeline.
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

  factory DiagramBoard.fromJson(Map<String, dynamic> json) {
    final updatedAt =
        DateTime.tryParse('${json['updated_at'] ?? json['updatedAt']}') ??
        DateTime.now();
    final title = (json['title'] as String?)?.trim();
    return DiagramBoard(
      id: '${json['id']}',
      title: title == null || title.isEmpty ? 'Доска' : title,
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? json['createdAt']}') ??
          updatedAt,
      updatedAt: updatedAt,
      author: '${json['author_name'] ?? json['author'] ?? ''}',
      project: _asStringMap(json['project']),
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

class BoardsApiException implements Exception {
  BoardsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BoardsApi {
  BoardsApi({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<List<DiagramBoard>> list() async {
    final response = await _client.get('/api/boards');
    _ensure(response, 'Не удалось загрузить доски');
    return ApiClient.decodeList(response).map(DiagramBoard.fromJson).toList();
  }

  Future<DiagramBoard?> find(String id) async {
    final response = await _client.get('/api/boards/$id');
    if (response.statusCode == 404) return null;
    _ensure(response, 'Не удалось открыть доску');
    return DiagramBoard.fromJson(ApiClient.decodeMap(response));
  }

  Future<DiagramBoard> create(String title) async {
    final response = await _client.post(
      '/api/boards',
      body: {'title': title},
    );
    _ensure(response, 'Не удалось создать доску');
    return DiagramBoard.fromJson(ApiClient.decodeMap(response));
  }

  Future<void> rename(String id, String title) async {
    final response = await _client.patch(
      '/api/boards/$id',
      body: {'title': title},
    );
    _ensure(response, 'Не удалось переименовать доску');
  }

  Future<void> saveProject(String id, Map<String, dynamic> project) async {
    final response = await _client.patch(
      '/api/boards/$id',
      body: {'project': project},
    );
    _ensure(response, 'Не удалось сохранить доску');
  }

  Future<void> delete(String id) async {
    final response = await _client.delete('/api/boards/$id');
    _ensure(response, 'Не удалось удалить доску');
  }

  void _ensure(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw BoardsApiException(_detail(response) ?? fallback);
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

final boardsApi = BoardsApi();

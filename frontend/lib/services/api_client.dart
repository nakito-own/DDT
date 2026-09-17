import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session_token_storage.dart';

const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: '',
);

class ApiClient {
  ApiClient({SessionTokenStorage? storage})
    : _storage = storage ?? sessionTokenStorage;

  static const defaultTimeout = Duration(seconds: 90);
  static const loginTimeout = Duration(minutes: 2);

  final SessionTokenStorage _storage;
  void Function()? onUnauthorized;
  bool _suppressUnauthorized = false;

  /// Во время restore/me 401 не должен выбрасывать пользователя на логин.
  Future<T> runSilentlyUnauthorized<T>(Future<T> Function() action) async {
    _suppressUnauthorized = true;
    try {
      return await action();
    } finally {
      _suppressUnauthorized = false;
    }
  }

  Future<String?> getSessionToken() => _storage.read();

  Future<void> setSessionToken(String token) => _storage.write(token);

  Future<void> clearSessionToken() => _storage.delete();

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getSessionToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$apiUrl$path').replace(queryParameters: query);
    final response = await http
        .get(uri, headers: await _headers(auth: auth))
        .timeout(timeout ?? defaultTimeout);
    if (auth) {
      _handleUnauthorized(response);
    }
    return response;
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$apiUrl$path').replace(queryParameters: query);
    final response = await http
        .post(
          uri,
          headers: await _headers(auth: auth),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(timeout ?? defaultTimeout);
    if (auth) {
      _handleUnauthorized(response);
    }
    return response;
  }

  Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$apiUrl$path');
    final response = await http.put(
      uri,
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    if (auth) {
      _handleUnauthorized(response);
    }
    return response;
  }

  Future<http.Response> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$apiUrl$path');
    final response = await http.patch(
      uri,
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    if (auth) {
      _handleUnauthorized(response);
    }
    return response;
  }

  Future<http.Response> delete(String path, {bool auth = true}) async {
    final uri = Uri.parse('$apiUrl$path');
    final response = await http.delete(
      uri,
      headers: await _headers(auth: auth),
    );
    if (auth) {
      _handleUnauthorized(response);
    }
    return response;
  }

  void _handleUnauthorized(http.Response response) {
    if (_suppressUnauthorized) {
      return;
    }
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
  }

  static Map<String, dynamic> decodeMap(http.Response response) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static List<Map<String, dynamic>> decodeList(http.Response response) {
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }
}

final apiClient = ApiClient();

Future<Map<String, dynamic>> fetchHealth() async {
  final response = await apiClient.get('/api/health', auth: false);
  if (response.statusCode != 200) {
    throw Exception('Health check failed');
  }
  return ApiClient.decodeMap(response);
}

Future<List<Map<String, dynamic>>> fetchUsers() async {
  final response = await apiClient.get('/api/users');
  if (response.statusCode != 200) {
    throw Exception('Failed to load users');
  }
  return ApiClient.decodeList(response);
}

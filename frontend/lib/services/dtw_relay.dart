import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One DTW page split into raw row JSON, without building row objects.
class DtwRawPage {
  const DtwRawPage({required this.totalCount, required this.rows});

  final int totalCount;
  final List<String> rows;
}

/// Cuts `data` objects out of a DTW page. A string scan stays off the object
/// graph, so a thousand geometry rows do not freeze the UI.
DtwRawPage splitDtwPage(String raw) {
  final totalMatch = RegExp(r'"totalCount"\s*:\s*(\d+)').firstMatch(raw);
  final total = int.tryParse(totalMatch?.group(1) ?? '') ?? 0;
  final dataKey = RegExp(r'"data"\s*:\s*\[').firstMatch(raw);
  if (dataKey == null) {
    throw Exception('Ответ набора DTW не содержит список data.');
  }
  var index = dataKey.end;
  final rows = <String>[];
  while (index < raw.length) {
    while (index < raw.length && _isSeparator(raw, index)) {
      index++;
    }
    if (index >= raw.length || raw[index] == ']') break;
    if (raw[index] != '{') {
      throw Exception('Ответ набора DTW имеет неожиданный формат.');
    }
    final start = index;
    var depth = 0;
    var inString = false;
    var escape = false;
    for (; index < raw.length; index++) {
      final char = raw[index];
      if (inString) {
        if (escape) {
          escape = false;
          continue;
        }
        if (char == r'\') {
          escape = true;
          continue;
        }
        if (char == '"') inString = false;
        continue;
      }
      if (char == '"') {
        inString = true;
        continue;
      }
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          index++;
          rows.add(raw.substring(start, index));
          break;
        }
      }
    }
    if (depth != 0) {
      throw Exception('Ответ набора DTW имеет неожиданный формат.');
    }
  }
  return DtwRawPage(totalCount: total, rows: rows);
}

bool _isSeparator(String raw, int index) {
  final char = raw[index];
  return char == ' ' ||
      char == '\n' ||
      char == '\r' ||
      char == '\t' ||
      char == ',';
}

/// Pulls dataset pages from DTW in the user's network.
class DtwRelay {
  DtwRelay({
    required String baseUrl,
    required this.login,
    required this.password,
    required this.datasetId,
    required this.pageSize,
    required this.offsetParam,
    required this.limitParam,
    http.Client? client,
  }) : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _client = client ?? http.Client();

  final String baseUrl;
  final String login;
  final String password;
  final int datasetId;
  final int pageSize;
  final String offsetParam;
  final String limitParam;
  final http.Client _client;

  static const _timeout = Duration(seconds: 120);
  static const _maxPages = 1000;

  String? _token;
  DateTime? _deadline;

  static const maxPages = _maxPages;

  /// Raw DTW JSON. The caller forwards it to the API without decoding it.
  Future<String> loadPage(int offset) async {
    final response = await _fetchPage(offset);
    final body = response.body;
    if (!body.trimLeft().startsWith('{')) {
      throw Exception('Ответ набора DTW имеет неожиданный формат.');
    }
    return body;
  }

  void close() => _client.close();

  Future<http.Response> _fetchPage(int offset) async {
    http.Response? response;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final token = await _accessToken();
        response = await _client
            .get(_pageUri(offset), headers: _authorized(token))
            .timeout(_timeout);
      } on TimeoutException {
        if (attempt < 2) continue;
        throw Exception('Истекло время ожидания ответа DTW.');
      } catch (error) {
        if (error is Exception && error is! http.ClientException) rethrow;
        throw Exception('Не удалось получить страницу набора DTW.');
      }
      if (response.statusCode == 401) {
        _token = null;
        _deadline = null;
        continue;
      }
      if (response.statusCode == 504 && attempt < 2) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      break;
    }
    final body = response!;
    if (body.statusCode == 401) {
      throw Exception('DTW отклонил учётные данные.');
    }
    if (body.statusCode >= 400) {
      final detail = body.body.replaceAll(RegExp(r'\s+'), ' ').trim();
      final clipped = detail.length > 240 ? detail.substring(0, 240) : detail;
      throw Exception(
        'DTW вернул ошибку ${body.statusCode} при запросе набора DTW. $clipped'
            .trim(),
      );
    }
    return body;
  }

  Future<String> _accessToken() async {
    final current = _token;
    final deadline = _deadline;
    if (current != null &&
        current.isNotEmpty &&
        deadline != null &&
        DateTime.now().isBefore(deadline)) {
      return current;
    }
    if (login.trim().isEmpty || password.isEmpty) {
      throw Exception('Укажите DTW_LOGIN и DTW_PASSWORD для загрузки набора КРР.');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/app/auth/login'),
    );
    request.fields['login'] = login.trim();
    request.fields['password'] = password;
    request.headers['Accept'] = 'application/json';
    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw Exception('Истекло время ожидания авторизации DTW.');
    } catch (error) {
      if (error is Exception && error is! http.ClientException) rethrow;
      throw Exception('Не удалось выполнить авторизацию в DTW.');
    }
    final payload = _object(response, 'авторизации DTW');
    final token = _findToken(payload);
    if (token == null) {
      throw Exception('Ответ авторизации DTW не содержит accessToken.');
    }
    _token = token;
    _deadline = _tokenDeadline(token, payload);
    return token;
  }

  Uri _pageUri(int offset) {
    return Uri.parse(
      '$baseUrl/app/api/data-output/datasets/GetDataWithRequest/$datasetId',
    ).replace(
      queryParameters: {
        offsetParam: '$offset',
        limitParam: '$pageSize',
      },
    );
  }

  Map<String, String> _authorized(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Map<String, dynamic> _object(http.Response response, String what) {
    if (response.statusCode == 401) {
      throw Exception('DTW отклонил учётные данные.');
    }
    if (response.statusCode >= 400) {
      final detail = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
      final clipped = detail.length > 240 ? detail.substring(0, 240) : detail;
      throw Exception(
        'DTW вернул ошибку ${response.statusCode} при запросе $what. $clipped'
            .trim(),
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Ответ $what имеет неожиданный формат.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  String? _findToken(Map<String, dynamic> payload) {
    for (final key in const ['accessToken', 'access_token', 'token']) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final nested = payload['data'];
    if (nested is Map) {
      return _findToken(
        nested.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  DateTime _tokenDeadline(String token, Map<String, dynamic> payload) {
    final expiresIn = _expiresIn(payload);
    if (expiresIn != null && expiresIn > 0) {
      final seconds = expiresIn > 60 ? expiresIn - 60 : 30;
      return DateTime.now().add(Duration(seconds: seconds));
    }
    final exp = _jwtExp(token);
    if (exp != null) {
      final moment = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return moment.subtract(const Duration(seconds: 60));
    }
    return DateTime.now().add(const Duration(minutes: 20));
  }

  int? _expiresIn(Map<String, dynamic> payload) {
    final direct = _asInt(payload['expiresIn'] ?? payload['expires_in']);
    if (direct != null) return direct;
    final nested = payload['data'];
    if (nested is Map) {
      return _asInt(nested['expiresIn'] ?? nested['expires_in']);
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  int? _jwtExp(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is Map) return _asInt(payload['exp']);
    } catch (_) {
      return null;
    }
    return null;
  }
}

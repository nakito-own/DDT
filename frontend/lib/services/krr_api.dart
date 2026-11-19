import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import '../models/analytics_filters.dart';
import '../models/krr_dashboard.dart';
import 'api_client.dart';
import 'dtw_relay.dart';

class KrrApi {
  KrrApi({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  /// Pulls today's DTW snapshot through this client and uploads it to the API.
  ///
  /// The server cannot reach DTW. A finished snapshot for today is left as-is
  /// unless [force] is set.
  Future<void> syncUntilDone({
    bool force = false,
    void Function(int stored, int total)? onProgress,
  }) async {
    final begin = await _post(
      '/api/krr/sync/begin',
      query: force ? const {'force': 'true'} : null,
    );
    if (begin['needed'] != true) return;

    final syncId = begin['sync_id']?.toString() ?? '';
    if (syncId.isEmpty) {
      throw Exception('Сервер не открыл сессию загрузки КРР.');
    }
    final relay = DtwRelay(
      baseUrl: begin['base_url']?.toString() ?? '',
      login: begin['login']?.toString() ?? '',
      password: begin['password']?.toString() ?? '',
      datasetId: _asInt(begin['dataset_id']),
      pageSize: _asInt(begin['page_size'], fallback: 200),
      offsetParam: _param(begin['offset_param'], 'offset'),
      limitParam: _param(begin['limit_param'], 'limit'),
    );
    try {
      var offset = 0;
      var finished = false;
      for (var page = 0; page < DtwRelay.maxPages; page++) {
        await _yieldFrame();
        final raw = await relay.loadPage(offset);
        await _yieldFrame();
        final progress = await _post(
          '/api/krr/sync/page',
          rawBody:
              '{"sync_id":${jsonEncode(syncId)},"offset":$offset,"payload":$raw}',
          timeout: const Duration(minutes: 2),
        );
        onProgress?.call(
          _asInt(progress['stored_count']),
          _asInt(progress['total_count']),
        );
        final rowCount = _asInt(progress['row_count']);
        if (progress['done'] == true || rowCount <= 0) {
          finished = true;
          break;
        }
        offset += rowCount;
      }
      if (!finished) {
        throw Exception('Загрузка КРР остановлена: слишком много страниц.');
      }
      await _post('/api/krr/sync/finish', body: {'sync_id': syncId});
    } catch (error) {
      await _abort(syncId, error);
      rethrow;
    } finally {
      relay.close();
    }
  }

  /// Lets the snow ticker paint between DTW pages.
  Future<void> _yieldFrame() async {
    final binding = SchedulerBinding.instance;
    binding.scheduleFrame();
    await binding.endOfFrame;
  }

  Future<void> _abort(String syncId, Object error) async {
    try {
      await _post(
        '/api/krr/sync/abort',
        body: {'sync_id': syncId, 'message': _plain(error)},
      );
    } catch (_) {
      // The original DTW or upload error is the one the user should see.
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
    String? rawBody,
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final response = await _client.post(
      path,
      body: body,
      rawBody: rawBody,
      query: query,
      timeout: timeout,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_messageFor(response));
    }
    if (response.body.isEmpty) return {};
    return ApiClient.decodeMap(response);
  }

  Future<KrrDashboard> query({
    required AnalyticsFilters filters,
    required int tableLimit,
  }) async {
    final response = await _client.post(
      '/api/krr/dashboard',
      body: {
        ...filters.toQueryJson(),
        'table_limit': tableLimit,
        'table_offset': 0,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_messageFor(response));
    }
    return KrrDashboard.fromJson(ApiClient.decodeMap(response));
  }

  int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  String _param(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _plain(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty) return 'Не удалось загрузить набор КРР.';
    return text.length > 2000 ? text.substring(0, 2000) : text;
  }

  String _messageFor(http.Response response) {
    try {
      final body = ApiClient.decodeMap(response);
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {
      // The body is not the API error envelope.
    }
    return 'Не удалось загрузить дашборд КРР';
  }
}

final krrApiInstance = KrrApi();

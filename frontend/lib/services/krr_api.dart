import 'package:http/http.dart' as http;

import '../models/analytics_filters.dart';
import '../models/krr_dashboard.dart';
import 'api_client.dart';

class KrrApi {
  KrrApi({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<Map<String, dynamic>> startSync({bool force = false}) async {
    final response = await _client.post(
      '/api/krr/sync',
      query: force ? const {'force': 'true'} : null,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_messageFor(response));
    }
    return ApiClient.decodeMap(response);
  }

  /// Starts a DTW fetch and waits until today's snapshot succeeds or fails.
  Future<void> syncUntilDone({
    bool force = false,
    void Function(int stored, int total)? onProgress,
  }) async {
    await startSync(force: force);
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final status = await syncStatus();
      final today = status['today'];
      if (today is! Map) continue;
      final state = today['status']?.toString() ?? '';
      final stored = (today['stored_count'] as num?)?.toInt() ?? 0;
      final total = (today['total_count'] as num?)?.toInt() ?? 0;
      onProgress?.call(stored, total);
      if (state == 'succeeded') return;
      if (state == 'failed') {
        throw Exception(
          today['error_message']?.toString() ?? 'Не удалось загрузить набор КРР',
        );
      }
    }
  }

  Future<Map<String, dynamic>> syncStatus() async {
    final response = await _client.get('/api/krr/sync');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_messageFor(response));
    }
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

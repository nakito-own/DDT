import 'package:http/http.dart' as http;

import '../models/analytics_dashboard.dart';
import '../models/analytics_filters.dart';
import 'api_client.dart';

class TaskAnalyticsApi {
  TaskAnalyticsApi({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<AnalyticsDashboard> query({
    required AnalyticsDashboardKind scope,
    int? spaceId,
    required AnalyticsFilters filters,
    required int tableLimit,
    int tableOffset = 0,
  }) async {
    final response = await _client.post(
      '/api/task-analytics/query',
      body: {
        'scope': scope == AnalyticsDashboardKind.tasksSpace ? 'space' : 'personal',
        if (spaceId != null) 'space_id': spaceId,
        ...filters.toQueryJson(),
        'table_limit': tableLimit,
        'table_offset': tableOffset,
      },
    );
    _ensureSuccess(response);
    return AnalyticsDashboard.fromJson(ApiClient.decodeMap(response));
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(_messageFor(response));
  }

  String _messageFor(http.Response response) {
    try {
      final body = ApiClient.decodeMap(response);
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {
      // Fall through to the generic error.
    }
    return 'Не удалось загрузить аналитику задач';
  }
}

final taskAnalyticsApi = TaskAnalyticsApi();

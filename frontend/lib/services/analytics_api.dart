import 'package:http/http.dart' as http;

import '../models/analytics_dashboard.dart';
import 'api_client.dart';

class AnalyticsApi {
  AnalyticsApi({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<AnalyticsDashboard> fetchDashboard({bool refresh = false}) async {
    final response = await _client.get(
      '/api/analytics/dashboard',
      query: refresh ? const {'refresh': 'true'} : null,
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
    return 'Не удалось загрузить данные аналитики';
  }
}

final analyticsApi = AnalyticsApi();

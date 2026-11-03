import 'package:http/http.dart' as http;

import '../models/space.dart';
import 'api_client.dart';

class SpacesApi {
  SpacesApi({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<List<Space>> fetchSpaces() async {
    final response = await _client.get('/api/spaces');
    _ensureSuccess(response);
    return ApiClient.decodeList(response).map(Space.fromJson).toList();
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Не удалось загрузить пространства');
  }
}

final spacesApi = SpacesApi();

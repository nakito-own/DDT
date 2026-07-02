import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';

typedef NotificationMessageHandler = void Function(Map<String, dynamic> message);
typedef NotificationDisconnectHandler = void Function();

class NotificationWsClient {
  NotificationWsClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  NotificationMessageHandler? onMessage;
  NotificationDisconnectHandler? onDisconnected;

  bool get isConnected => _channel != null;

  Future<void> connect() async {
    await disconnect();

    final token = await _client.getSessionToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final uri = _buildWsUri(token);
    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      _handleRawMessage,
      onError: (_) => _handleDisconnect(),
      onDone: _handleDisconnect,
      cancelOnError: true,
    );

    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _channel?.sink.add('ping');
    });
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Uri _buildWsUri(String token) {
    final base = Uri.parse(apiUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: wsScheme,
      path: '/api/ews/notifications/ws',
      queryParameters: {'token': token},
    );
  }

  void _handleRawMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }

    try {
      final message = jsonDecode(raw) as Map<String, dynamic>;
      onMessage?.call(message);
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  void _handleDisconnect() {
    if (_channel == null) {
      return;
    }
    unawaited(disconnect());
    onDisconnected?.call();
  }
}

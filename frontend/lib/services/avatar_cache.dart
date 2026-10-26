import 'dart:typed_data';

import 'api_client.dart';

/// In-memory cache of tiny avatar bytes. The key includes the server version,
/// so a new upload never reuses a stale image. Requests for the same key share
/// one in-flight download.
class AvatarImageCache {
  AvatarImageCache._();

  static final instance = AvatarImageCache._();

  static const _maxEntries = 400;

  final _bytes = <String, Uint8List>{};
  final _inflight = <String, Future<Uint8List?>>{};

  Future<Uint8List?> load({
    required int userId,
    required int version,
    required int pixelSize,
  }) {
    final key = '$userId:$version:$pixelSize';
    final cached = _bytes.remove(key);
    if (cached != null) {
      _bytes[key] = cached;
      return Future.value(cached);
    }
    return _inflight.putIfAbsent(key, () async {
      try {
        final response = await apiClient.get(
          '/api/users/$userId/avatar',
          query: {'s': '$pixelSize', 'v': '$version'},
        );
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          return null;
        }
        final bytes = response.bodyBytes;
        _store(key, bytes);
        return bytes;
      } catch (_) {
        return null;
      } finally {
        _inflight.remove(key);
      }
    });
  }

  void _store(String key, Uint8List bytes) {
    _bytes.remove(key);
    _bytes[key] = bytes;
    while (_bytes.length > _maxEntries) {
      _bytes.remove(_bytes.keys.first);
    }
  }

  void clear() {
    _bytes.clear();
  }
}

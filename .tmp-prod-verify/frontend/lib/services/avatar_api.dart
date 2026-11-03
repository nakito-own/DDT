import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import '../models/user_profile.dart';
import 'api_client.dart';
import 'avatar_cache.dart';
import 'directory_users.dart';

Future<UserProfile> uploadMyAvatar(Uint8List bytes) async {
  final prepared = await limitAvatarUpload(bytes);
  final response = await apiClient.postMultipart(
    '/api/users/me/avatar',
    field: 'file',
    bytes: prepared,
    filename: 'avatar.png',
  );
  return _profileFromResponse(response, fallback: 'Не удалось загрузить фото');
}

Future<UserProfile> deleteMyAvatar() async {
  final response = await apiClient.delete('/api/users/me/avatar');
  return _profileFromResponse(response, fallback: 'Не удалось удалить фото');
}

UserProfile _profileFromResponse(
  http.Response response, {
  required String fallback,
}) {
  if (response.statusCode != 200) {
    throw Exception(_errorDetail(response.body, fallback));
  }
  final user = UserProfile.fromJson(ApiClient.decodeMap(response));
  publishDirectoryUserAvatar(user);
  return user;
}

String _errorDetail(String body, String fallback) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
    }
  } catch (_) {}
  return fallback;
}

/// Encodes a square upload at 512px so the request stays small.
/// The server stores 64px and 256px WebP copies.
Future<Uint8List> limitAvatarUpload(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 512);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return bytes;
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } catch (_) {
    if (bytes.length > 6 * 1024 * 1024) {
      throw Exception('Файл слишком большой');
    }
    return bytes;
  }
}

void clearAvatarCache() {
  AvatarImageCache.instance.clear();
}

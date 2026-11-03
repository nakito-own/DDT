import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

class SessionTokenStorage {
  SessionTokenStorage({GetStorage? box, FlutterSecureStorage? secureStorage})
    : _box = box ?? GetStorage(_boxName),
      _secureStorage = secureStorage;

  static const _key = 'ews_session_token';
  static const _boxName = 'ddt_auth';

  static var _ready = false;

  final GetStorage _box;
  final FlutterSecureStorage? _secureStorage;

  static Future<void> prepare() async {
    if (_ready) {
      return;
    }
    await GetStorage.init(_boxName);
    _ready = true;
  }

  FlutterSecureStorage get _secure =>
      _secureStorage ?? const FlutterSecureStorage();

  Future<String?> read() async {
    if (kIsWeb) {
      return _box.read<String>(_key);
    }

    try {
      return await _secure.read(key: _key);
    } on MissingPluginException {
      return _box.read<String>(_key);
    } on PlatformException {
      return _box.read<String>(_key);
    }
  }

  Future<void> write(String token) async {
    if (kIsWeb) {
      await _box.write(_key, token);
      return;
    }

    try {
      await _secure.write(key: _key, value: token);
    } on MissingPluginException {
      await _box.write(_key, token);
    } on PlatformException {
      await _box.write(_key, token);
    }
  }

  Future<void> delete() async {
    if (kIsWeb) {
      await _box.remove(_key);
      return;
    }

    try {
      await _secure.delete(key: _key);
    } on MissingPluginException {
      await _box.remove(_key);
    } on PlatformException {
      await _box.remove(_key);
    }

    await _box.remove(_key);
  }
}

final sessionTokenStorage = SessionTokenStorage();

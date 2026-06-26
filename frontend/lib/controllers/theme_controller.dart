import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  static const _storageKey = 'theme_mode';
  static const _boxName = 'ddt_storage';

  static var _storageReady = false;

  final _isDarkMode = false.obs;

  bool get isDarkMode => _isDarkMode.value;

  ThemeMode get themeMode =>
      _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  static Future<void> prepareStorage() async {
    await GetStorage.init(_boxName);
    _storageReady = true;
  }

  @override
  void onInit() {
    super.onInit();
    if (!_storageReady) return;

    final saved = GetStorage(_boxName).read<String>(_storageKey);
    _isDarkMode.value = saved == 'dark';
  }

  void toggleTheme() {
    _isDarkMode.value = !_isDarkMode.value;
    Get.changeThemeMode(themeMode);

    if (_storageReady) {
      GetStorage(_boxName).write(
        _storageKey,
        _isDarkMode.value ? 'dark' : 'light',
      );
    }
  }
}

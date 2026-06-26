import 'package:get/get.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/ews_api.dart';
import 'tasks_controller.dart';

enum EwsAuthStatus { unknown, authenticated, unauthenticated }

class EwsAuthController extends GetxController {
  EwsAuthController({EwsApi? api}) : _api = api ?? ewsApi;

  final EwsApi _api;

  final Rx<EwsAuthStatus> status = EwsAuthStatus.unknown.obs;
  final RxnString email = RxnString();
  final Rxn<UserProfile> user = Rxn<UserProfile>();
  final RxBool connected = false.obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  bool get isAuthenticated => status.value == EwsAuthStatus.authenticated;

  int? get currentUserId => user.value?.id;

  @override
  void onInit() {
    super.onInit();
    apiClient.onUnauthorized = _handleUnauthorized;
    restoreSession();
  }

  Future<void> restoreSession() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final session = await _api.restoreSession();
      if (session == null) {
        await _setUnauthenticated(clearToken: false);
        return;
      }
      _setAuthenticated(session);
    } catch (error) {
      await _setUnauthenticated(clearToken: true);
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    required String email,
    required bool rememberMe,
  }) async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final session = await _api.login(
        username: username,
        password: password,
        email: email,
        rememberMe: rememberMe,
      );
      _setAuthenticated(session);
      if (Get.isRegistered<TasksController>()) {
        await Get.find<TasksController>().loadBoard();
      }
      return true;
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      await _setUnauthenticated(clearToken: true);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    isLoading.value = true;
    try {
      await _api.logout();
    } finally {
      await _setUnauthenticated(clearToken: false);
      if (Get.isRegistered<TasksController>()) {
        Get.find<TasksController>().clearBoard();
      }
      isLoading.value = false;
    }
  }

  void _setAuthenticated(EwsSession session) {
    email.value = session.email;
    user.value = session.user;
    connected.value = session.connected;
    status.value = EwsAuthStatus.authenticated;
  }

  Future<void> _setUnauthenticated({required bool clearToken}) async {
    email.value = null;
    user.value = null;
    connected.value = false;
    status.value = EwsAuthStatus.unauthenticated;
    if (clearToken) {
      await apiClient.clearSessionToken();
    }
  }

  Future<void> _handleUnauthorized() async {
    await _setUnauthenticated(clearToken: true);
    if (Get.isRegistered<TasksController>()) {
      Get.find<TasksController>().clearBoard();
    }
  }
}

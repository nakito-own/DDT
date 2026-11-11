import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/user_profile.dart';
import '../../services/api_client.dart';
import '../../services/avatar_api.dart';
import '../../services/ews_api.dart';
import '../../utils/ews_login.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({EwsApi? api}) : _api = api ?? ewsApi, super(const AuthInitial()) {
    on<AuthSessionRestoreRequested>(
      _onSessionRestoreRequested,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<AuthLoginRequested>(
      _onLoginRequested,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
    on<AuthUserUpdated>(_onUserUpdated);
    on<AuthExchangeRefreshRequested>(_onExchangeRefreshRequested);

    // Перехват 401 — весь UI переходит в AuthUnauthenticated.
    apiClient.onUnauthorized = () => add(const AuthSessionExpired());
  }

  final EwsApi _api;

  /// Пока идёт restore, пользователь может отправить login — увеличиваем счётчик,
  /// чтобы устаревший restore не перезаписал состояние после входа.
  int _sessionRestoreGeneration = 0;
  Timer? _exchangeRefreshTimer;
  DateTime? _nextExchangeRefreshAt;
  static const _exchangeRefreshPeriod = Duration(hours: 12);
  static const _exchangeRefreshTick = Duration(minutes: 15);

  @override
  Future<void> close() {
    _stopExchangeRefresh();
    apiClient.onUnauthorized = null;
    return super.close();
  }

  Future<void> _onSessionRestoreRequested(
    AuthSessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    final generation = ++_sessionRestoreGeneration;

    final token = await apiClient.getSessionToken();
    if (generation != _sessionRestoreGeneration) {
      return;
    }
    if (token == null || token.isEmpty) {
      emit(const AuthUnauthenticated());
      return;
    }

    try {
      final session = await _api.restoreSession();
      if (generation != _sessionRestoreGeneration) {
        return;
      }
      if (session == null) {
        await _clearToken();
        emit(const AuthUnauthenticated());
        return;
      }
      _notifyAuthenticated();
      _scheduleExchangeRefresh();
      emit(
        AuthAuthenticated(
          user: session.user,
          email: session.email,
          connected: session.connected,
        ),
      );
    } catch (_) {
      if (generation != _sessionRestoreGeneration) {
        return;
      }
      await _clearToken();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    _sessionRestoreGeneration++;
    emit(const AuthLoading());
    try {
      final username = usernameFromEmail(event.email);
      if (username == null) {
        emit(
          const AuthFailure(
            message: 'Почта должна содержать логин до @',
          ),
        );
        return;
      }
      final session = await _api.login(
        username: username,
        password: event.password,
        email: event.email,
        rememberMe: event.rememberMe,
      );
      _notifyAuthenticated();
      _scheduleExchangeRefresh();
      emit(
        AuthAuthenticated(
          user: session.user,
          email: session.email,
          connected: session.connected,
        ),
      );
    } on TimeoutException {
      await _clearToken();
      emit(
        const AuthFailure(
          message:
              'Превышено время ожидания. Проверьте VPN и доступность Exchange.',
        ),
      );
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      await _clearToken();
      emit(AuthFailure(message: message));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _api.logout();
    } finally {
      await _handleSignOut();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    await _clearToken();
    await _handleSignOut();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onExchangeRefreshRequested(
    AuthExchangeRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthAuthenticated) {
      return;
    }
    try {
      final session = await _api.refreshSession();
      if (session == null || state is! AuthAuthenticated) {
        return;
      }
      _scheduleExchangeRefresh();
      emit(
        AuthAuthenticated(
          user: session.user,
          email: session.email,
          connected: session.connected,
        ),
      );
    } catch (_) {
      // 401 обрабатывается onUnauthorized. Остальные ошибки не выкидывают
      // пользователя на логин — следующая попытка через тик таймера.
    }
  }

  void _scheduleExchangeRefresh() {
    _nextExchangeRefreshAt = DateTime.now().add(_exchangeRefreshPeriod);
    _exchangeRefreshTimer?.cancel();
    _exchangeRefreshTimer = Timer.periodic(_exchangeRefreshTick, (_) {
      final dueAt = _nextExchangeRefreshAt;
      if (dueAt == null || DateTime.now().isBefore(dueAt)) {
        return;
      }
      if (state is AuthAuthenticated) {
        add(const AuthExchangeRefreshRequested());
      }
    });
  }

  void _stopExchangeRefresh() {
    _exchangeRefreshTimer?.cancel();
    _exchangeRefreshTimer = null;
    _nextExchangeRefreshAt = null;
  }

  void _onUserUpdated(AuthUserUpdated event, Emitter<AuthState> emit) {
    final current = state;
    if (current is! AuthAuthenticated) return;
    emit(
      AuthAuthenticated(
        user: event.user,
        email: current.email,
        connected: current.connected,
      ),
    );
  }

  void _notifyAuthenticated() {
    // Уведомление других Bloc-ов происходит через BlocListener в main.dart.
  }

  Future<void> _handleSignOut() async {
    _stopExchangeRefresh();
    clearAvatarCache();
  }

  Future<void> _clearToken() async {
    await apiClient.clearSessionToken();
  }
}

part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Восстановить сессию из хранилища при старте приложения.
final class AuthSessionRestoreRequested extends AuthEvent {
  const AuthSessionRestoreRequested();
}

/// Пользователь отправил форму входа.
final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.email,
    required this.password,
    required this.rememberMe,
  });

  final String email;
  final String password;
  final bool rememberMe;

  @override
  List<Object?> get props => [email, password, rememberMe];
}

/// Тихое обновление сессии Exchange по сохранённым на сервере учётным данным.
final class AuthExchangeRefreshRequested extends AuthEvent {
  const AuthExchangeRefreshRequested();
}

/// Пользователь нажал «Выйти».
final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Сервер вернул 401 — сессия истекла.
final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

/// Профиль обновлён локально, например после загрузки фото.
final class AuthUserUpdated extends AuthEvent {
  const AuthUserUpdated(this.user);

  final UserProfile user;

  @override
  List<Object?> get props => [user];
}

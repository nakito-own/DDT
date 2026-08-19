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
    required this.username,
    required this.password,
    required this.email,
    required this.rememberMe,
  });

  final String username;
  final String password;
  final String email;
  final bool rememberMe;

  @override
  List<Object?> get props => [username, password, email, rememberMe];
}

/// Пользователь нажал «Выйти».
final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Сервер вернул 401 — сессия истекла.
final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

part of 'auth_bloc.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние — сессия ещё не проверялась.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Идёт асинхронная операция (restore / login / logout).
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Пользователь успешно аутентифицирован.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.user,
    required this.email,
    required this.connected,
  });

  final UserProfile user;
  final String email;
  final bool connected;

  @override
  List<Object?> get props => [user, email, connected];
}

/// Пользователь не аутентифицирован.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Ошибка при входе (отображается в форме логина).
final class AuthFailure extends AuthState {
  const AuthFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

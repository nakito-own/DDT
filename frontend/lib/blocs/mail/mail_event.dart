part of 'mail_bloc.dart';

sealed class MailEvent extends Equatable {
  const MailEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузить входящие при открытии почты.
final class MailInboxLoadRequested extends MailEvent {
  const MailInboxLoadRequested();
}

/// Обновить входящие (например, по WS-уведомлению).
final class MailInboxRefreshRequested extends MailEvent {
  const MailInboxRefreshRequested();
}

/// Пользователь выбрал письмо из списка.
final class MailMessageSelected extends MailEvent {
  const MailMessageSelected(this.message);

  final MailMessage message;

  @override
  List<Object?> get props => [message];
}

/// Отправить новое письмо.
final class MailMessageSendRequested extends MailEvent {
  const MailMessageSendRequested({
    required this.to,
    required this.subject,
    required this.body,
    this.cc = const [],
  });

  final List<String> to;
  final String subject;
  final String body;
  final List<String> cc;

  @override
  List<Object?> get props => [to, subject, body, cc];
}

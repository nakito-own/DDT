part of 'mail_bloc.dart';

sealed class MailEvent extends Equatable {
  const MailEvent();

  @override
  List<Object?> get props => [];
}

/// Очистить персональные данные почты при завершении сессии.
final class MailSessionCleared extends MailEvent {
  const MailSessionCleared();
}

/// Загрузить входящие при открытии почты.
final class MailInboxLoadRequested extends MailEvent {
  const MailInboxLoadRequested({this.showAnimation = false});

  final bool showAnimation;

  @override
  List<Object?> get props => [showAnimation];
}

/// Обновить входящие.
final class MailInboxRefreshRequested extends MailEvent {
  const MailInboxRefreshRequested({this.showAnimation = false});

  /// Показывать анимацию для обновления, инициированного пользователем.
  final bool showAnimation;

  @override
  List<Object?> get props => [showAnimation];
}

/// Подгрузить более старые письма (следующая страница).
final class MailInboxLoadMoreRequested extends MailEvent {
  const MailInboxLoadMoreRequested();
}

/// Изменить фильтр или сортировку входящих.
final class MailInboxQueryChanged extends MailEvent {
  const MailInboxQueryChanged({this.filter, this.sort, this.folderId});

  final MailInboxFilter? filter;
  final MailInboxSort? sort;
  final String? folderId;

  @override
  List<Object?> get props => [filter, sort, folderId];
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

// ─── Множественный выбор ──────────────────────────────────────────────────────

/// Включить режим множественного выбора (кнопка «Выделить» в аппбаре).
final class MailSelectionModeEntered extends MailEvent {
  const MailSelectionModeEntered();
}

/// Переключить наличие письма в множественном выборе.
final class MailSelectionToggled extends MailEvent {
  const MailSelectionToggled(this.messageId);

  final String messageId;

  @override
  List<Object?> get props => [messageId];
}

/// Снять весь множественный выбор и выйти из режима выбора.
final class MailSelectionCleared extends MailEvent {
  const MailSelectionCleared();
}

/// Выбрать все письма текущего списка.
final class MailSelectAllRequested extends MailEvent {
  const MailSelectAllRequested();
}

/// Пакетно отметить выбранные письма как прочитанные.
final class MailBulkMarkReadRequested extends MailEvent {
  const MailBulkMarkReadRequested();
}

// ─── Архив ────────────────────────────────────────────────────────────────────

/// Переместить письма в архив Exchange.
final class MailArchiveRequested extends MailEvent {
  const MailArchiveRequested({
    required this.messageIds,
    required this.folderId,
  });

  final List<String> messageIds;
  final String? folderId;

  @override
  List<Object?> get props => [messageIds, folderId];
}

// ─── Вложения ─────────────────────────────────────────────────────────────────

/// Скачать вложение текущего письма.
final class MailAttachmentDownloadRequested extends MailEvent {
  const MailAttachmentDownloadRequested({
    required this.messageId,
    required this.attachment,
    required this.folderId,
  });

  final String messageId;
  final MailAttachment attachment;
  final String? folderId;

  @override
  List<Object?> get props => [messageId, attachment.id, folderId];
}

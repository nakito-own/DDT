import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/mail_message.dart';
import '../../services/ews_api.dart';

part 'mail_event.dart';
part 'mail_state.dart';

class MailBloc extends Bloc<MailEvent, MailState> {
  MailBloc({EwsApi? api})
      : _api = api ?? ewsApi,
        super(const MailState()) {
    on<MailInboxLoadRequested>(_onInboxLoadRequested);
    on<MailInboxRefreshRequested>(_onInboxRefreshRequested);
    on<MailMessageSelected>(_onMessageSelected);
    on<MailMessageSendRequested>(_onMessageSendRequested);
  }

  final EwsApi _api;

  Future<void> _onInboxLoadRequested(
    MailInboxLoadRequested event,
    Emitter<MailState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    await _loadInbox(emit);
  }

  Future<void> _onInboxRefreshRequested(
    MailInboxRefreshRequested event,
    Emitter<MailState> emit,
  ) async {
    await _loadInbox(emit);
  }

  Future<void> _loadInbox(Emitter<MailState> emit) async {
    try {
      final results = await Future.wait([
        _api.fetchMailFolders(),
        _api.fetchInbox(),
      ]);
      final folders = results[0] as MailFolders;
      final messages = results[1] as List<MailMessage>;

      // Если выбранное письмо есть в новом списке — обновить его
      MailMessage? updatedSelected;
      final selectedId = state.selectedMessage?.id;
      if (selectedId != null) {
        final index = messages.indexWhere((item) => item.id == selectedId);
        if (index >= 0) {
          updatedSelected = messages[index];
        }
      }

      emit(state.copyWith(
        isLoading: false,
        folders: () => folders,
        messages: messages,
        selectedMessage: updatedSelected != null
            ? () => updatedSelected
            : null,
        errorMessage: () => null,
      ));
    } catch (error) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onMessageSelected(
    MailMessageSelected event,
    Emitter<MailState> emit,
  ) async {
    final message = event.message;
    final wasUnread = !message.isRead;

    // Оптимистично отметить как прочитанное локально
    List<MailMessage> updatedMessages = state.messages;
    if (wasUnread) {
      updatedMessages = _setReadLocally(state.messages, message.id);
    }

    emit(state.copyWith(
      selectedMessage: () => wasUnread
          ? updatedMessages.firstWhere((m) => m.id == message.id,
              orElse: () => message)
          : message,
      messages: updatedMessages,
    ));

    // Если тело уже загружено — просто отметить на сервере
    final hasCachedBody = message.body != null && message.body!.isNotEmpty;
    if (hasCachedBody) {
      if (wasUnread) {
        _api.markMessageRead(message.id).catchError((_) => null);
      }
      return;
    }

    // Загрузить детали письма
    emit(state.copyWith(isLoadingDetail: true));
    try {
      final detail = await _api.fetchMessage(
        message.id,
        markRead: wasUnread,
      );
      final merged = _mergeDetail(state.messages, detail);
      emit(state.copyWith(
        isLoadingDetail: false,
        selectedMessage: () => detail,
        messages: merged,
        errorMessage: () => null,
      ));
    } catch (error) {
      emit(state.copyWith(
        isLoadingDetail: false,
        errorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onMessageSendRequested(
    MailMessageSendRequested event,
    Emitter<MailState> emit,
  ) async {
    emit(state.copyWith(isSending: true, errorMessage: () => null));
    try {
      await _api.sendMail(
        to: event.to,
        cc: event.cc,
        subject: event.subject,
        body: event.body,
      );
      // После отправки обновляем входящие
      await _loadInbox(emit);
      emit(state.copyWith(isSending: false));
    } catch (error) {
      emit(state.copyWith(
        isSending: false,
        errorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  List<MailMessage> _setReadLocally(List<MailMessage> messages, String id) {
    return messages.map((m) {
      if (m.id == id && !m.isRead) return m.copyWith(isRead: true);
      return m;
    }).toList();
  }

  List<MailMessage> _mergeDetail(List<MailMessage> messages, MailMessage detail) {
    return messages.map((m) {
      if (m.id != detail.id) return m;
      return m.copyWith(
        body: detail.body,
        bodyType: detail.bodyType,
        preview: detail.preview,
        isRead: detail.isRead,
      );
    }).toList();
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/mail_inbox_options.dart';
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
    on<MailInboxLoadMoreRequested>(_onInboxLoadMoreRequested);
    on<MailInboxQueryChanged>(_onInboxQueryChanged);
    on<MailMessageSelected>(_onMessageSelected);
    on<MailMessageSendRequested>(_onMessageSendRequested);
  }

  static const _pageSize = 50;

  final EwsApi _api;
  int _inboxRequestGeneration = 0;

  Future<void> _onInboxLoadRequested(
    MailInboxLoadRequested event,
    Emitter<MailState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    await _reloadInbox(emit);
  }

  Future<void> _onInboxRefreshRequested(
    MailInboxRefreshRequested event,
    Emitter<MailState> emit,
  ) async {
    await _reloadInbox(emit);
  }

  Future<void> _onInboxLoadMoreRequested(
    MailInboxLoadMoreRequested event,
    Emitter<MailState> emit,
  ) async {
    if (state.isLoading ||
        state.isRefreshingInbox ||
        state.isLoadingMore ||
        !state.hasMoreMessages ||
        state.messages.isEmpty) {
      return;
    }

    emit(state.copyWith(
      isLoadingMore: true,
      loadMoreErrorMessage: () => null,
    ));

    try {
      final batch = await _api.fetchInbox(
        limit: _pageSize,
        offset: state.messages.length,
        filter: state.filter,
        sort: state.sort,
      );

      emit(state.copyWith(
        isLoadingMore: false,
        messages: [...state.messages, ...batch],
        hasMoreMessages: batch.length >= _pageSize,
        loadMoreErrorMessage: () => null,
      ));
    } catch (error) {
      emit(state.copyWith(
        isLoadingMore: false,
        loadMoreErrorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onInboxQueryChanged(
    MailInboxQueryChanged event,
    Emitter<MailState> emit,
  ) async {
    final nextFilter = event.filter ?? state.filter;
    final nextSort = event.sort ?? state.sort;

    if (nextFilter == state.filter && nextSort == state.sort) {
      return;
    }

    emit(state.copyWith(
      filter: nextFilter,
      sort: nextSort,
      inboxQueryErrorMessage: () => null,
    ));

    await _reloadInbox(emit);
  }

  Future<void> _reloadInbox(Emitter<MailState> emit) async {
    final background = state.messages.isNotEmpty;
    final generation = ++_inboxRequestGeneration;
    final filter = state.filter;
    final sort = state.sort;
    final previousSelected = state.selectedMessage;

    if (background) {
      emit(state.copyWith(
        isRefreshingInbox: true,
        inboxQueryErrorMessage: () => null,
        errorMessage: () => null,
      ));
    }

    try {
      final foldersFuture = state.folders == null && !background
          ? _api.fetchMailFolders()
          : null;
      final messagesFuture = _api.fetchInbox(
        limit: _pageSize,
        filter: filter,
        sort: sort,
      );

      final messages = await messagesFuture;
      if (generation != _inboxRequestGeneration) return;

      final folders = foldersFuture != null
          ? await foldersFuture
          : state.folders;

      final updatedSelected = _resolveSelectedMessage(
        previousSelected,
        messages,
      );

      emit(state.copyWith(
        isLoading: false,
        isRefreshingInbox: false,
        folders: folders != null ? () => folders : null,
        messages: messages,
        hasMoreMessages: messages.length >= _pageSize,
        loadMoreErrorMessage: () => null,
        selectedMessage: () => updatedSelected,
        errorMessage: () => null,
        inboxQueryErrorMessage: () => null,
      ));
    } catch (error) {
      if (generation != _inboxRequestGeneration) return;

      final message = error.toString().replaceFirst('Exception: ', '');
      if (background) {
        emit(state.copyWith(
          isRefreshingInbox: false,
          inboxQueryErrorMessage: () => message,
        ));
        return;
      }

      emit(state.copyWith(
        isLoading: false,
        isRefreshingInbox: false,
        errorMessage: () => message,
      ));
    }
  }

  MailMessage? _resolveSelectedMessage(
    MailMessage? previousSelected,
    List<MailMessage> messages,
  ) {
    if (previousSelected == null) return null;

    final index =
        messages.indexWhere((item) => item.id == previousSelected.id);
    if (index >= 0) {
      return messages[index];
    }

    return previousSelected;
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
      await _reloadInbox(emit);
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

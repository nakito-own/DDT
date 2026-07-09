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
    on<MailSelectionModeEntered>(_onSelectionModeEntered);
    on<MailSelectionToggled>(_onSelectionToggled);
    on<MailSelectionCleared>(_onSelectionCleared);
    on<MailSelectAllRequested>(_onSelectAllRequested);
    on<MailBulkMarkReadRequested>(_onBulkMarkReadRequested);
    on<MailArchiveRequested>(_onArchiveRequested);
    on<MailAttachmentDownloadRequested>(_onAttachmentDownloadRequested);
  }

  static const _pageSize = 50;

  final EwsApi _api;
  int _inboxRequestGeneration = 0;

  // ─── Inbox loading ────────────────────────────────────────────────────────

  Future<void> _onInboxLoadRequested(
    MailInboxLoadRequested event,
    Emitter<MailState> emit,
  ) async {
    // If cached messages already exist, skip the full-screen loader and do
    // a silent background refresh instead, preserving the visible list.
    if (state.messages.isNotEmpty) {
      await _reloadInbox(emit);
      return;
    }
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
        folderId: state.selectedFolderId,
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
    final nextFolderId = event.folderId ?? state.selectedFolderId;

    if (nextFilter == state.filter &&
        nextSort == state.sort &&
        nextFolderId == state.selectedFolderId) {
      return;
    }

    emit(state.copyWith(
      filter: nextFilter,
      sort: nextSort,
      selectedFolderId: () => nextFolderId,
      inboxQueryErrorMessage: () => null,
      // Clear selection when switching query
      selectedMessageIds: const {},
      isSelectionModeActive: false,
    ));

    await _reloadInbox(emit);
  }

  Future<void> _reloadInbox(Emitter<MailState> emit) async {
    final background = state.messages.isNotEmpty;
    final generation = ++_inboxRequestGeneration;
    final filter = state.filter;
    final sort = state.sort;
    var folderId = state.selectedFolderId;
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
        folderId: folderId,
      );

      final freshMessages = await messagesFuture;
      if (generation != _inboxRequestGeneration) return;

      final folders = foldersFuture != null
          ? await foldersFuture
          : state.folders;
      if ((folderId == null || folderId.isEmpty) && folders != null) {
        folderId = folders.inboxFolderId;
      }

      // Merge fresh list with cached bodies to avoid losing loaded content.
      final mergedMessages = _smartMergeMessages(state.messages, freshMessages);

      // Skip updating the messages list if nothing actually changed —
      // this prevents unnecessary BlocBuilder rebuilds.
      final messagesChanged =
          !background || _hasMessagesChanged(state.messages, mergedMessages);

      final messagesForSelection =
          messagesChanged ? mergedMessages : state.messages;
      final updatedSelected = _resolveSelectedMessage(
        previousSelected,
        messagesForSelection,
        folderId,
      );

      emit(state.copyWith(
        isLoading: false,
        isRefreshingInbox: false,
        folders: folders != null ? () => folders : null,
        selectedFolderId: () => folderId,
        messages: messagesChanged ? mergedMessages : null,
        hasMoreMessages: freshMessages.length >= _pageSize,
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

  // ─── Message detail ───────────────────────────────────────────────────────

  Future<void> _onMessageSelected(
    MailMessageSelected event,
    Emitter<MailState> emit,
  ) async {
    final tapped = event.message;
    final cached = _findMessageById(state.messages, tapped.id) ?? tapped;
    final wasUnread = !cached.isRead;

    var updatedMessages = state.messages;
    if (wasUnread) {
      updatedMessages = _setReadLocally(state.messages, cached.id);
    }

    final selected = wasUnread
        ? updatedMessages.firstWhere(
            (m) => m.id == cached.id,
            orElse: () => cached,
          )
        : cached;

    final needsBody = selected.body == null || selected.body!.isEmpty;
    final needsAttachments =
        (selected.hasAttachments || selected.attachments.isNotEmpty) &&
            selected.attachments.isEmpty;
    final needsDetail = !selected.detailLoaded || needsBody || needsAttachments;
    emit(state.copyWith(
      selectedMessage: () => selected,
      messages: updatedMessages,
    ));

    if (!needsDetail) {
      if (wasUnread) {
        _api
            .markMessageRead(cached.id, folderId: cached.folderId)
            .catchError((_) => null);
      }
      return;
    }

    emit(state.copyWith(isLoadingDetail: needsBody));
    try {
      final detail = await _api.fetchMessage(
        cached.id,
        markRead: wasUnread,
        folderId: cached.folderId,
      );
      final merged = _mergeDetail(updatedMessages, detail);
      final updatedSelected = merged.firstWhere((m) => m.id == detail.id);
      emit(state.copyWith(
        isLoadingDetail: false,
        selectedMessage: () => updatedSelected,
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

  // ─── Multiple selection ───────────────────────────────────────────────────

  void _onSelectionModeEntered(
    MailSelectionModeEntered event,
    Emitter<MailState> emit,
  ) {
    emit(state.copyWith(
      isSelectionModeActive: true,
      archiveErrorMessage: () => null,
    ));
  }

  void _onSelectionToggled(
    MailSelectionToggled event,
    Emitter<MailState> emit,
  ) {
    final ids = Set<String>.from(state.selectedMessageIds);
    if (ids.contains(event.messageId)) {
      ids.remove(event.messageId);
    } else {
      ids.add(event.messageId);
    }
    emit(state.copyWith(
      selectedMessageIds: ids,
      archiveErrorMessage: () => null,
    ));
  }

  void _onSelectionCleared(
    MailSelectionCleared event,
    Emitter<MailState> emit,
  ) {
    emit(state.copyWith(
      selectedMessageIds: const {},
      isSelectionModeActive: false,
      archiveErrorMessage: () => null,
    ));
  }

  void _onSelectAllRequested(
    MailSelectAllRequested event,
    Emitter<MailState> emit,
  ) {
    final allIds = state.messages.map((m) => m.id).toSet();
    emit(state.copyWith(selectedMessageIds: allIds));
  }

  Future<void> _onBulkMarkReadRequested(
    MailBulkMarkReadRequested event,
    Emitter<MailState> emit,
  ) async {
    final ids = state.selectedMessageIds.toList();
    if (ids.isEmpty) return;

    // Optimistic local update
    final updatedMessages = state.messages.map((m) {
      if (ids.contains(m.id) && !m.isRead) return m.copyWith(isRead: true);
      return m;
    }).toList();

    emit(state.copyWith(
      messages: updatedMessages,
      selectedMessageIds: const {},
    ));

    // Fire-and-forget: mark read on server
    final folderId = state.selectedFolderId;
    for (final id in ids) {
      _api
          .markMessageRead(id, folderId: folderId)
          .catchError((_) => null);
    }
  }

  // ─── Archive ──────────────────────────────────────────────────────────────

  Future<void> _onArchiveRequested(
    MailArchiveRequested event,
    Emitter<MailState> emit,
  ) async {
    if (event.messageIds.isEmpty) return;

    emit(state.copyWith(
      isArchiving: true,
      archiveErrorMessage: () => null,
    ));

    try {
      final result = await _api.archiveMessages(
        event.messageIds,
        folderId: event.folderId,
      );

      final archivedSet = result.archivedIds.toSet();

      // Remove successfully archived messages from the list
      final updatedMessages = state.messages
          .where((m) => !archivedSet.contains(m.id))
          .toList();

      // If the currently viewed message was archived, deselect it
      final updatedSelected = archivedSet.contains(state.selectedMessage?.id)
          ? null
          : state.selectedMessage;

      // Keep only failed messages in selection
      final updatedSelection = Set<String>.from(state.selectedMessageIds)
        ..removeAll(archivedSet);

      String? errorMsg;
      if (result.errors.isNotEmpty) {
        final n = result.errors.length;
        errorMsg = 'Не удалось переместить $n ${_pluralMail(n)}';
      }

      emit(state.copyWith(
        isArchiving: false,
        messages: updatedMessages,
        selectedMessage: () => updatedSelected,
        selectedMessageIds: updatedSelection,
        archiveErrorMessage: errorMsg != null ? () => errorMsg : () => null,
      ));
    } catch (error) {
      emit(state.copyWith(
        isArchiving: false,
        archiveErrorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  // ─── Attachments ──────────────────────────────────────────────────────────

  Future<void> _onAttachmentDownloadRequested(
    MailAttachmentDownloadRequested event,
    Emitter<MailState> emit,
  ) async {
    emit(state.copyWith(downloadErrorMessage: () => null));
    try {
      await _api.downloadAttachment(
        event.messageId,
        attachmentId: event.attachment.id,
        filename: event.attachment.name,
        contentType: event.attachment.contentType,
        folderId: event.folderId,
      );
    } catch (error) {
      emit(state.copyWith(
        downloadErrorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  MailMessage? _findMessageById(List<MailMessage> messages, String id) {
    for (final message in messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  MailMessage _mergeMessageDetails(MailMessage primary, MailMessage? fallback) {
    if (fallback == null || fallback.id != primary.id) return primary;

    final primaryBody = primary.body;
    final fallbackBody = fallback.body;
    final resolvedBody = primaryBody != null && primaryBody.isNotEmpty
        ? primaryBody
        : fallbackBody;

    return primary.copyWith(
      body: resolvedBody,
      bodyType: primaryBody != null && primaryBody.isNotEmpty
          ? primary.bodyType
          : fallback.bodyType,
      hasAttachments: primary.hasAttachments || fallback.hasAttachments,
      attachments: primary.attachments.isNotEmpty
          ? primary.attachments
          : fallback.attachments,
      detailLoaded: primary.detailLoaded || fallback.detailLoaded,
    );
  }

  MailMessage? _resolveSelectedMessage(
    MailMessage? previousSelected,
    List<MailMessage> messages,
    String? selectedFolderId,
  ) {
    if (previousSelected == null) return null;
    if (selectedFolderId != null &&
        previousSelected.folderId != selectedFolderId) {
      return null;
    }

    final index =
        messages.indexWhere((item) => item.id == previousSelected.id);
    if (index >= 0) {
      return _mergeMessageDetails(messages[index], previousSelected);
    }

    return previousSelected;
  }

  List<MailMessage> _setReadLocally(List<MailMessage> messages, String id) {
    return messages.map((m) {
      if (m.id == id && !m.isRead) return m.copyWith(isRead: true);
      return m;
    }).toList();
  }

  List<MailMessage> _mergeDetail(
      List<MailMessage> messages, MailMessage detail) {
    return messages.map((m) {
      if (m.id != detail.id) return m;
      return m.copyWith(
        body: detail.body,
        bodyType: detail.bodyType,
        preview: detail.preview,
        isRead: detail.isRead,
        hasAttachments: detail.hasAttachments || m.hasAttachments,
        attachments: detail.attachments.isNotEmpty
            ? detail.attachments
            : m.attachments,
        detailLoaded: true,
      );
    }).toList();
  }

  /// Merge fresh server list with cached data (preserve loaded bodies).
  List<MailMessage> _smartMergeMessages(
    List<MailMessage> current,
    List<MailMessage> fresh,
  ) {
    if (current.isEmpty) return fresh;

    final currentMap = <String, MailMessage>{
      for (final m in current) m.id: m,
    };

    return fresh.map((freshMsg) {
      final existing = currentMap[freshMsg.id];
      if (existing == null) return freshMsg;

      final hasCachedBody =
          existing.body != null && existing.body!.isNotEmpty;
      if (!hasCachedBody) return freshMsg;

      return freshMsg.copyWith(
        body: existing.body,
        bodyType: existing.bodyType,
        hasAttachments: freshMsg.hasAttachments || existing.hasAttachments,
        attachments: existing.attachments.isNotEmpty
            ? existing.attachments
            : freshMsg.attachments,
        detailLoaded: existing.detailLoaded,
      );
    }).toList();
  }

  /// Returns true if the two lists differ in a way visible to the user.
  bool _hasMessagesChanged(
    List<MailMessage> oldList,
    List<MailMessage> newList,
  ) {
    if (identical(oldList, newList)) return false;
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      final o = oldList[i];
      final n = newList[i];
      if (o.id != n.id ||
          o.isRead != n.isRead ||
          o.subject != n.subject ||
          o.hasAttachments != n.hasAttachments) {
        return true;
      }
    }
    return false;
  }

  static String _pluralMail(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'письмо';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'письма';
    }
    return 'писем';
  }
}

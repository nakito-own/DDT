import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/mail_inbox_options.dart';
import '../../models/mail_message.dart';
import '../../services/ews_api.dart';

part 'mail_event.dart';
part 'mail_state.dart';

class MailBloc extends Bloc<MailEvent, MailState> {
  MailBloc({EwsApi? api}) : _api = api ?? ewsApi, super(const MailState()) {
    on<MailSessionCleared>(_onSessionCleared);
    on<MailInboxLoadRequested>(_onInboxLoadRequested);
    on<MailInboxRefreshRequested>(_onInboxRefreshRequested);
    on<MailInboxLoadMoreRequested>(_onInboxLoadMoreRequested);
    on<MailInboxQueryChanged>(_onInboxQueryChanged);
    on<MailSearchQueryChanged>(_onSearchQueryChanged);
    on<MailConversationToggled>(_onConversationToggled);
    on<MailMessageActionRequested>(_onMessageActionRequested);
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
  int _sessionGeneration = 0;
  bool _backgroundRefreshInFlight = false;
  bool _backgroundRefreshQueued = false;

  void _onSessionCleared(MailSessionCleared event, Emitter<MailState> emit) {
    _inboxRequestGeneration++;
    _sessionGeneration++;
    _backgroundRefreshQueued = false;
    emit(const MailState());
  }

  // ─── Inbox loading ────────────────────────────────────────────────────────

  Future<void> _onInboxLoadRequested(
    MailInboxLoadRequested event,
    Emitter<MailState> emit,
  ) async {
    if (state.messages.isNotEmpty) {
      await _reloadInbox(emit, showAnimation: event.showAnimation);
      return;
    }
    if (event.showAnimation) {
      emit(state.copyWith(isLoading: true, errorMessage: () => null));
    }
    await _reloadInbox(emit, showAnimation: false);
  }

  Future<void> _onInboxRefreshRequested(
    MailInboxRefreshRequested event,
    Emitter<MailState> emit,
  ) async {
    if (event.showAnimation) {
      await _reloadInbox(emit, showAnimation: true);
      return;
    }
    // Exchange notifications arrive in bursts; the backend serializes a
    // session's Exchange calls, so overlapping reloads only pile up there.
    if (_backgroundRefreshInFlight) {
      _backgroundRefreshQueued = true;
      return;
    }
    _backgroundRefreshInFlight = true;
    final sessionGeneration = _sessionGeneration;
    try {
      await _reloadInbox(emit, showAnimation: false);
    } finally {
      _backgroundRefreshInFlight = false;
    }
    if (_backgroundRefreshQueued && sessionGeneration == _sessionGeneration) {
      _backgroundRefreshQueued = false;
      add(const MailInboxRefreshRequested());
    }
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

    emit(state.copyWith(isLoadingMore: true, loadMoreErrorMessage: () => null));
    final generation = ++_inboxRequestGeneration;

    try {
      final batch = await _api.fetchInbox(
        limit: _pageSize,
        offset: state.messages.length,
        filter: state.filter,
        sort: state.sort,
        folderId: state.selectedFolderId,
        search: state.searchQuery,
      );
      if (generation != _inboxRequestGeneration) return;

      emit(
        state.copyWith(
          isLoadingMore: false,
          messages: [...state.messages, ...batch],
          hasMoreMessages: batch.length >= _pageSize,
          loadMoreErrorMessage: () => null,
        ),
      );
    } catch (error) {
      if (generation != _inboxRequestGeneration) return;
      emit(
        state.copyWith(
          isLoadingMore: false,
          loadMoreErrorMessage: () =>
              error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onInboxQueryChanged(
    MailInboxQueryChanged event,
    Emitter<MailState> emit,
  ) async {
    final nextFilter = event.filter ?? state.filter;
    final nextSort = event.sort ?? state.sort;
    final nextFolderId = event.folderId ?? state.selectedFolderId;
    final showAnimation = nextFilter != state.filter || nextSort != state.sort;

    if (nextFilter == state.filter &&
        nextSort == state.sort &&
        nextFolderId == state.selectedFolderId) {
      return;
    }

    emit(
      state.copyWith(
        filter: nextFilter,
        sort: nextSort,
        selectedFolderId: () => nextFolderId,
        inboxQueryErrorMessage: () => null,
        // Clear selection when switching query
        selectedMessageIds: const {},
        isSelectionModeActive: false,
      ),
    );

    await _reloadInbox(emit, showAnimation: showAnimation);
  }

  Future<void> _onSearchQueryChanged(
    MailSearchQueryChanged event,
    Emitter<MailState> emit,
  ) async {
    final next = event.query.trim();
    if (next == state.searchQuery) return;
    emit(
      state.copyWith(
        searchQuery: next,
        selectedMessageIds: const {},
        isSelectionModeActive: false,
        inboxQueryErrorMessage: () => null,
      ),
    );
    await _reloadInbox(emit, showAnimation: true);
  }

  Future<void> _onConversationToggled(
    MailConversationToggled event,
    Emitter<MailState> emit,
  ) async {
    final index = state.messages.indexWhere(
      (message) => message.id == event.messageId,
    );
    if (index < 0) return;
    final message = state.messages[index];
    if (!message.canExpand) return;
    if (message.isExpanded) {
      emit(
        state.copyWith(
          messages: _replaceMessage(
            state.messages,
            index,
            message.copyWith(isExpanded: false),
          ),
        ),
      );
      return;
    }
    if (message.thread.isNotEmpty) {
      emit(
        state.copyWith(
          messages: _replaceMessage(
            state.messages,
            index,
            message.copyWith(isExpanded: true),
          ),
        ),
      );
      return;
    }
    final conversationId = message.conversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    emit(
      state.copyWith(
        messages: _replaceMessage(
          state.messages,
          index,
          message.copyWith(isExpanding: true),
        ),
      ),
    );
    try {
      final items = await _api.fetchConversationMessages(conversationId);
      final currentIndex = state.messages.indexWhere(
        (item) => item.id == event.messageId,
      );
      if (currentIndex < 0) return;
      final current = state.messages[currentIndex];
      final children = [
        for (final item in items)
          if (item.id != current.id) item,
      ];
      emit(
        state.copyWith(
          messages: _replaceMessage(
            state.messages,
            currentIndex,
            current.copyWith(
              isExpanding: false,
              isExpanded: true,
              thread: children,
              messageCount: children.length + 1,
            ),
          ),
        ),
      );
    } catch (error) {
      final currentIndex = state.messages.indexWhere(
        (item) => item.id == event.messageId,
      );
      if (currentIndex < 0) return;
      emit(
        state.copyWith(
          messages: _replaceMessage(
            state.messages,
            currentIndex,
            state.messages[currentIndex].copyWith(isExpanding: false),
          ),
          archiveErrorMessage: () =>
              error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onMessageActionRequested(
    MailMessageActionRequested event,
    Emitter<MailState> emit,
  ) async {
    final message = event.message;
    final previous = state.messages;
    final next = switch (event.action) {
      MailQuickAction.pin => _mapMessage(
        previous,
        message.id,
        (item) => item.copyWith(isPinned: !item.isPinned),
      ),
      MailQuickAction.flag => _mapMessage(
        previous,
        message.id,
        (item) => item.copyWith(isFlagged: !item.isFlagged),
      ),
      MailQuickAction.unread => _mapMessage(
        previous,
        message.id,
        (item) => item.copyWith(isRead: false),
      ),
      MailQuickAction.delete => _removeMessage(previous, message.id),
    };
    emit(state.copyWith(messages: next, archiveErrorMessage: () => null));
    try {
      final folderId = message.folderId.isEmpty
          ? state.selectedFolderId
          : message.folderId;
      final isTopLevel = previous.any((item) => item.id == message.id);
      switch (event.action) {
        case MailQuickAction.pin:
          await _api.pinMessage(message.id, pinned: !message.isPinned);
        case MailQuickAction.flag:
          await _api.setConversationFlag(
            conversationId: message.conversationId ?? '',
            folderId: folderId,
            flagged: !message.isFlagged,
            itemId: message.id,
          );
        case MailQuickAction.unread:
          await _api.markConversationUnread(
            conversationId: isTopLevel ? (message.conversationId ?? '') : '',
            folderId: folderId,
            itemId: message.id,
          );
        case MailQuickAction.delete:
          await _api.deleteConversation(
            conversationId: isTopLevel ? (message.conversationId ?? '') : '',
            folderId: folderId,
            itemId: message.id,
          );
      }
    } catch (error) {
      emit(
        state.copyWith(
          messages: previous,
          archiveErrorMessage: () =>
              error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _reloadInbox(
    Emitter<MailState> emit, {
    required bool showAnimation,
  }) async {
    final background = state.messages.isNotEmpty;
    final generation = ++_inboxRequestGeneration;
    final filter = state.filter;
    final sort = state.sort;
    var folderId = state.selectedFolderId;
    final previousSelected = state.selectedMessage;

    if (showAnimation) {
      emit(
        state.copyWith(
          isRefreshingInbox: true,
          inboxQueryErrorMessage: () => null,
          errorMessage: () => null,
        ),
      );
    }

    try {
      final foldersFuture = _api.fetchMailFolders();
      final search = state.searchQuery;
      final messagesFuture = _api.fetchInbox(
        limit: _pageSize,
        filter: filter,
        sort: sort,
        folderId: folderId,
        search: search,
      );

      final freshMessages = await messagesFuture;
      if (generation != _inboxRequestGeneration) return;

      var folders = state.folders;
      try {
        folders = await foldersFuture;
      } catch (_) {
        // Keep previously loaded folder tree if counts cannot be refreshed.
      }
      if (generation != _inboxRequestGeneration) return;
      if ((folderId == null || folderId.isEmpty) && folders != null) {
        folderId = folders.inboxFolderId;
      }

      // Merge fresh list with cached bodies to avoid losing loaded content.
      final mergedMessages = _smartMergeMessages(state.messages, freshMessages);

      // Skip updating the messages list if nothing actually changed —
      // this prevents unnecessary BlocBuilder rebuilds.
      final messagesChanged =
          !background || _hasMessagesChanged(state.messages, mergedMessages);

      final messagesForSelection = messagesChanged
          ? mergedMessages
          : state.messages;
      final updatedSelected = _resolveSelectedMessage(
        previousSelected,
        messagesForSelection,
        folderId,
      );

      emit(
        state.copyWith(
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
        ),
      );
    } catch (error) {
      if (generation != _inboxRequestGeneration) return;

      final message = error.toString().replaceFirst('Exception: ', '');
      if (background) {
        emit(
          state.copyWith(
            isRefreshingInbox: false,
            inboxQueryErrorMessage: () => message,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          isRefreshingInbox: false,
          errorMessage: () => message,
        ),
      );
    }
  }

  // ─── Message detail ───────────────────────────────────────────────────────

  Future<void> _onMessageSelected(
    MailMessageSelected event,
    Emitter<MailState> emit,
  ) async {
    final sessionGeneration = _sessionGeneration;
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
    emit(
      state.copyWith(
        selectedMessage: () => selected,
        messages: updatedMessages,
      ),
    );

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
      if (sessionGeneration != _sessionGeneration) return;
      final merged = _mergeDetail(updatedMessages, detail);
      final updatedSelected = merged.firstWhere((m) => m.id == detail.id);
      emit(
        state.copyWith(
          isLoadingDetail: false,
          selectedMessage: () => updatedSelected,
          messages: merged,
          errorMessage: () => null,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      emit(
        state.copyWith(
          isLoadingDetail: false,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onMessageSendRequested(
    MailMessageSendRequested event,
    Emitter<MailState> emit,
  ) async {
    final sessionGeneration = _sessionGeneration;
    emit(state.copyWith(isSending: true, errorMessage: () => null));
    try {
      await _api.sendMail(
        to: event.to,
        cc: event.cc,
        subject: event.subject,
        body: event.body,
      );
      if (sessionGeneration != _sessionGeneration) return;
      await _reloadInbox(emit, showAnimation: false);
      if (sessionGeneration != _sessionGeneration) return;
      emit(state.copyWith(isSending: false));
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      emit(
        state.copyWith(
          isSending: false,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  // ─── Multiple selection ───────────────────────────────────────────────────

  void _onSelectionModeEntered(
    MailSelectionModeEntered event,
    Emitter<MailState> emit,
  ) {
    emit(
      state.copyWith(
        isSelectionModeActive: true,
        archiveErrorMessage: () => null,
      ),
    );
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
    emit(
      state.copyWith(selectedMessageIds: ids, archiveErrorMessage: () => null),
    );
  }

  void _onSelectionCleared(
    MailSelectionCleared event,
    Emitter<MailState> emit,
  ) {
    emit(
      state.copyWith(
        selectedMessageIds: const {},
        isSelectionModeActive: false,
        archiveErrorMessage: () => null,
      ),
    );
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

    emit(
      state.copyWith(messages: updatedMessages, selectedMessageIds: const {}),
    );

    // Fire-and-forget: mark read on server
    final folderId = state.selectedFolderId;
    for (final id in ids) {
      _api.markMessageRead(id, folderId: folderId).catchError((_) => null);
    }
  }

  // ─── Archive ──────────────────────────────────────────────────────────────

  Future<void> _onArchiveRequested(
    MailArchiveRequested event,
    Emitter<MailState> emit,
  ) async {
    if (event.messageIds.isEmpty) return;
    final sessionGeneration = _sessionGeneration;

    emit(state.copyWith(isArchiving: true, archiveErrorMessage: () => null));

    try {
      final result = await _api.archiveMessages(
        event.messageIds,
        folderId: event.folderId,
      );
      if (sessionGeneration != _sessionGeneration) return;

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

      emit(
        state.copyWith(
          isArchiving: false,
          messages: updatedMessages,
          selectedMessage: () => updatedSelected,
          selectedMessageIds: updatedSelection,
          archiveErrorMessage: errorMsg != null ? () => errorMsg : () => null,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      emit(
        state.copyWith(
          isArchiving: false,
          archiveErrorMessage: () =>
              error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  // ─── Attachments ──────────────────────────────────────────────────────────

  Future<void> _onAttachmentDownloadRequested(
    MailAttachmentDownloadRequested event,
    Emitter<MailState> emit,
  ) async {
    final sessionGeneration = _sessionGeneration;
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
      if (sessionGeneration != _sessionGeneration) return;
      emit(
        state.copyWith(
          downloadErrorMessage: () =>
              error.toString().replaceFirst('Exception: ', ''),
        ),
      );
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

    final index = messages.indexWhere((item) => item.id == previousSelected.id);
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
    List<MailMessage> messages,
    MailMessage detail,
  ) {
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

    final currentMap = <String, MailMessage>{for (final m in current) m.id: m};

    return fresh.map((freshMsg) {
      final existing = currentMap[freshMsg.id];
      if (existing == null) return freshMsg;

      final hasCachedBody = existing.body != null && existing.body!.isNotEmpty;
      return freshMsg.copyWith(
        body: hasCachedBody ? existing.body : freshMsg.body,
        bodyType: hasCachedBody ? existing.bodyType : freshMsg.bodyType,
        hasAttachments: freshMsg.hasAttachments || existing.hasAttachments,
        attachments: existing.attachments.isNotEmpty
            ? existing.attachments
            : freshMsg.attachments,
        detailLoaded: existing.detailLoaded || freshMsg.detailLoaded,
        isPinned: existing.isPinned,
        isFlagged: existing.isFlagged || freshMsg.isFlagged,
        isExpanded: existing.isExpanded,
        thread: existing.thread,
        conversationId: freshMsg.conversationId ?? existing.conversationId,
      );
    }).toList();
  }

  List<MailMessage> _replaceMessage(
    List<MailMessage> messages,
    int index,
    MailMessage message,
  ) {
    return [
      for (var i = 0; i < messages.length; i++)
        if (i == index) message else messages[i],
    ];
  }

  List<MailMessage> _mapMessage(
    List<MailMessage> messages,
    String id,
    MailMessage Function(MailMessage message) update,
  ) {
    return [
      for (final message in messages)
        if (message.id == id)
          update(message)
        else if (message.thread.any((child) => child.id == id))
          message.copyWith(
            thread: [
              for (final child in message.thread)
                if (child.id == id) update(child) else child,
            ],
          )
        else
          message,
    ];
  }

  List<MailMessage> _removeMessage(List<MailMessage> messages, String id) {
    return [
      for (final message in messages)
        if (message.id == id)
          null
        else if (message.thread.any((child) => child.id == id))
          message.copyWith(
            thread: [
              for (final child in message.thread)
                if (child.id != id) child,
            ],
            messageCount: message.messageCount > 1
                ? message.messageCount - 1
                : 1,
          )
        else
          message,
    ].whereType<MailMessage>().toList();
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
          o.hasAttachments != n.hasAttachments ||
          o.isPinned != n.isPinned ||
          o.isFlagged != n.isFlagged ||
          o.messageCount != n.messageCount ||
          o.isExpanded != n.isExpanded) {
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

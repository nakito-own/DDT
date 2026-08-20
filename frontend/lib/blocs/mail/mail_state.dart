part of 'mail_bloc.dart';

final class MailState extends Equatable {
  const MailState({
    this.messages = const [],
    this.folders,
    this.selectedMessage,
    this.selectedFolderId,
    this.filter = MailInboxFilter.all,
    this.sort = MailInboxSort.dateDesc,
    this.isLoading = false,
    this.isRefreshingInbox = false,
    this.isLoadingMore = false,
    this.isLoadingDetail = false,
    this.isSending = false,
    this.isArchiving = false,
    this.hasMoreMessages = false,
    this.selectedMessageIds = const {},
    this.isSelectionModeActive = false,
    this.errorMessage,
    this.inboxQueryErrorMessage,
    this.loadMoreErrorMessage,
    this.archiveErrorMessage,
    this.downloadErrorMessage,
  });

  final List<MailMessage> messages;
  final MailFolders? folders;
  final MailMessage? selectedMessage;
  final String? selectedFolderId;
  final MailInboxFilter filter;
  final MailInboxSort sort;
  final bool isLoading;
  final bool isRefreshingInbox;
  final bool isLoadingMore;
  final bool isLoadingDetail;
  final bool isSending;
  final bool isArchiving;
  final bool hasMoreMessages;

  /// IDs писем в режиме множественного выбора.
  final Set<String> selectedMessageIds;

  /// Режим выбора включён кнопкой «Выделить» в аппбаре.
  final bool isSelectionModeActive;

  final String? errorMessage;
  final String? inboxQueryErrorMessage;
  final String? loadMoreErrorMessage;
  final String? archiveErrorMessage;
  final String? downloadErrorMessage;

  bool get isSelectionMode => isSelectionModeActive;

  MailState copyWith({
    List<MailMessage>? messages,
    MailFolders? Function()? folders,
    MailMessage? Function()? selectedMessage,
    String? Function()? selectedFolderId,
    MailInboxFilter? filter,
    MailInboxSort? sort,
    bool? isLoading,
    bool? isRefreshingInbox,
    bool? isLoadingMore,
    bool? isLoadingDetail,
    bool? isSending,
    bool? isArchiving,
    bool? hasMoreMessages,
    Set<String>? selectedMessageIds,
    bool? isSelectionModeActive,
    String? Function()? errorMessage,
    String? Function()? inboxQueryErrorMessage,
    String? Function()? loadMoreErrorMessage,
    String? Function()? archiveErrorMessage,
    String? Function()? downloadErrorMessage,
  }) {
    return MailState(
      messages: messages ?? this.messages,
      folders: folders != null ? folders() : this.folders,
      selectedMessage: selectedMessage != null
          ? selectedMessage()
          : this.selectedMessage,
      selectedFolderId: selectedFolderId != null
          ? selectedFolderId()
          : this.selectedFolderId,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      isLoading: isLoading ?? this.isLoading,
      isRefreshingInbox: isRefreshingInbox ?? this.isRefreshingInbox,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      isSending: isSending ?? this.isSending,
      isArchiving: isArchiving ?? this.isArchiving,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      selectedMessageIds: selectedMessageIds ?? this.selectedMessageIds,
      isSelectionModeActive:
          isSelectionModeActive ?? this.isSelectionModeActive,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      inboxQueryErrorMessage: inboxQueryErrorMessage != null
          ? inboxQueryErrorMessage()
          : this.inboxQueryErrorMessage,
      loadMoreErrorMessage: loadMoreErrorMessage != null
          ? loadMoreErrorMessage()
          : this.loadMoreErrorMessage,
      archiveErrorMessage: archiveErrorMessage != null
          ? archiveErrorMessage()
          : this.archiveErrorMessage,
      downloadErrorMessage: downloadErrorMessage != null
          ? downloadErrorMessage()
          : this.downloadErrorMessage,
    );
  }

  @override
  List<Object?> get props => [
    messages,
    folders,
    selectedMessage,
    selectedFolderId,
    filter,
    sort,
    isLoading,
    isRefreshingInbox,
    isLoadingMore,
    isLoadingDetail,
    isSending,
    isArchiving,
    hasMoreMessages,
    selectedMessageIds,
    isSelectionModeActive,
    errorMessage,
    inboxQueryErrorMessage,
    loadMoreErrorMessage,
    archiveErrorMessage,
    downloadErrorMessage,
  ];
}

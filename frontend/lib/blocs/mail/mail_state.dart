part of 'mail_bloc.dart';

final class MailState extends Equatable {
  const MailState({
    this.messages = const [],
    this.folders,
    this.selectedMessage,
    this.filter = MailInboxFilter.all,
    this.sort = MailInboxSort.dateDesc,
    this.isLoading = false,
    this.isRefreshingInbox = false,
    this.isLoadingMore = false,
    this.isLoadingDetail = false,
    this.isSending = false,
    this.hasMoreMessages = false,
    this.errorMessage,
    this.inboxQueryErrorMessage,
    this.loadMoreErrorMessage,
  });

  final List<MailMessage> messages;
  final MailFolders? folders;
  final MailMessage? selectedMessage;
  final MailInboxFilter filter;
  final MailInboxSort sort;
  final bool isLoading;
  final bool isRefreshingInbox;
  final bool isLoadingMore;
  final bool isLoadingDetail;
  final bool isSending;
  final bool hasMoreMessages;
  final String? errorMessage;
  final String? inboxQueryErrorMessage;
  final String? loadMoreErrorMessage;

  MailState copyWith({
    List<MailMessage>? messages,
    MailFolders? Function()? folders,
    MailMessage? Function()? selectedMessage,
    MailInboxFilter? filter,
    MailInboxSort? sort,
    bool? isLoading,
    bool? isRefreshingInbox,
    bool? isLoadingMore,
    bool? isLoadingDetail,
    bool? isSending,
    bool? hasMoreMessages,
    String? Function()? errorMessage,
    String? Function()? inboxQueryErrorMessage,
    String? Function()? loadMoreErrorMessage,
  }) {
    return MailState(
      messages: messages ?? this.messages,
      folders: folders != null ? folders() : this.folders,
      selectedMessage:
          selectedMessage != null ? selectedMessage() : this.selectedMessage,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      isLoading: isLoading ?? this.isLoading,
      isRefreshingInbox: isRefreshingInbox ?? this.isRefreshingInbox,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      isSending: isSending ?? this.isSending,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
      inboxQueryErrorMessage: inboxQueryErrorMessage != null
          ? inboxQueryErrorMessage()
          : this.inboxQueryErrorMessage,
      loadMoreErrorMessage: loadMoreErrorMessage != null
          ? loadMoreErrorMessage()
          : this.loadMoreErrorMessage,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        folders,
        selectedMessage,
        filter,
        sort,
        isLoading,
        isRefreshingInbox,
        isLoadingMore,
        isLoadingDetail,
        isSending,
        hasMoreMessages,
        errorMessage,
        inboxQueryErrorMessage,
        loadMoreErrorMessage,
      ];
}

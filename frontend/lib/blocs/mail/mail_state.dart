part of 'mail_bloc.dart';

final class MailState extends Equatable {
  const MailState({
    this.messages = const [],
    this.folders,
    this.selectedMessage,
    this.isLoading = false,
    this.isLoadingDetail = false,
    this.isSending = false,
    this.errorMessage,
  });

  final List<MailMessage> messages;
  final MailFolders? folders;
  final MailMessage? selectedMessage;
  final bool isLoading;
  final bool isLoadingDetail;
  final bool isSending;
  final String? errorMessage;

  MailState copyWith({
    List<MailMessage>? messages,
    MailFolders? Function()? folders,
    MailMessage? Function()? selectedMessage,
    bool? isLoading,
    bool? isLoadingDetail,
    bool? isSending,
    String? Function()? errorMessage,
  }) {
    return MailState(
      messages: messages ?? this.messages,
      folders: folders != null ? folders() : this.folders,
      selectedMessage:
          selectedMessage != null ? selectedMessage() : this.selectedMessage,
      isLoading: isLoading ?? this.isLoading,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      isSending: isSending ?? this.isSending,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        folders,
        selectedMessage,
        isLoading,
        isLoadingDetail,
        isSending,
        errorMessage,
      ];
}

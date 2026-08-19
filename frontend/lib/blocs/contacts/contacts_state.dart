part of 'contacts_bloc.dart';

final class ContactsState extends Equatable {
  const ContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
  });

  final List<Contact> contacts;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  ContactsState copyWith({
    List<Contact>? contacts,
    bool? isLoading,
    String? Function()? errorMessage,
    String? searchQuery,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [contacts, isLoading, errorMessage, searchQuery];
}

part of 'contacts_bloc.dart';

sealed class ContactsEvent extends Equatable {
  const ContactsEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузить список контактов при входе в раздел.
final class ContactsLoadRequested extends ContactsEvent {
  const ContactsLoadRequested({this.search});

  final String? search;

  @override
  List<Object?> get props => [search];
}

/// Пользователь изменил строку поиска.
final class ContactsSearchQueryChanged extends ContactsEvent {
  const ContactsSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/contact.dart';
import '../../services/ews_api.dart';

part 'contacts_event.dart';
part 'contacts_state.dart';

class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  ContactsBloc({EwsApi? api})
      : _api = api ?? ewsApi,
        super(const ContactsState()) {
    on<ContactsLoadRequested>(_onLoadRequested);
    on<ContactsSearchQueryChanged>(_onSearchQueryChanged);
  }

  final EwsApi _api;

  Future<void> _onLoadRequested(
    ContactsLoadRequested event,
    Emitter<ContactsState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      errorMessage: () => null,
      searchQuery: event.search ?? state.searchQuery,
    ));

    try {
      final query = event.search ?? state.searchQuery;
      final result = await _api.fetchContacts(
        search: query,
      );
      emit(state.copyWith(
        isLoading: false,
        contacts: result,
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

  void _onSearchQueryChanged(
    ContactsSearchQueryChanged event,
    Emitter<ContactsState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
    add(ContactsLoadRequested(search: event.query));
  }
}

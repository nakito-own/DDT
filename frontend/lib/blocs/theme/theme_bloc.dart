import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';

part 'theme_event.dart';
part 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc({required GetStorage storage})
    : _storage = storage,
      super(const ThemeState()) {
    on<ThemeLoadRequested>(_onLoadRequested);
    on<ThemeToggleRequested>(_onToggleRequested);
  }

  static const _storageKey = 'theme_mode';

  final GetStorage _storage;

  void _onLoadRequested(ThemeLoadRequested event, Emitter<ThemeState> emit) {
    final saved = _storage.read<String>(_storageKey);
    final mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    emit(state.copyWith(mode: mode));
  }

  void _onToggleRequested(
    ThemeToggleRequested event,
    Emitter<ThemeState> emit,
  ) {
    final newMode = state.isDarkMode ? ThemeMode.light : ThemeMode.dark;
    _storage.write(_storageKey, newMode == ThemeMode.dark ? 'dark' : 'light');
    emit(state.copyWith(mode: newMode));
  }
}

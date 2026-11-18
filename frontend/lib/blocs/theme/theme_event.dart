part of 'theme_bloc.dart';

sealed class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузить сохранённую тему из хранилища при старте приложения.
final class ThemeLoadRequested extends ThemeEvent {
  const ThemeLoadRequested();
}

/// Переключить тему между светлой и тёмной.
final class ThemeToggleRequested extends ThemeEvent {
  const ThemeToggleRequested();
}

/// Включить или выключить сезонный снег.
final class ThemeSnowChanged extends ThemeEvent {
  const ThemeSnowChanged(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

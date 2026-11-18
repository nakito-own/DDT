part of 'theme_bloc.dart';

final class ThemeState extends Equatable {
  const ThemeState({this.mode = ThemeMode.light, this.snowEnabled = true});

  final ThemeMode mode;
  final bool snowEnabled;

  bool get isDarkMode => mode == ThemeMode.dark;

  ThemeState copyWith({ThemeMode? mode, bool? snowEnabled}) {
    return ThemeState(
      mode: mode ?? this.mode,
      snowEnabled: snowEnabled ?? this.snowEnabled,
    );
  }

  @override
  List<Object?> get props => [mode, snowEnabled];
}

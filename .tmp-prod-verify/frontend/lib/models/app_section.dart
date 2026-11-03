import '../router/route_paths.dart';
import '../theme/ddt_icons.dart';

enum AppSection {
  tasks(label: 'Задачи', icon: DdtIcons.tasks),
  mail(label: 'Почта', icon: DdtIcons.mail),
  calendar(label: 'Календарь', icon: DdtIcons.calendar),
  contacts(label: 'Контакты', icon: DdtIcons.contacts),
  analytics(label: 'Аналитика', icon: DdtIcons.analytics),
  space(label: 'Пространство', icon: DdtIcons.grid),
  notes(label: 'Заметки', icon: DdtIcons.penToSquare),
  boards(label: 'Доски', icon: DdtIcons.boards),
  settings(label: 'Настройки', icon: DdtIcons.settings),
  more(label: 'Дополнения', icon: DdtIcons.additions);

  const AppSection({required this.label, required this.icon});

  final String label;
  final FaIconData icon;

  /// URL-путь этой секции для GoRouter.
  String get routePath => switch (this) {
    AppSection.tasks => RoutePaths.tasksList,
    AppSection.mail => RoutePaths.mail,
    AppSection.calendar => RoutePaths.calendar,
    AppSection.contacts => RoutePaths.contacts,
    AppSection.analytics => RoutePaths.analytics,
    AppSection.space => RoutePaths.space,
    AppSection.notes => RoutePaths.notes,
    AppSection.boards => RoutePaths.boards,
    AppSection.settings => RoutePaths.settings,
    AppSection.more => RoutePaths.more,
  };

  /// Определяет активную секцию по текущему URL-пути.
  ///
  /// Используется в [MainShellPage] для синхронизации подсветки
  /// навигационного рейла с текущим маршрутом.
  static AppSection fromRoute(String location) {
    if (location.startsWith(RoutePaths.tasks)) return AppSection.tasks;
    if (location.startsWith(RoutePaths.mail)) return AppSection.mail;
    if (location.startsWith(RoutePaths.calendar)) return AppSection.calendar;
    if (location.startsWith(RoutePaths.contacts)) return AppSection.contacts;
    if (location.startsWith(RoutePaths.analytics)) return AppSection.analytics;
    if (location.startsWith(RoutePaths.space)) return AppSection.space;
    if (location.startsWith(RoutePaths.notes) ||
        location.startsWith(RoutePaths.linkArchive)) {
      return AppSection.notes;
    }
    if (location.startsWith(RoutePaths.boards)) return AppSection.boards;
    if (location.startsWith(RoutePaths.settings)) return AppSection.settings;
    if (location == RoutePaths.more ||
        location.startsWith('${RoutePaths.more}/')) {
      return AppSection.more;
    }
    return AppSection.tasks;
  }
}

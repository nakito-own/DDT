import '../router/route_paths.dart';
import '../theme/ddt_icons.dart';

enum AppSection {
  tasks(label: 'Задачи', icon: DdtIcons.tasks),
  mail(label: 'Почта', icon: DdtIcons.mail),
  calendar(label: 'Календарь', icon: DdtIcons.calendar),
  contacts(label: 'Контакты', icon: DdtIcons.contacts),
  analytics(label: 'Аналитика', icon: DdtIcons.analytics),
  space(label: 'Пространство', icon: DdtIcons.grid),
  automations(label: 'Автоматизации', icon: DdtIcons.automations),
  notes(label: 'Заметки', icon: DdtIcons.penToSquare),
  settings(label: 'Настройки', icon: DdtIcons.settings);

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
    AppSection.automations => RoutePaths.automations,
    AppSection.notes => RoutePaths.notes,
    AppSection.settings => RoutePaths.settings,
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
    if (location.startsWith(RoutePaths.automations)) {
      return AppSection.automations;
    }
    if (location.startsWith(RoutePaths.notes) ||
        location.startsWith(RoutePaths.linkArchive)) {
      return AppSection.notes;
    }
    if (location.startsWith(RoutePaths.settings)) return AppSection.settings;
    return AppSection.tasks;
  }
}

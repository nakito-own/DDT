import 'package:flutter/cupertino.dart';

import '../router/route_paths.dart';

enum AppSection {
  tasks(
    label: 'Задачи',
    icon: CupertinoIcons.checkmark_square,
  ),
  mail(
    label: 'Почта',
    icon: CupertinoIcons.mail,
  ),
  calendar(
    label: 'Календарь',
    icon: CupertinoIcons.calendar,
  ),
  contacts(
    label: 'Контакты',
    icon: CupertinoIcons.person_2,
  ),
  space(
    label: 'Пространство',
    icon: CupertinoIcons.square_grid_2x2,
  ),
  automations(
    label: 'Автоматизации',
    icon: CupertinoIcons.bolt_horizontal,
  ),
  linkArchive(
    label: 'Архив ссылок',
    icon: CupertinoIcons.link,
  ),
  settings(
    label: 'Настройки',
    icon: CupertinoIcons.settings,
  );

  const AppSection({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  /// URL-путь этой секции для GoRouter.
  String get routePath => switch (this) {
        AppSection.tasks => RoutePaths.tasksKanban,
        AppSection.mail => RoutePaths.mail,
        AppSection.calendar => RoutePaths.calendar,
        AppSection.contacts => RoutePaths.contacts,
        AppSection.space => RoutePaths.space,
        AppSection.automations => RoutePaths.automations,
        AppSection.linkArchive => RoutePaths.linkArchive,
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
    if (location.startsWith(RoutePaths.space)) return AppSection.space;
    if (location.startsWith(RoutePaths.automations)) {
      return AppSection.automations;
    }
    if (location.startsWith(RoutePaths.linkArchive)) {
      return AppSection.linkArchive;
    }
    if (location.startsWith(RoutePaths.settings)) return AppSection.settings;
    return AppSection.tasks;
  }
}

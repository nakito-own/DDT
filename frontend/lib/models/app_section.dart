import 'package:flutter/cupertino.dart';

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
}

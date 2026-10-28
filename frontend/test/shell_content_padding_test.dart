import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/models/app_section.dart';
import 'package:ddt_frontend/models/tasks_view_mode.dart';
import 'package:ddt_frontend/screens/main_shell_page.dart';

void main() {
  setUp(() {
    TasksViewMode.fromRoute('/tasks/list');
  });

  test('kanban inset stays on the board and on a task opened from it', () {
    TasksViewMode.fromRoute('/tasks/kanban');

    expect(
      MainShellPage.padsContentFor(AppSection.tasks, '/tasks/kanban'),
      isFalse,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.tasks, '/tasks/DDT-12'),
      isFalse,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.tasks, '/tasks/new'),
      isFalse,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.space, '/space/TEST/kanban'),
      isFalse,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.space, '/space/TEST-3'),
      isFalse,
    );
  });

  test('leaving kanban restores top padding on every other section', () {
    TasksViewMode.fromRoute('/tasks/kanban');

    expect(
      MainShellPage.padsContentFor(AppSection.mail, '/mail'),
      isTrue,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.calendar, '/calendar'),
      isTrue,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.notes, '/notes'),
      isTrue,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.boards, '/boards'),
      isTrue,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.analytics, '/analytics'),
      isTrue,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.settings, '/settings'),
      isTrue,
    );
  });

  test('list and gantt keep the normal content inset', () {
    expect(
      MainShellPage.padsContentFor(AppSection.tasks, '/tasks/list'),
      isTrue,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.tasks, '/tasks/gantt'),
      isTrue,
    );
    expect(
      MainShellPage.padsContentFor(AppSection.tasks, '/tasks/DDT-12'),
      isTrue,
    );
  });
}

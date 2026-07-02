enum TasksViewMode {
  kanban('Канбан'),
  list('Список'),
  gantt('Гант');

  const TasksViewMode(this.label);

  final String label;
}

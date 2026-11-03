enum TaskStatus {
  todo('todo', 'Запланировано'),
  inProgress('in_progress', 'В работе'),
  done('done', 'Готово');

  const TaskStatus(this.value, this.label);

  final String value;
  final String label;

  static TaskStatus fromValue(String value) {
    return TaskStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => TaskStatus.todo,
    );
  }
}

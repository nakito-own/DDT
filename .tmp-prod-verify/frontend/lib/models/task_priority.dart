enum TaskPriority {
  insignificant('insignificant', 'Незначительный'),
  low('low', 'Низкий'),
  medium('medium', 'Средний'),
  high('high', 'Высокий'),
  blocker('blocker', 'Блокер');

  const TaskPriority(this.value, this.label);

  final String value;
  final String label;

  static TaskPriority? fromValue(String? value) {
    if (value == null) return null;
    for (final item in TaskPriority.values) {
      if (item.value == value) return item;
    }
    return null;
  }
}

class TaskStatus {
  const TaskStatus(this.value, this.label, [this.category = 'open', this.id]);

  final String value;
  final String label;
  final String category;
  final int? id;

  static const todo = TaskStatus('todo', 'Запланировано', 'open');
  static const inProgress = TaskStatus('in_progress', 'В работе', 'active');
  static const done = TaskStatus('done', 'Готово', 'closed');
  static const values = <TaskStatus>[todo, inProgress, done];

  bool get isOpen => category == 'open';
  bool get isActive => category == 'active';
  bool get isClosed => category == 'closed';

  static TaskStatus fromValue(
    String value, {
    String? label,
    String? category,
    int? id,
  }) {
    for (final item in values) {
      if (item.value != value) continue;
      if (label == null && category == null && id == null) return item;
      return TaskStatus(
        value,
        label ?? item.label,
        category ?? item.category,
        id,
      );
    }
    return TaskStatus(value, label ?? value, category ?? 'open', id);
  }

  static TaskStatus fromQueueJson(Map<String, dynamic> json) {
    return TaskStatus(
      json['key'] as String? ?? json['value'] as String? ?? 'todo',
      json['name'] as String? ?? json['label'] as String? ?? 'Статус',
      json['category'] as String? ?? 'open',
      json['id'] as int?,
    );
  }

  Map<String, dynamic> toQueueJson() {
    return {
      if (id != null) 'id': id,
      'key': value,
      'name': label,
      'category': category,
      'is_system': value == 'todo' || value == 'in_progress' || value == 'done',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is TaskStatus && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

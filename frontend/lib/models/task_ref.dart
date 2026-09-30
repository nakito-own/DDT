import 'task_status.dart';

class TaskRef {
  const TaskRef({
    required this.id,
    required this.key,
    required this.title,
    required this.status,
  });

  final int id;
  final String key;
  final String title;
  final TaskStatus status;

  factory TaskRef.fromJson(Map<String, dynamic> json) {
    return TaskRef(
      id: json['id'] as int,
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: TaskStatus.fromValue(json['status'] as String? ?? 'todo'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'title': title,
      'status': status.value,
    };
  }
}

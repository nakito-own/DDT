class TaskType {
  TaskType({required this.id, required this.name, this.createdAt});

  final int id;
  final String name;
  final DateTime? createdAt;

  factory TaskType.fromJson(Map<String, dynamic> json) {
    return TaskType(
      id: json['id'] as int,
      name: json['name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

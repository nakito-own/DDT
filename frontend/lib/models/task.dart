import 'task_comment.dart';
import 'task_link.dart';
import 'task_priority.dart';
import 'task_status.dart';
import 'task_type.dart';

class Task {
  Task({
    required this.id,
    required this.title,
    required this.status,
    required this.timeSet,
    this.typeId,
    this.type,
    this.description = '',
    this.executorId,
    this.authorId,
    this.responsibleId,
    this.ownerId,
    this.timeStart,
    this.timeEnd,
    this.deadline,
    this.priority,
    this.links,
    this.comments = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final TaskStatus status;
  final int? typeId;
  final TaskType? type;
  final String description;
  final int? executorId;
  final int? authorId;
  final int? responsibleId;
  final int? ownerId;
  final DateTime timeSet;
  final DateTime? timeStart;
  final DateTime? timeEnd;
  final DateTime? deadline;
  final TaskPriority? priority;
  final List<TaskLink>? links;
  final List<TaskComment> comments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Task.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['links'] as List<dynamic>?;
    final rawComments = json['comments'] as List<dynamic>?;

    return Task(
      id: json['id'] as int,
      title: json['title'] as String,
      status: TaskStatus.fromValue(json['status'] as String),
      typeId: json['type_id'] as int?,
      type: json['type'] != null
          ? TaskType.fromJson(json['type'] as Map<String, dynamic>)
          : null,
      description: json['description'] as String? ?? '',
      executorId: json['executor_id'] as int?,
      authorId: json['author_id'] as int?,
      responsibleId: json['responsible_id'] as int?,
      ownerId: json['owner_id'] as int?,
      timeSet: DateTime.parse(json['time_set'] as String),
      timeStart: json['time_start'] != null
          ? DateTime.parse(json['time_start'] as String)
          : null,
      timeEnd: json['time_end'] != null
          ? DateTime.parse(json['time_end'] as String)
          : null,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      priority: TaskPriority.fromValue(json['priority'] as String?),
      links: rawLinks
          ?.map((item) => TaskLink.fromJson(item as Map<String, dynamic>))
          .toList(),
      comments: rawComments
              ?.map((item) => TaskComment.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status.value,
      if (typeId != null) 'type_id': typeId,
      if (type != null) 'type': type!.toJson(),
      'description': description,
      if (executorId != null) 'executor_id': executorId,
      if (authorId != null) 'author_id': authorId,
      if (responsibleId != null) 'responsible_id': responsibleId,
      if (ownerId != null) 'owner_id': ownerId,
      'time_set': timeSet.toIso8601String(),
      if (timeStart != null) 'time_start': timeStart!.toIso8601String(),
      if (timeEnd != null) 'time_end': timeEnd!.toIso8601String(),
      if (deadline != null) 'deadline': deadline!.toIso8601String(),
      if (priority != null) 'priority': priority!.value,
      if (links != null) 'links': links!.map((link) => link.toJson()).toList(),
      'comments': comments.map((comment) => comment.toJson()).toList(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Task copyWith({
    String? title,
    TaskStatus? status,
    int? typeId,
    TaskType? type,
    String? description,
    int? executorId,
    int? authorId,
    int? responsibleId,
    DateTime? timeSet,
    DateTime? timeStart,
    DateTime? timeEnd,
    DateTime? deadline,
    TaskPriority? priority,
    List<TaskLink>? links,
    List<TaskComment>? comments,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      typeId: typeId ?? this.typeId,
      type: type ?? this.type,
      description: description ?? this.description,
      executorId: executorId ?? this.executorId,
      authorId: authorId ?? this.authorId,
      responsibleId: responsibleId ?? this.responsibleId,
      timeSet: timeSet ?? this.timeSet,
      timeStart: timeStart ?? this.timeStart,
      timeEnd: timeEnd ?? this.timeEnd,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      links: links ?? this.links,
      comments: comments ?? this.comments,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

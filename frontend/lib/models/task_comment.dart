class TaskComment {
  TaskComment({
    required this.id,
    required this.text,
    this.authorId,
    this.createdAt,
  });

  final int id;
  final String text;
  final int? authorId;
  final DateTime? createdAt;

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    return TaskComment(
      id: json['id'] as int,
      text: json['text'] as String,
      authorId: json['author_id'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      if (authorId != null) 'author_id': authorId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

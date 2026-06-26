class TaskLink {
  TaskLink({
    required this.id,
    required this.url,
    this.title,
  });

  final int id;
  final String url;
  final String? title;

  factory TaskLink.fromJson(Map<String, dynamic> json) {
    return TaskLink(
      id: json['id'] as int,
      url: json['url'] as String,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      if (title != null) 'title': title,
    };
  }
}

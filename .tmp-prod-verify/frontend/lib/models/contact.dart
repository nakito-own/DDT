class Contact {
  const Contact({
    required this.id,
    required this.displayName,
    required this.emails,
    required this.phones,
  });

  final String id;
  final String displayName;
  final List<String> emails;
  final List<String> phones;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Без имени',
      emails: (json['emails'] as List<dynamic>? ?? [])
          .map((item) => item as String)
          .toList(),
      phones: (json['phones'] as List<dynamic>? ?? [])
          .map((item) => item as String)
          .toList(),
    );
  }
}

import '../models/user_profile.dart';
import 'api_client.dart';

Future<List<UserProfile>>? _directoryUsersFuture;

/// Registered users from the application database.
Future<List<UserProfile>> loadDirectoryUsers() {
  return _directoryUsersFuture ??= () async {
    final rows = await fetchUsers();
    final users = <UserProfile>[];
    for (final row in rows) {
      final idValue = row['id'];
      if (idValue is! num) continue;
      final name = (row['name'] as String?)?.trim() ?? '';
      final displayName = (row['display_name'] as String?)?.trim();
      final label = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : name;
      if (label.isEmpty) continue;
      users.add(
        UserProfile(
          id: idValue.toInt(),
          name: name.isEmpty ? label : name,
          email: (row['email'] as String?)?.trim() ?? '',
          displayName: displayName,
        ),
      );
    }
    users.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return users;
  }();
}

UserProfile? directoryUserById(List<UserProfile> users, int? id) {
  if (id == null) return null;
  for (final user in users) {
    if (user.id == id) return user;
  }
  return null;
}

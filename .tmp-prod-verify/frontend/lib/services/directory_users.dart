import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import 'api_client.dart';

/// Bumped whenever the cached directory changes, including avatar updates.
final directoryUsersRevision = ValueNotifier<int>(0);

List<UserProfile>? _directoryUsers;
Future<List<UserProfile>>? _directoryUsersFuture;

/// Registered users from the application database.
Future<List<UserProfile>> loadDirectoryUsers() {
  return _directoryUsersFuture ??= _fetchDirectoryUsers();
}

Future<List<UserProfile>> _fetchDirectoryUsers() async {
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
    final version = row['avatar_version'];
    users.add(
      UserProfile(
        id: idValue.toInt(),
        name: name.isEmpty ? label : name,
        email: (row['email'] as String?)?.trim() ?? '',
        displayName: displayName,
        avatarVersion: version is num ? version.toInt() : null,
      ),
    );
  }
  users.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  _directoryUsers = users;
  return users;
}

void publishDirectoryUserAvatar(UserProfile user) {
  final users = _directoryUsers;
  if (users != null) {
    final index = users.indexWhere((item) => item.id == user.id);
    if (index >= 0) {
      users[index] = users[index].copyWith(avatarVersion: user.avatarVersion);
    }
  } else {
    _directoryUsersFuture = null;
  }
  directoryUsersRevision.value++;
}

UserProfile? directoryUserById(List<UserProfile> users, int? id) {
  if (id == null) return null;
  for (final user in users) {
    if (user.id == id) return user;
  }
  return null;
}

UserProfile? directoryUserMatching({int? id, String? email, String? name}) {
  final users = _directoryUsers;
  if (users == null || users.isEmpty) return null;
  if (id != null) {
    for (final user in users) {
      if (user.id == id) return user;
    }
  }

  final mail = _normalizeEmail(email) ?? _emailInside(name);
  if (mail != null) {
    for (final user in users) {
      if (user.email.toLowerCase() == mail) return user;
    }
  }

  final label = name?.trim().toLowerCase();
  if (label == null || label.isEmpty || label == '—') return null;
  for (final user in users) {
    if (user.label.toLowerCase() == label ||
        user.name.toLowerCase() == label ||
        user.email.toLowerCase() == label) {
      return user;
    }
  }
  return null;
}

String? _normalizeEmail(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || !trimmed.contains('@')) return null;
  return trimmed;
}

String? _emailInside(String? value) {
  if (value == null) return null;
  final match = RegExp(r'<([^>]+@[^>]+)>').firstMatch(value);
  final embedded = match?.group(1)?.trim().toLowerCase();
  if (embedded != null && embedded.contains('@')) return embedded;
  return _normalizeEmail(value);
}

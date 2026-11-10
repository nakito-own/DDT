String? usernameFromEmail(String email) {
  final trimmed = email.trim();
  final separator = trimmed.indexOf('@');
  if (separator <= 0) {
    return null;
  }
  final username = trimmed.substring(0, separator).trim();
  return username.isEmpty ? null : username;
}

final _zoneSuffix = RegExp(r'(Z|z|[+-]\d{2}:?\d{2})$');

/// The tasks API serialises timestamps as naive UTC. `DateTime.parse` would
/// read those as local time and shift every value by the user's offset, so an
/// offset-less string is explicitly treated as UTC.
DateTime parseApiDateTime(String value) {
  final normalized = _zoneSuffix.hasMatch(value) ? value : '${value}Z';
  return DateTime.parse(normalized).toLocal();
}

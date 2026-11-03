String formatAnalyticsDuration(double? hours) {
  if (hours == null) return '—';
  if (hours < 24) return '${hours.round()} ч';
  return '${(hours / 24).round()} д';
}

String formatAnalyticsReaction(double? hours) {
  if (hours == null) return '—';
  if (hours < 1) return '${(hours * 60).round()} мин';
  if (hours < 24) return '${hours.toStringAsFixed(1)} ч';
  return '${(hours / 24).toStringAsFixed(1)} д';
}

String formatAnalyticsHoursAxis(double hours) {
  if (hours < 24) return '${hours.round()} ч';
  return '${(hours / 24).toStringAsFixed(1)} д';
}

String formatAnalyticsShare(double percent) => '${percent.toStringAsFixed(1)}%';

String formatAnalyticsDate(DateTime? value) {
  if (value == null) return '—';
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  return '$d.$m.${value.year}';
}

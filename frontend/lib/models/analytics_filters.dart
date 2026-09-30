import 'package:equatable/equatable.dart';

import 'analytics_dashboard.dart';

class AnalyticsFilters extends Equatable {
  const AnalyticsFilters({
    this.dateColumnKey,
    this.periodStart,
    this.periodEnd,
    this.selectedValues = const {},
    this.queries = const {},
  });

  final String? dateColumnKey;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final Map<String, Set<String>> selectedValues;
  final Map<String, String> queries;

  bool get hasPeriod => periodStart != null || periodEnd != null;

  bool get hasColumnFilters =>
      selectedValues.values.any((values) => values.isNotEmpty) ||
      queries.values.any((query) => query.trim().isNotEmpty);

  AnalyticsFilters copyWith({
    String? Function()? dateColumnKey,
    DateTime? Function()? periodStart,
    DateTime? Function()? periodEnd,
    Map<String, Set<String>>? selectedValues,
    Map<String, String>? queries,
  }) {
    return AnalyticsFilters(
      dateColumnKey: dateColumnKey != null
          ? dateColumnKey()
          : this.dateColumnKey,
      periodStart: periodStart != null ? periodStart() : this.periodStart,
      periodEnd: periodEnd != null ? periodEnd() : this.periodEnd,
      selectedValues: selectedValues ?? this.selectedValues,
      queries: queries ?? this.queries,
    );
  }

  AnalyticsFilters toggleValue(String columnKey, String valueKey) {
    final current = {...(selectedValues[columnKey] ?? <String>{})};
    if (!current.add(valueKey)) {
      current.remove(valueKey);
    }
    final next = Map<String, Set<String>>.from(selectedValues);
    if (current.isEmpty) {
      next.remove(columnKey);
    } else {
      next[columnKey] = current;
    }
    return copyWith(selectedValues: next);
  }

  AnalyticsFilters setQuery(String columnKey, String query) {
    final next = Map<String, String>.from(queries);
    if (query.trim().isEmpty) {
      next.remove(columnKey);
    } else {
      next[columnKey] = query;
    }
    return copyWith(queries: next);
  }

  /// Drops filters by columns that disappeared from the sheet.
  AnalyticsFilters prunedTo(List<AnalyticsColumn> columns) {
    final keys = {for (final column in columns) column.key};
    return copyWith(
      dateColumnKey: () => dateColumnKey != null && keys.contains(dateColumnKey)
          ? dateColumnKey
          : null,
      selectedValues: {
        for (final entry in selectedValues.entries)
          if (keys.contains(entry.key)) entry.key: entry.value,
      },
      queries: {
        for (final entry in queries.entries)
          if (keys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  Map<String, dynamic> toQueryJson() {
    return {
      'date_column': ?dateColumnKey,
      'period_start': ?_isoDay(periodStart),
      'period_end': ?_isoDay(periodEnd),
      'selected': {
        for (final entry in selectedValues.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
      },
      'queries': {
        for (final entry in queries.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      },
    };
  }

  static String? _isoDay(DateTime? value) {
    if (value == null) return null;
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  List<Object?> get props => [
    dateColumnKey,
    periodStart,
    periodEnd,
    selectedValues,
    queries,
  ];
}

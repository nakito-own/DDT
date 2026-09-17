part of 'analytics_bloc.dart';

sealed class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

final class AnalyticsLoadRequested extends AnalyticsEvent {
  const AnalyticsLoadRequested();
}

final class AnalyticsRefreshRequested extends AnalyticsEvent {
  const AnalyticsRefreshRequested();
}

final class AnalyticsDateColumnChanged extends AnalyticsEvent {
  const AnalyticsDateColumnChanged(this.columnKey);

  final String columnKey;

  @override
  List<Object?> get props => [columnKey];
}

final class AnalyticsPeriodChanged extends AnalyticsEvent {
  const AnalyticsPeriodChanged({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  @override
  List<Object?> get props => [start, end];
}

final class AnalyticsColumnValueToggled extends AnalyticsEvent {
  const AnalyticsColumnValueToggled({
    required this.columnKey,
    required this.valueKey,
  });

  final String columnKey;
  final String valueKey;

  @override
  List<Object?> get props => [columnKey, valueKey];
}

final class AnalyticsColumnQueryChanged extends AnalyticsEvent {
  const AnalyticsColumnQueryChanged({
    required this.columnKey,
    required this.query,
  });

  final String columnKey;
  final String query;

  @override
  List<Object?> get props => [columnKey, query];
}

final class AnalyticsFiltersCleared extends AnalyticsEvent {
  const AnalyticsFiltersCleared();
}

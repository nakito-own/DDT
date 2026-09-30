part of 'analytics_bloc.dart';

final class AnalyticsState extends Equatable {
  const AnalyticsState({
    this.dashboard,
    this.filters = const AnalyticsFilters(),
    this.tableLimit = AnalyticsBloc.tablePageSize,
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final AnalyticsDashboard? dashboard;
  final AnalyticsFilters filters;
  final int tableLimit;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;

  AnalyticsState copyWith({
    AnalyticsDashboard? dashboard,
    AnalyticsFilters? filters,
    int? tableLimit,
    bool? isLoading,
    bool? isRefreshing,
    String? Function()? errorMessage,
  }) {
    return AnalyticsState(
      dashboard: dashboard ?? this.dashboard,
      filters: filters ?? this.filters,
      tableLimit: tableLimit ?? this.tableLimit,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    dashboard,
    filters,
    tableLimit,
    isLoading,
    isRefreshing,
    errorMessage,
  ];
}

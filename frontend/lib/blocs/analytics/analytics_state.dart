part of 'analytics_bloc.dart';

final class AnalyticsState extends Equatable {
  const AnalyticsState({
    this.dashboard,
    this.filters = const AnalyticsFilters(),
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final AnalyticsDashboard? dashboard;
  final AnalyticsFilters filters;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;

  AnalyticsDashboard? get visibleDashboard {
    final source = dashboard;
    if (source == null) return null;
    return AnalyticsAggregator.filter(source, filters);
  }

  AnalyticsState copyWith({
    AnalyticsDashboard? dashboard,
    AnalyticsFilters? filters,
    bool? isLoading,
    bool? isRefreshing,
    String? Function()? errorMessage,
  }) {
    return AnalyticsState(
      dashboard: dashboard ?? this.dashboard,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    dashboard,
    filters,
    isLoading,
    isRefreshing,
    errorMessage,
  ];
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/analytics_dashboard.dart';
import '../../models/analytics_filters.dart';
import '../../services/analytics_aggregator.dart';
import '../../services/analytics_api.dart';

part 'analytics_event.dart';
part 'analytics_state.dart';

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc({AnalyticsApi? api})
    : _api = api ?? analyticsApi,
      super(const AnalyticsState()) {
    on<AnalyticsLoadRequested>(_onLoadRequested);
    on<AnalyticsRefreshRequested>(_onRefreshRequested);
    on<AnalyticsDateColumnChanged>(_onDateColumnChanged);
    on<AnalyticsPeriodChanged>(_onPeriodChanged);
    on<AnalyticsColumnValueToggled>(_onColumnValueToggled);
    on<AnalyticsColumnQueryChanged>(_onColumnQueryChanged);
    on<AnalyticsFiltersCleared>(_onFiltersCleared);
  }

  final AnalyticsApi _api;

  Future<void> _onLoadRequested(
    AnalyticsLoadRequested event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    await _fetch(emit, refresh: false);
  }

  Future<void> _onRefreshRequested(
    AnalyticsRefreshRequested event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, errorMessage: () => null));
    await _fetch(emit, refresh: true);
  }

  void _onDateColumnChanged(
    AnalyticsDateColumnChanged event,
    Emitter<AnalyticsState> emit,
  ) {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(dateColumnKey: () => event.columnKey),
      ),
    );
  }

  void _onPeriodChanged(
    AnalyticsPeriodChanged event,
    Emitter<AnalyticsState> emit,
  ) {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(
          periodStart: () => event.start,
          periodEnd: () => event.end,
        ),
      ),
    );
  }

  void _onColumnValueToggled(
    AnalyticsColumnValueToggled event,
    Emitter<AnalyticsState> emit,
  ) {
    emit(
      state.copyWith(
        filters: state.filters.toggleValue(event.columnKey, event.valueKey),
      ),
    );
  }

  void _onColumnQueryChanged(
    AnalyticsColumnQueryChanged event,
    Emitter<AnalyticsState> emit,
  ) {
    emit(
      state.copyWith(
        filters: state.filters.setQuery(event.columnKey, event.query),
      ),
    );
  }

  void _onFiltersCleared(
    AnalyticsFiltersCleared event,
    Emitter<AnalyticsState> emit,
  ) {
    emit(state.copyWith(filters: const AnalyticsFilters()));
  }

  Future<void> _fetch(
    Emitter<AnalyticsState> emit, {
    required bool refresh,
  }) async {
    try {
      final dashboard = await _api.fetchDashboard(refresh: refresh);
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          dashboard: dashboard,
          filters: _pruneFilters(state.filters, dashboard.columns),
          errorMessage: () => null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  AnalyticsFilters _pruneFilters(
    AnalyticsFilters filters,
    List<AnalyticsColumn> columns,
  ) {
    final keys = {for (final column in columns) column.key};
    final selected = {
      for (final entry in filters.selectedValues.entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    };
    final queries = {
      for (final entry in filters.queries.entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    };
    final dateKey = filters.dateColumnKey != null && keys.contains(filters.dateColumnKey)
        ? filters.dateColumnKey
        : null;
    return filters.copyWith(
      dateColumnKey: () => dateKey,
      selectedValues: selected,
      queries: queries,
    );
  }
}

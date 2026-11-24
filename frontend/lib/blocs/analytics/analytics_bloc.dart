import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/analytics_dashboard.dart';
import '../../models/analytics_filters.dart';
import '../../models/krr_dashboard.dart';
import '../../services/analytics_api.dart';
import '../../services/krr_api.dart';
import '../../services/task_analytics_api.dart';

part 'analytics_event.dart';
part 'analytics_state.dart';

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc({AnalyticsApi? api, TaskAnalyticsApi? taskApi, KrrApi? krrApi})
    : _api = api ?? analyticsApi,
      _taskApi = taskApi ?? taskAnalyticsApi,
      _krrApi = krrApi ?? krrApiInstance,
      super(const AnalyticsState()) {
    on<AnalyticsLoadRequested>(_onLoadRequested);
    on<AnalyticsRefreshRequested>(_onRefreshRequested);
    on<AnalyticsDateColumnChanged>(_onDateColumnChanged);
    on<AnalyticsPeriodChanged>(_onPeriodChanged);
    on<AnalyticsColumnValueToggled>(_onColumnValueToggled);
    on<AnalyticsColumnQueryChanged>(_onColumnQueryChanged);
    on<AnalyticsExcludeWeekendsChanged>(_onExcludeWeekendsChanged);
    on<AnalyticsFiltersCleared>(_onFiltersCleared);
    on<AnalyticsTableMoreRequested>(_onTableMoreRequested);
    on<AnalyticsSessionCleared>(_onSessionCleared);
    on<AnalyticsDashboardSourceChanged>(_onDashboardSourceChanged);
  }

  static const tablePageSize = 200;

  final AnalyticsApi _api;
  final TaskAnalyticsApi _taskApi;
  final KrrApi _krrApi;
  int _requestId = 0;

  Future<void> _onLoadRequested(
    AnalyticsLoadRequested event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    await _query(emit);
  }

  Future<void> _onRefreshRequested(
    AnalyticsRefreshRequested event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, errorMessage: () => null));
    await _query(emit, refresh: true);
  }

  Future<void> _onDateColumnChanged(
    AnalyticsDateColumnChanged event,
    Emitter<AnalyticsState> emit,
  ) {
    return _applyFilters(
      emit,
      state.filters.copyWith(dateColumnKey: () => event.columnKey),
    );
  }

  Future<void> _onPeriodChanged(
    AnalyticsPeriodChanged event,
    Emitter<AnalyticsState> emit,
  ) {
    return _applyFilters(
      emit,
      state.filters.copyWith(
        periodStart: () => event.start,
        periodEnd: () => event.end,
      ),
    );
  }

  Future<void> _onColumnValueToggled(
    AnalyticsColumnValueToggled event,
    Emitter<AnalyticsState> emit,
  ) {
    return _applyFilters(
      emit,
      state.filters.toggleValue(event.columnKey, event.valueKey),
    );
  }

  Future<void> _onColumnQueryChanged(
    AnalyticsColumnQueryChanged event,
    Emitter<AnalyticsState> emit,
  ) {
    return _applyFilters(
      emit,
      state.filters.setQuery(event.columnKey, event.query),
    );
  }

  Future<void> _onExcludeWeekendsChanged(
    AnalyticsExcludeWeekendsChanged event,
    Emitter<AnalyticsState> emit,
  ) {
    return _applyFilters(
      emit,
      state.filters.copyWith(excludeWeekends: event.enabled),
    );
  }

  Future<void> _onFiltersCleared(
    AnalyticsFiltersCleared event,
    Emitter<AnalyticsState> emit,
  ) {
    return _applyFilters(emit, const AnalyticsFilters());
  }

  Future<void> _onTableMoreRequested(
    AnalyticsTableMoreRequested event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(
      state.copyWith(
        tableLimit: state.tableLimit + tablePageSize,
        isRefreshing: true,
      ),
    );
    await _query(emit, allowStale: true);
  }

  Future<void> _applyFilters(
    Emitter<AnalyticsState> emit,
    AnalyticsFilters filters,
  ) async {
    if (filters == state.filters) return;
    emit(
      state.copyWith(
        filters: filters,
        tableLimit: tablePageSize,
        errorMessage: () => null,
      ),
    );
    await _query(emit, allowStale: true);
  }

  Future<void> _query(
    Emitter<AnalyticsState> emit, {
    bool refresh = false,
    bool allowStale = false,
  }) async {
    final requestId = ++_requestId;
    final kind = state.dashboardKind;
    try {
      if (kind == AnalyticsDashboardKind.krrWorks) {
        final dashboard = await _krrApi.query(
          filters: state.filters,
          tableLimit: state.tableLimit,
        );
        if (requestId != _requestId) return;
        emit(
          state.copyWith(
            isLoading: false,
            isRefreshing: false,
            clearDashboard: true,
            krrDashboard: dashboard,
            filters: state.filters.prunedTo(dashboard.columns),
            errorMessage: () => null,
          ),
        );
        return;
      }
      final dashboard = await _fetchDashboard(
        refresh: refresh,
        allowStale: allowStale,
      );
      if (requestId != _requestId) return;
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          clearKrr: true,
          dashboard: dashboard,
          filters: state.filters.prunedTo(dashboard.columns),
          errorMessage: () => null,
        ),
      );
    } catch (error) {
      if (requestId != _requestId) return;
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void _onSessionCleared(
    AnalyticsSessionCleared event,
    Emitter<AnalyticsState> emit,
  ) {
    _requestId++;
    emit(const AnalyticsState());
  }

  Future<void> _onDashboardSourceChanged(
    AnalyticsDashboardSourceChanged event,
    Emitter<AnalyticsState> emit,
  ) async {
    if (event.kind == state.dashboardKind && event.spaceId == state.spaceId) {
      return;
    }
    emit(
      AnalyticsState(
        dashboardKind: event.kind,
        spaceId: event.spaceId,
        isLoading: true,
      ),
    );
    await _query(emit);
  }

  Future<AnalyticsDashboard> _fetchDashboard({
    required bool refresh,
    required bool allowStale,
  }) {
    if (state.dashboardKind.isTaskDashboard) {
      return _taskApi.query(
        scope: state.dashboardKind,
        spaceId: state.spaceId,
        filters: state.filters,
        tableLimit: state.tableLimit,
      );
    }
    return _api.query(
      filters: state.filters,
      tableLimit: state.tableLimit,
      refresh: refresh,
      allowStale: allowStale,
    );
  }
}

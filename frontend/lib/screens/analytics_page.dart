import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import '../theme/ddt_icons.dart';

import '../blocs/analytics/analytics_bloc.dart';
import '../models/analytics_dashboard.dart';
import '../models/analytics_filters.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/analytics_formatters.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/krr_analytics_dashboard.dart';
import '../widgets/analytics_filters_panel.dart';
import '../widgets/ddt_adaptive.dart';
import '../widgets/analytics_tables.dart';
import '../widgets/task_analytics_dashboard.dart';
import '../widgets/ddt_section_refresh.dart';
import '../widgets/ddt_segmented_control.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_side_panel_divider.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/ddt_filter_dropdown.dart';
import '../widgets/ddt_section_sidebar.dart';
import '../widgets/ddt_icon.dart';

enum AnalyticsSection {
  overview('Основные данные'),
  summary('Сводная аналитика'),
  table('Таблица');

  const AnalyticsSection(this.label);

  final String label;

  static AnalyticsSection fromName(String? name) {
    for (final section in values) {
      if (section.name == name) return section;
    }
    return overview;
  }

  static List<AnalyticsSection> forDashboard(AnalyticsDashboardKind kind) {
    if (kind.isTaskDashboard || kind == AnalyticsDashboardKind.krrWorks) {
      return [overview, table];
    }
    return values;
  }
}

const _sectionStorageKey = 'analytics_section';
const _dashboardKindStorageKey = 'analytics_dashboard_kind';
const _dashboardSpaceIdStorageKey = 'analytics_space_id';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _storage = GetStorage('ddt_storage');
  late AnalyticsSection _section;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<AnalyticsBloc>();
    final storedKind = _storage.read<String>(_dashboardKindStorageKey);
    final kind = _dashboardKindFromStorage(storedKind);
    _section = _resolveSection(
      AnalyticsSection.fromName(_storage.read<String>(_sectionStorageKey)),
      kind,
    );
    final storedSpaceId = _storage.read<int>(_dashboardSpaceIdStorageKey);
    if (kind != AnalyticsDashboardKind.stp ||
        storedKind != null ||
        storedSpaceId != null) {
      bloc.add(
        AnalyticsDashboardSourceChanged(
          kind: kind,
          spaceId: kind == AnalyticsDashboardKind.tasksSpace
              ? storedSpaceId
              : null,
        ),
      );
    } else if (bloc.state.dashboard == null && !bloc.state.isLoading) {
      bloc.add(const AnalyticsLoadRequested());
    }
  }

  AnalyticsDashboardKind _dashboardKindFromStorage(String? value) {
    switch (value) {
      case 'personal':
        return AnalyticsDashboardKind.tasksPersonal;
      case 'space':
        return AnalyticsDashboardKind.tasksSpace;
      case 'krr':
        return AnalyticsDashboardKind.krrWorks;
      default:
        return AnalyticsDashboardKind.stp;
    }
  }

  AnalyticsSection _resolveSection(
    AnalyticsSection section,
    AnalyticsDashboardKind kind,
  ) {
    final allowed = AnalyticsSection.forDashboard(kind);
    return allowed.contains(section) ? section : AnalyticsSection.overview;
  }

  void _selectSection(AnalyticsSection section) {
    if (section == _section) return;
    setState(() => _section = section);
    _storage.write(_sectionStorageKey, section.name);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AnalyticsBloc>();
    return BlocListener<AnalyticsBloc, AnalyticsState>(
      listenWhen: (previous, current) =>
          previous.dashboardKind != current.dashboardKind,
      listener: (context, state) {
        final resolved = _resolveSection(_section, state.dashboardKind);
        if (resolved != _section) {
          _selectSection(resolved);
        }
      },
      child: BlocBuilder<AnalyticsBloc, AnalyticsState>(
      builder: (context, state) {
        final loaded = state.dashboardKind == AnalyticsDashboardKind.krrWorks
            ? state.krrDashboard != null
            : state.dashboard != null;
        if (state.isLoading && !loaded) {
          if (state.dashboardKind == AnalyticsDashboardKind.krrWorks) {
            return KrrAnalyticsView(
              skeleton: true,
              filters: state.filters,
              section: _section,
              isRefreshing: false,
              onSectionChanged: _selectSection,
              onRefresh: () {},
              onDateColumnChanged: (_) {},
              onPeriodChanged: (_, _) {},
              onValueToggled: (_, _) {},
              onQueryChanged: (_, _) {},
              onFiltersCleared: () {},
              onTableMore: () {},
            );
          }
          return _AnalyticsDashboardView(
            skeleton: true,
            dashboardKind: state.dashboardKind,
            filters: state.filters,
            section: _section,
            isRefreshing: false,
            onSectionChanged: _selectSection,
            onRefresh: () {},
            onDateColumnChanged: (_) {},
            onPeriodChanged: (_, _) {},
            onValueToggled: (_, _) {},
            onFiltersCleared: () {},
            onTableMore: () {},
          );
        }

        if (state.dashboardKind == AnalyticsDashboardKind.krrWorks) {
          final krr = state.krrDashboard;
          if (krr == null) {
            return KrrFirstSyncPrompt(
              message: state.errorMessage ?? 'Не удалось загрузить аналитику',
              onReady: () => bloc.add(const AnalyticsLoadRequested()),
            );
          }
          return KrrAnalyticsView(
            dashboard: krr,
            filters: state.filters,
            section: _section,
            isRefreshing: state.isRefreshing,
            errorMessage: state.errorMessage,
            onSectionChanged: _selectSection,
            onRefresh: () => bloc.add(const AnalyticsRefreshRequested()),
            onDateColumnChanged: (key) =>
                bloc.add(AnalyticsDateColumnChanged(key)),
            onPeriodChanged: (start, end) =>
                bloc.add(AnalyticsPeriodChanged(start: start, end: end)),
            onValueToggled: (column, value) => bloc.add(
              AnalyticsColumnValueToggled(columnKey: column, valueKey: value),
            ),
            onQueryChanged: (column, query) => bloc.add(
              AnalyticsColumnQueryChanged(columnKey: column, query: query),
            ),
            onFiltersCleared: () => bloc.add(const AnalyticsFiltersCleared()),
            onTableMore: () => bloc.add(const AnalyticsTableMoreRequested()),
          );
        }

        final dashboard = state.dashboard;
        if (dashboard == null) {
          return _AnalyticsLoadError(
            message: state.errorMessage ?? 'Не удалось загрузить аналитику',
            onRetry: () => bloc.add(const AnalyticsLoadRequested()),
          );
        }

        return _AnalyticsDashboardView(
          dashboard: dashboard,
          dashboardKind: state.dashboardKind,
          filters: state.filters,
          section: _section,
          isRefreshing: state.isRefreshing,
          errorMessage: state.errorMessage,
          onSectionChanged: _selectSection,
          onRefresh: () => bloc.add(const AnalyticsRefreshRequested()),
          onDateColumnChanged: (key) =>
              bloc.add(AnalyticsDateColumnChanged(key)),
          onPeriodChanged: (start, end) =>
              bloc.add(AnalyticsPeriodChanged(start: start, end: end)),
          onValueToggled: (column, value) => bloc.add(
            AnalyticsColumnValueToggled(columnKey: column, valueKey: value),
          ),
          onFiltersCleared: () => bloc.add(const AnalyticsFiltersCleared()),
          onTableMore: () => bloc.add(const AnalyticsTableMoreRequested()),
        );
      },
    ),
    );
  }
}

class _AnalyticsLoadError extends StatelessWidget {
  const _AnalyticsLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodyLargeSize,
              color: DdtTheme.textSecondary(context),
            ),
          ),
          SizedBox(height: 12.h),
          Button(
            text: 'Повторить',
            onPressed: onRetry,
            borderRadius: DdtTheme.radius,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsDashboardView extends StatefulWidget {
  const _AnalyticsDashboardView({
    this.dashboard,
    this.skeleton = false,
    required this.dashboardKind,
    required this.filters,
    required this.section,
    required this.isRefreshing,
    required this.onSectionChanged,
    required this.onRefresh,
    required this.onDateColumnChanged,
    required this.onPeriodChanged,
    required this.onValueToggled,
    required this.onFiltersCleared,
    required this.onTableMore,
    this.errorMessage,
  });

  final AnalyticsDashboard? dashboard;
  final bool skeleton;
  final AnalyticsDashboardKind dashboardKind;
  final AnalyticsFilters filters;
  final AnalyticsSection section;
  final bool isRefreshing;
  final ValueChanged<AnalyticsSection> onSectionChanged;
  final VoidCallback onRefresh;
  final ValueChanged<String> onDateColumnChanged;
  final void Function(DateTime? start, DateTime? end) onPeriodChanged;
  final void Function(String column, String value) onValueToggled;
  final VoidCallback onFiltersCleared;
  final VoidCallback onTableMore;
  final String? errorMessage;

  @override
  State<_AnalyticsDashboardView> createState() =>
      _AnalyticsDashboardViewState();
}

class _AnalyticsDashboardViewState extends State<_AnalyticsDashboardView> {
  bool _trendIsLine = false;
  AnalyticsTrendGroupBy _trendGroupBy = AnalyticsTrendGroupBy.day;

  @override
  Widget build(BuildContext context) {
    final dashboard = widget.dashboard;
    final skeleton = widget.skeleton || dashboard == null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final showSideFilters = constraints.maxWidth >= 860;
        final chartHeight = wide ? 340.h : 300.h;
        final tallChartHeight = wide ? 400.h : 340.h;

        final isTaskDashboard = widget.dashboardKind.isTaskDashboard;
        final sectionSlivers = switch (widget.section) {
          AnalyticsSection.overview => [
            SliverToBoxAdapter(
              child: isTaskDashboard
                  ? TaskAnalyticsKpiGrid(
                      kpi: skeleton ? null : dashboard.kpi,
                      skeleton: skeleton,
                    )
                  : _StpKpiGrid(
                      kpi: skeleton ? null : dashboard.kpi,
                      skeleton: skeleton,
                    ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: 12.h),
              sliver: SliverToBoxAdapter(
                child: isTaskDashboard
                    ? TaskAnalyticsChartGrid(
                        wide: wide,
                        chartHeight: chartHeight,
                        tallChartHeight: tallChartHeight,
                        skeleton: skeleton,
                        charts: skeleton ? null : dashboard.charts,
                        trendIsLine: _trendIsLine,
                        trendGroupBy: _trendGroupBy,
                        showSpaceCharts:
                            widget.dashboardKind ==
                            AnalyticsDashboardKind.tasksSpace,
                        onTrendTypeChanged: (isLine) =>
                            setState(() => _trendIsLine = isLine),
                        onTrendGroupChanged: (groupBy) =>
                            setState(() => _trendGroupBy = groupBy),
                      )
                    : _AnalyticsChartGrid(
                        wide: wide,
                        chartHeight: chartHeight,
                        tallChartHeight: tallChartHeight,
                        skeleton: skeleton,
                        charts: skeleton ? null : dashboard.charts,
                        trendIsLine: _trendIsLine,
                        trendGroupBy: _trendGroupBy,
                        onTrendTypeChanged: (isLine) =>
                            setState(() => _trendIsLine = isLine),
                        onTrendGroupChanged: (groupBy) =>
                            setState(() => _trendGroupBy = groupBy),
                      ),
              ),
            ),
          ],
          AnalyticsSection.summary => [
            if (!skeleton)
              SliverToBoxAdapter(child: _SummarySection(dashboard: dashboard)),
          ],
          AnalyticsSection.table => [
            if (!skeleton)
            SliverToBoxAdapter(
              child: _RequestsSection(
                records: dashboard.records,
                onMore: widget.onTableMore,
                title: isTaskDashboard ? 'Таблица задач' : 'Таблица заявок',
              ),
            ),
          ],
        };

        final dashboardScroll = CustomScrollView(
          key: PageStorageKey('analytics-${widget.section.name}'),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: DdtShellMetrics.of(context).contentInsetTop,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(bottom: 12.h),
              sliver: SliverToBoxAdapter(
                child: _DashboardHeader(
                  dashboard: skeleton ? null : dashboard,
                  dashboardKind: widget.dashboardKind,
                  filtered:
                      widget.filters.hasPeriod ||
                      widget.filters.hasColumnFilters,
                  errorMessage: widget.errorMessage,
                  section: widget.section,
                  isRefreshing: widget.isRefreshing,
                  onSectionChanged: widget.onSectionChanged,
                  onRefresh: widget.onRefresh,
                ),
              ),
            ),
            ...sectionSlivers,
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: 8.h + DdtScrollEdgeFade.listBottomPadding(context),
              ),
              sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        );

        final dashboardWithFades = DdtSectionRefreshOverlay(
          isRefreshing: widget.isRefreshing,
          child: DdtScrollEdgeFade(child: dashboardScroll),
        );

        final filtersPanel = AnalyticsFiltersPanel(
          loading: skeleton,
          columns: skeleton ? const [] : dashboard.columns,
          dateColumn: skeleton ? '' : dashboard.dateColumn,
          dateBounds: skeleton ? const {} : dashboard.dateBounds,
          filters: widget.filters,
          onDateColumnChanged: widget.onDateColumnChanged,
          onPeriodChanged: widget.onPeriodChanged,
          onValueToggled: widget.onValueToggled,
          onCleared: widget.onFiltersCleared,
        );

        if (DdtAdaptive.isCompact(context)) {
          return DdtAdaptiveSectionColumns(
            sheetTitle: 'Фильтры',
            sheetIcon: DdtIcons.sliders,
            sidebar: filtersPanel,
            body: dashboardWithFades,
          );
        }

        if (!showSideFilters) {
          return Column(
            children: [
              DdtSectionSidebarFrame(
                constrainWidth: false,
                child: SizedBox(height: 280.h, child: filtersPanel),
              ),
              SizedBox(height: 12.h),
              Container(height: 1, color: DdtTheme.sidePanelDivider(context)),
              SizedBox(height: 12.h),
              Expanded(child: dashboardWithFades),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DdtSectionSidebarFrame(child: filtersPanel),
            DdtSectionSidebar.afterScrollbarGapBox(),
            const DdtSidePanelDivider(),
            DdtSectionSidebar.dividerGap(),
            Expanded(child: dashboardWithFades),
          ],
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.dashboard,
    required this.dashboardKind,
    required this.filtered,
    required this.section,
    required this.isRefreshing,
    required this.onSectionChanged,
    required this.onRefresh,
    this.errorMessage,
  });

  final AnalyticsDashboard? dashboard;
  final AnalyticsDashboardKind dashboardKind;
  final bool filtered;
  final AnalyticsSection section;
  final bool isRefreshing;
  final ValueChanged<AnalyticsSection> onSectionChanged;
  final VoidCallback onRefresh;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final loaded = dashboard;
    final fetched = loaded == null
        ? ''
        : DateFormat('dd.MM.yyyy HH:mm').format(loaded.fetchedAt.toLocal());
    final entity = dashboardKind.isTaskDashboard ? 'задач' : 'заявок';
    final count = loaded == null
        ? ''
        : filtered
        ? 'показано ${loaded.filteredCount} из ${loaded.totalCount} $entity'
        : '${loaded.totalCount} $entity';
    final error = errorMessage;

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DdtSegmentedControl<AnalyticsSection>(
          segments: [
            for (final item in AnalyticsSection.forDashboard(dashboardKind))
              DdtSegmentedControlSegment(value: item, label: item.label),
          ],
          selected: section,
          onChanged: onSectionChanged,
        ),
        SizedBox(width: 8.w),
        IconButton(
          tooltip: 'Обновить',
          onPressed: isRefreshing ? null : onRefresh,
          icon: DdtIcon(
            DdtIcons.refresh,
            color: AppColors.primary,
            size: 22.sp,
          ),
        ),
        IconButton(
          tooltip: 'Редактировать',
          onPressed: null,
          icon: DdtIcon(
            DdtIcons.edit,
            color: DdtTheme.textMuted(context),
            size: 22.sp,
          ),
        ),
      ],
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dashboardKind.isTaskDashboard
              ? (loaded?.sheetName ?? 'Задачи')
              : 'КРР МР — Аналитика СТП',
          style: DdtTheme.style(
            fontSize: DdtTypography.panelTitleSize,
            fontWeight: FontWeight.w800,
            color: DdtTheme.textPrimary(context),
          ),
        ),
        SizedBox(height: 4.h),
        loaded == null
            ? const Align(
                alignment: Alignment.centerLeft,
                child: AnalyticsSkeletonFill(height: 14, width: 220),
              )
            : Text(
          dashboardKind.isTaskDashboard
              ? '$count · обновлено $fetched'
              : 'Лист «${loaded.sheetName}» · $count · обновлено $fetched',
          style: DdtTheme.style(
            fontSize: DdtTypography.captionSize,
            color: DdtTheme.textMuted(context),
          ),
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              error,
              style: DdtTheme.style(
                fontSize: DdtTypography.captionSize,
                color: const Color(0xFFC62828),
              ),
            ),
          ),
      ],
    );

    if (DdtAdaptive.isCompact(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          SizedBox(height: 10.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: controls,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titleBlock),
        SizedBox(width: 12.w),
        controls,
      ],
    );
  }
}

class _StpKpiGrid extends StatelessWidget {
  const _StpKpiGrid({required this.kpi, this.skeleton = false});

  final AnalyticsKpi? kpi;
  final bool skeleton;

  String _shareOfTotal(AnalyticsKpi kpi, int value) =>
      '${kpi.total == 0 ? 0 : (value / kpi.total * 100).round()}% от всех';

  @override
  Widget build(BuildContext context) {
    if (skeleton || kpi == null) {
      return _kpiWrap(context, [
        ('Всего заявок', AppColors.primary),
        ('SLA (в срок)', analyticsPositiveColor),
        ('Время решения', Color(0xFF7D6BC4)),
        ('Подтверждено', Color(0xFFD4943A)),
        ('Просрочено', Color(0xFFD65C5C)),
        ('Скорость реакции', Color(0xFF4A90C2)),
        ('Ошибки', Color(0xFF6B7C93)),
        ('Ожидание от ОИВ', Color(0xFFD4943A)),
      ]);
    }
    final data = kpi!;
    final topWaiting = data.topWaitingOiv;
    final items = [
      (
        'Всего заявок',
        '${data.total}',
        AppColors.primary,
        '${data.open} откр. / ${data.closed} закр.',
      ),
      (
        'SLA (в срок)',
        data.slaKnown == 0
            ? '—'
            : '${(data.slaOk / data.slaKnown * 100).round()}%',
        analyticsPositiveColor,
        '${data.slaOk} из ${data.slaKnown}',
      ),
      (
        'Время решения',
        formatAnalyticsDuration(data.medianResolutionHours),
        const Color(0xFF7D6BC4),
        'медиана закрытых',
      ),
      (
        'Подтверждено',
        '${data.confirmed}',
        const Color(0xFFD4943A),
        _shareOfTotal(data, data.confirmed),
      ),
      (
        'Просрочено',
        '${data.overdueOpen}',
        const Color(0xFFD65C5C),
        'просрочено открытых',
      ),
      (
        'Скорость реакции',
        formatAnalyticsReaction(data.medianReactionHours),
        const Color(0xFF4A90C2),
        'из ${data.reactionCount} с 2 комментариями',
      ),
      (
        'Ошибки',
        '${data.errors}',
        const Color(0xFF6B7C93),
        _shareOfTotal(data, data.errors),
      ),
      (
        'Ожидание от ОИВ',
        topWaiting != null && data.topWaitingOivHours != null
            ? formatAnalyticsDuration(data.topWaitingOivHours)
            : '—',
        const Color(0xFFD4943A),
        topWaiting != null && data.topWaitingOivHours != null
            ? '$topWaiting · ${data.topWaitingOivOpen} заявок · ${data.waitingOpen} всего'
            : (data.waitingOpen > 0
                  ? '${data.waitingOpen} в ожидании'
                  : 'нет данных'),
      ),
    ];

    return _kpiWrap(context, [
      for (final item in items) (item.$1, item.$3),
    ], values: [
      for (final item in items) (item.$2, item.$4),
    ]);
  }

  Widget _kpiWrap(
    BuildContext context,
    List<(String, Color)> cards, {
    List<(String, String?)>? values,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < cards.length; index++)
              SizedBox(
                width: width,
                child: AnalyticsKpiCard(
                  label: cards[index].$1,
                  value: values == null ? '' : values[index].$1,
                  color: cards[index].$2,
                  hint: values == null ? null : values[index].$2,
                  skeleton: values == null,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Extra vertical space for the OIV waiting panel (long subtitle + many rows).
double _oivWaitingPanelHeight({
  required bool wide,
  required double tallChartHeight,
  required int rowCount,
}) {
  final rowHeight = (wide ? 30.0 : 28.0).h;
  final headerSlack = 96.h;
  final needed = headerSlack + rowCount * rowHeight;
  final minHeight = tallChartHeight + (wide ? 120.h : 100.h);
  final maxHeight = (wide ? 720.0 : 640.0).h;
  return needed.clamp(minHeight, maxHeight);
}

class _AnalyticsChartGrid extends StatelessWidget {
  const _AnalyticsChartGrid({
    required this.wide,
    required this.chartHeight,
    required this.tallChartHeight,
    required this.charts,
    this.skeleton = false,
    required this.trendIsLine,
    required this.trendGroupBy,
    required this.onTrendTypeChanged,
    required this.onTrendGroupChanged,
  });

  final bool wide;
  final double chartHeight;
  final double tallChartHeight;
  final AnalyticsCharts? charts;
  final bool skeleton;
  final bool trendIsLine;
  final AnalyticsTrendGroupBy trendGroupBy;
  final ValueChanged<bool> onTrendTypeChanged;
  final ValueChanged<AnalyticsTrendGroupBy> onTrendGroupChanged;

  @override
  Widget build(BuildContext context) {
    final gap = 12.h;
    final data = charts;
    Widget plot(Widget Function(AnalyticsCharts charts) build) {
      if (skeleton || data == null) return const AnalyticsSkeletonFill();
      return build(data);
    }

    final trendControls = _TrendChartControls(
      isLine: trendIsLine,
      groupBy: trendGroupBy,
      onTypeChanged: onTrendTypeChanged,
      onGroupChanged: onTrendGroupChanged,
    );

    final trendCard = AnalyticsPanel(
      title: 'Динамика: создание и закрытие',
      headerTrailing: trendControls,
      child: plot(
        (charts) => AnalyticsTrendChart(
          trend: charts.trendFor(trendGroupBy),
          isLine: trendIsLine,
        ),
      ),
    );

    final typeCard = AnalyticsPanel(
      title: 'Тип обращений',
      child: plot((charts) => AnalyticsDonutChart(points: charts.type)),
    );

    final row2 = _ResponsiveRow(
      wide: wide,
      height: chartHeight,
      gap: gap,
      children: [
        AnalyticsPanel(
          title: 'Блоки системы',
          child: plot((charts) => AnalyticsHorizontalBarChart(points: charts.block)),
        ),
        AnalyticsPanel(
          title: 'ОИВ',
          child: plot((charts) => AnalyticsHorizontalBarChart(points: charts.oiv)),
        ),
        AnalyticsPanel(
          title: 'Модули / формы',
          child: plot((charts) => AnalyticsBarChart(points: charts.module)),
        ),
      ],
    );

    final row3 = _ResponsiveRow(
      wide: wide,
      height: tallChartHeight,
      gap: gap,
      children: [
        AnalyticsPanel(
          title: 'Категории проблем (топ-10)',
          child: plot(
            (charts) => AnalyticsHorizontalBarChart(points: charts.problemCategory),
          ),
        ),
        AnalyticsPanel(
          title: 'Заявки по статусам',
          child: plot(
            (charts) => AnalyticsDonutChart(
              points: charts.statusGroup,
              preferStatusColors: true,
            ),
          ),
        ),
      ],
    );

    final oivWaitingHeight = _oivWaitingPanelHeight(
      wide: wide,
      tallChartHeight: tallChartHeight,
      rowCount: charts?.oivWaiting.length ?? 6,
    );

    final oivWaitingPanel = SizedBox(
      height: oivWaitingHeight,
      child: AnalyticsPanel(
        title: 'ОИВ: ожидание ответа клиента',
        subtitle:
            'Среднее время от запроса информации до ответа ОИВ. Для открытых заявок — текущая длительность ожидания.',
        child: plot(
          (charts) => AnalyticsHorizontalBarChart.hours(points: charts.oivWaiting),
        ),
      ),
    );

    final row4 = _ResponsiveRow(
      wide: wide,
      height: tallChartHeight,
      gap: gap,
      children: [
        AnalyticsPanel(
          title: 'Сторона ошибки',
          child: plot((charts) => AnalyticsDonutChart(points: charts.errorSide)),
        ),
        AnalyticsPanel(
          title: 'Динамика по дням: создание / закрытие / реакция',
          child: plot(
            (charts) => AnalyticsDailyDetailChart(buckets: charts.dailyDetail),
          ),
        ),
      ],
    );

    final statusCategoryPanel = SizedBox(
      height: tallChartHeight,
      child: AnalyticsPanel(
        title: 'Статусы по топ-категориям',
        child: plot(
          (charts) => AnalyticsStackedStatusChart(data: charts.statusByCategory),
        ),
      ),
    );

    final solvedPanel = SizedBox(
      height: chartHeight,
      child: AnalyticsPanel(
        title: 'Решено / подтверждение пользователя',
        child: plot((charts) => AnalyticsSolvedChart(data: charts.solved)),
      ),
    );

    if (!wide) {
      return Column(
        children: [
          SizedBox(height: tallChartHeight, child: trendCard),
          SizedBox(height: gap),
          SizedBox(height: chartHeight, child: typeCard),
          SizedBox(height: gap),
          row2,
          SizedBox(height: gap),
          row3,
          SizedBox(height: gap),
          oivWaitingPanel,
          SizedBox(height: gap),
          row4,
          SizedBox(height: gap),
          statusCategoryPanel,
          SizedBox(height: gap),
          solvedPanel,
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: tallChartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 8, child: trendCard),
              SizedBox(width: 12.w),
              Expanded(flex: 4, child: typeCard),
            ],
          ),
        ),
        SizedBox(height: gap),
        row2,
        SizedBox(height: gap),
        row3,
        SizedBox(height: gap),
        oivWaitingPanel,
        SizedBox(height: gap),
        row4,
        SizedBox(height: gap),
        statusCategoryPanel,
        SizedBox(height: gap),
        solvedPanel,
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.dashboard});

  final AnalyticsDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final summary = dashboard.summary;
    final baseUrl = dashboard.itsmBaseUrl;
    final gap = SizedBox(height: 12.h);

    Widget panel(String title, Widget table) =>
        AnalyticsPanel(title: title, expandChild: false, child: table);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Агрегаты пересчитываются по активным фильтрам. Скорость реакции — разница между 1-м и 2-м комментарием. '
          'Сторона ошибки определяется автоматически по тексту заявки и статусу. Время ожидания ОИВ считается от первого '
          'напоминания «От Вас ожидают…» или последней активности по заявке в статусе ожидания.',
          style: DdtTheme.style(
            fontSize: DdtTypography.captionSize,
            color: DdtTheme.textMuted(context),
          ),
        ),
        gap,
        panel(
          'По категориям проблем',
          AnalyticsGroupTable(
            nameTitle: 'Категория',
            rows: summary.category,
            itsmBaseUrl: baseUrl,
          ),
        ),
        gap,
        panel(
          'По блокам системы',
          AnalyticsGroupTable(
            nameTitle: 'Блок',
            rows: summary.block,
            itsmBaseUrl: baseUrl,
          ),
        ),
        gap,
        panel(
          'По ОИВ: ожидание ответа клиента',
          AnalyticsOivWaitingTable(
            rows: summary.oivWaiting,
            itsmBaseUrl: baseUrl,
          ),
        ),
        gap,
        panel(
          'По стороне ошибки',
          AnalyticsGroupTable(
            nameTitle: 'Сторона',
            rows: summary.errorSide,
            itsmBaseUrl: baseUrl,
          ),
        ),
        gap,
        panel(
          'Матрица: категория × блок',
          AnalyticsCrossMatrixTable(matrix: summary.crossMatrix),
        ),
      ],
    );
  }
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection({
    required this.records,
    required this.onMore,
    this.title = 'Таблица заявок',
  });

  final AnalyticsRecordsPage records;
  final VoidCallback onMore;
  final String title;

  @override
  Widget build(BuildContext context) {
    final shown = records.items.length;
    return AnalyticsPanel(
      title: title,
      subtitle: records.total > shown
          ? 'Показано $shown из ${records.total} записей'
          : '${records.total} записей',
      expandChild: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnalyticsRequestsTable(rows: records.items),
          if (records.hasMore) ...[
            SizedBox(height: 12.h),
            Center(
              child: TextButton(
                onPressed: onMore,
                child: Text(
                  'Показать ещё',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendChartControls extends StatelessWidget {
  const _TrendChartControls({
    required this.isLine,
    required this.groupBy,
    required this.onTypeChanged,
    required this.onGroupChanged,
  });

  final bool isLine;
  final AnalyticsTrendGroupBy groupBy;
  final ValueChanged<bool> onTypeChanged;
  final ValueChanged<AnalyticsTrendGroupBy> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textMuted(context),
    );

    const typeOptions = [
      DdtFilterOption(key: 'bar', label: 'Столбцы'),
      DdtFilterOption(key: 'line', label: 'Линия'),
    ];
    const groupOptions = [
      DdtFilterOption(key: 'day', label: 'по дням'),
      DdtFilterOption(key: 'week', label: 'по неделям'),
      DdtFilterOption(key: 'month', label: 'по месяцам'),
    ];

    Widget compactSelect({
      required double width,
      required String summary,
      required List<DdtFilterOption> options,
      required Set<String> selected,
      required ValueChanged<String> onSelected,
    }) {
      return SizedBox(
        width: width.w,
        child: DdtSearchableFilterDropdown(
          summary: summary,
          active: false,
          multi: false,
          options: options,
          selected: selected,
          onSelected: onSelected,
        ),
      );
    }

    return Wrap(
      spacing: 8.w,
      runSpacing: 6.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: [
        Text('Вид', style: labelStyle),
        compactSelect(
          width: 132,
          summary: isLine ? 'Линия' : 'Столбцы',
          options: typeOptions,
          selected: {isLine ? 'line' : 'bar'},
          onSelected: (key) => onTypeChanged(key == 'line'),
        ),
        Text('Группировка', style: labelStyle),
        compactSelect(
          width: 148,
          summary: switch (groupBy) {
            AnalyticsTrendGroupBy.day => 'по дням',
            AnalyticsTrendGroupBy.week => 'по неделям',
            AnalyticsTrendGroupBy.month => 'по месяцам',
          },
          options: groupOptions,
          selected: {groupBy.name},
          onSelected: (key) {
            final next = AnalyticsTrendGroupBy.values.firstWhere(
              (item) => item.name == key,
              orElse: () => AnalyticsTrendGroupBy.day,
            );
            onGroupChanged(next);
          },
        ),
      ],
    );
  }
}

class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({
    required this.wide,
    required this.height,
    required this.gap,
    required this.children,
  });

  final bool wide;
  final double height;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) SizedBox(height: gap),
            SizedBox(height: height, child: children[index]),
          ],
        ],
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) SizedBox(width: 12.w),
            Expanded(child: children[index]),
          ],
        ],
      ),
    );
  }
}

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
import '../widgets/analytics_filters_panel.dart';
import '../widgets/analytics_tables.dart';
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
}

const _sectionStorageKey = 'analytics_section';

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
    _section = AnalyticsSection.fromName(
      _storage.read<String>(_sectionStorageKey),
    );
    final bloc = context.read<AnalyticsBloc>();
    if (bloc.state.dashboard == null && !bloc.state.isLoading) {
      bloc.add(const AnalyticsLoadRequested());
    }
  }

  void _selectSection(AnalyticsSection section) {
    if (section == _section) return;
    setState(() => _section = section);
    _storage.write(_sectionStorageKey, section.name);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AnalyticsBloc>();
    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      builder: (context, state) {
        if (state.isLoading && state.dashboard == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final dashboard = state.dashboard;
        if (dashboard == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.errorMessage ?? 'Не удалось загрузить аналитику',
                  textAlign: TextAlign.center,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodyLargeSize,
                    color: DdtTheme.textSecondary(context),
                  ),
                ),
                SizedBox(height: 12.h),
                Button(
                  text: 'Повторить',
                  onPressed: () => bloc.add(const AnalyticsLoadRequested()),
                  borderRadius: DdtTheme.radius,
                ),
              ],
            ),
          );
        }

        return _AnalyticsDashboardView(
          dashboard: dashboard,
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
    );
  }
}

class _AnalyticsDashboardView extends StatefulWidget {
  const _AnalyticsDashboardView({
    required this.dashboard,
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

  final AnalyticsDashboard dashboard;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final showSideFilters = constraints.maxWidth >= 860;
        final chartHeight = wide ? 340.h : 300.h;
        final tallChartHeight = wide ? 400.h : 340.h;

        final sectionSlivers = switch (widget.section) {
          AnalyticsSection.overview => [
            SliverToBoxAdapter(child: _StpKpiGrid(kpi: dashboard.kpi)),
            SliverPadding(
              padding: EdgeInsets.only(top: 12.h),
              sliver: SliverToBoxAdapter(
                child: _AnalyticsChartGrid(
                  wide: wide,
                  chartHeight: chartHeight,
                  tallChartHeight: tallChartHeight,
                  charts: dashboard.charts,
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
            SliverToBoxAdapter(child: _SummarySection(dashboard: dashboard)),
          ],
          AnalyticsSection.table => [
            SliverToBoxAdapter(
              child: _RequestsSection(
                records: dashboard.records,
                onMore: widget.onTableMore,
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
                  dashboard: dashboard,
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
          columns: dashboard.columns,
          dateColumn: dashboard.dateColumn,
          dateBounds: dashboard.dateBounds,
          filters: widget.filters,
          onDateColumnChanged: widget.onDateColumnChanged,
          onPeriodChanged: widget.onPeriodChanged,
          onValueToggled: widget.onValueToggled,
          onCleared: widget.onFiltersCleared,
        );

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
    required this.filtered,
    required this.section,
    required this.isRefreshing,
    required this.onSectionChanged,
    required this.onRefresh,
    this.errorMessage,
  });

  final AnalyticsDashboard dashboard;
  final bool filtered;
  final AnalyticsSection section;
  final bool isRefreshing;
  final ValueChanged<AnalyticsSection> onSectionChanged;
  final VoidCallback onRefresh;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final fetched = DateFormat(
      'dd.MM.yyyy HH:mm',
    ).format(dashboard.fetchedAt.toLocal());
    final count = filtered
        ? 'показано ${dashboard.filteredCount} из ${dashboard.totalCount} заявок'
        : '${dashboard.totalCount} заявок';
    final error = errorMessage;

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DdtSegmentedControl<AnalyticsSection>(
          segments: [
            for (final item in AnalyticsSection.values)
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

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'КРР МР — Аналитика СТП',
                style: DdtTheme.style(
                  fontSize: DdtTypography.panelTitleSize,
                  fontWeight: FontWeight.w800,
                  color: DdtTheme.textPrimary(context),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Лист «${dashboard.sheetName}» · $count · обновлено $fetched',
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
          ),
        ),
        SizedBox(width: 12.w),
        controls,
      ],
    );
  }
}

class _StpKpiGrid extends StatelessWidget {
  const _StpKpiGrid({required this.kpi});

  final AnalyticsKpi kpi;

  String _shareOfTotal(int value) =>
      '${kpi.total == 0 ? 0 : (value / kpi.total * 100).round()}% от всех';

  @override
  Widget build(BuildContext context) {
    final topWaiting = kpi.topWaitingOiv;
    final items = [
      (
        'Всего заявок',
        '${kpi.total}',
        AppColors.primary,
        '${kpi.open} откр. / ${kpi.closed} закр.',
      ),
      (
        'SLA (в срок)',
        kpi.slaKnown == 0
            ? '—'
            : '${(kpi.slaOk / kpi.slaKnown * 100).round()}%',
        analyticsPositiveColor,
        '${kpi.slaOk} из ${kpi.slaKnown}',
      ),
      (
        'Время решения',
        formatAnalyticsDuration(kpi.medianResolutionHours),
        const Color(0xFF1976D2),
        'медиана закрытых',
      ),
      (
        'Подтверждено',
        '${kpi.confirmed}',
        const Color(0xFFF9A825),
        _shareOfTotal(kpi.confirmed),
      ),
      (
        'Просрочено',
        '${kpi.overdueOpen}',
        const Color(0xFFC62828),
        'просрочено открытых',
      ),
      (
        'Скорость реакции',
        formatAnalyticsReaction(kpi.medianReactionHours),
        const Color(0xFF00838F),
        'из ${kpi.reactionCount} с 2 комментариями',
      ),
      (
        'Ошибки',
        '${kpi.errors}',
        const Color(0xFF546E7A),
        _shareOfTotal(kpi.errors),
      ),
      (
        'Ожидание от ОИВ',
        topWaiting != null && kpi.topWaitingOivHours != null
            ? formatAnalyticsDuration(kpi.topWaitingOivHours)
            : '—',
        const Color(0xFFF9A825),
        topWaiting != null && kpi.topWaitingOivHours != null
            ? '$topWaiting · ${kpi.topWaitingOivOpen} заявок · ${kpi.waitingOpen} всего'
            : (kpi.waitingOpen > 0
                  ? '${kpi.waitingOpen} в ожидании'
                  : 'нет данных'),
      ),
    ];

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
            for (final item in items)
              SizedBox(
                width: width,
                child: AnalyticsKpiCard(
                  label: item.$1,
                  value: item.$2,
                  color: item.$3,
                  hint: item.$4,
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
    required this.trendIsLine,
    required this.trendGroupBy,
    required this.onTrendTypeChanged,
    required this.onTrendGroupChanged,
  });

  final bool wide;
  final double chartHeight;
  final double tallChartHeight;
  final AnalyticsCharts charts;
  final bool trendIsLine;
  final AnalyticsTrendGroupBy trendGroupBy;
  final ValueChanged<bool> onTrendTypeChanged;
  final ValueChanged<AnalyticsTrendGroupBy> onTrendGroupChanged;

  @override
  Widget build(BuildContext context) {
    final gap = 12.h;
    final trendControls = _TrendChartControls(
      isLine: trendIsLine,
      groupBy: trendGroupBy,
      onTypeChanged: onTrendTypeChanged,
      onGroupChanged: onTrendGroupChanged,
    );

    final trendCard = AnalyticsPanel(
      title: 'Динамика: создание и закрытие',
      headerTrailing: trendControls,
      child: AnalyticsTrendChart(
        trend: charts.trendFor(trendGroupBy),
        isLine: trendIsLine,
      ),
    );

    final typeCard = AnalyticsPanel(
      title: 'Тип обращений',
      child: AnalyticsDonutChart(points: charts.type),
    );

    final row2 = _ResponsiveRow(
      wide: wide,
      height: chartHeight,
      gap: gap,
      children: [
        AnalyticsPanel(
          title: 'Блоки системы',
          child: AnalyticsHorizontalBarChart(points: charts.block),
        ),
        AnalyticsPanel(
          title: 'ОИВ',
          child: AnalyticsHorizontalBarChart(points: charts.oiv),
        ),
        AnalyticsPanel(
          title: 'Модули / формы',
          child: AnalyticsBarChart(points: charts.module),
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
          child: AnalyticsHorizontalBarChart(points: charts.problemCategory),
        ),
        AnalyticsPanel(
          title: 'Заявки по статусам',
          child: AnalyticsDonutChart(
            points: charts.statusGroup,
            preferStatusColors: true,
          ),
        ),
      ],
    );

    final oivWaitingHeight = _oivWaitingPanelHeight(
      wide: wide,
      tallChartHeight: tallChartHeight,
      rowCount: charts.oivWaiting.length,
    );

    final oivWaitingPanel = SizedBox(
      height: oivWaitingHeight,
      child: AnalyticsPanel(
        title: 'ОИВ: ожидание ответа клиента',
        subtitle:
            'Среднее время от запроса информации до ответа ОИВ. Для открытых заявок — текущая длительность ожидания.',
        child: AnalyticsHorizontalBarChart.hours(points: charts.oivWaiting),
      ),
    );

    final row4 = _ResponsiveRow(
      wide: wide,
      height: tallChartHeight,
      gap: gap,
      children: [
        AnalyticsPanel(
          title: 'Сторона ошибки',
          child: AnalyticsDonutChart(points: charts.errorSide),
        ),
        AnalyticsPanel(
          title: 'Динамика по дням: создание / закрытие / реакция',
          child: AnalyticsDailyDetailChart(buckets: charts.dailyDetail),
        ),
      ],
    );

    final statusCategoryPanel = SizedBox(
      height: tallChartHeight,
      child: AnalyticsPanel(
        title: 'Статусы по топ-категориям',
        child: AnalyticsStackedStatusChart(data: charts.statusByCategory),
      ),
    );

    final solvedPanel = SizedBox(
      height: chartHeight,
      child: AnalyticsPanel(
        title: 'Решено / подтверждение пользователя',
        child: AnalyticsSolvedChart(data: charts.solved),
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
  const _RequestsSection({required this.records, required this.onMore});

  final AnalyticsRecordsPage records;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final shown = records.items.length;
    return AnalyticsPanel(
      title: 'Таблица заявок',
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

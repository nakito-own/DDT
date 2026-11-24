import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../models/analytics_dashboard.dart';
import '../services/krr_api.dart';
import '../models/analytics_filters.dart';
import '../models/krr_dashboard.dart';
import '../screens/analytics_page.dart';
import '../theme/ddt_icons.dart';
import 'ddt_dialog.dart';
import 'ddt_load_progress.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/analytics_charts.dart';
import 'krr_insights_panels.dart';
import '../widgets/analytics_filters_panel.dart';
import '../widgets/ddt_filter_dropdown.dart';
import '../widgets/ddt_section_refresh.dart';
import '../widgets/analytics_tables.dart';
import '../widgets/ddt_adaptive.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/ddt_section_sidebar.dart';
import '../widgets/ddt_segmented_control.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_side_panel_divider.dart';

class KrrAnalyticsView extends StatelessWidget {
  const KrrAnalyticsView({
    super.key,
    this.dashboard,
    this.skeleton = false,
    required this.filters,
    required this.section,
    required this.isRefreshing,
    required this.onSectionChanged,
    required this.onRefresh,
    this.onResync,
    required this.onDateColumnChanged,
    required this.onPeriodChanged,
    required this.onExcludeWeekendsChanged,
    required this.onValueToggled,
    required this.onQueryChanged,
    required this.onFiltersCleared,
    required this.onTableMore,
    this.errorMessage,
  });

  final KrrDashboard? dashboard;
  final bool skeleton;
  final AnalyticsFilters filters;
  final AnalyticsSection section;
  final bool isRefreshing;
  final ValueChanged<AnalyticsSection> onSectionChanged;
  final VoidCallback onRefresh;
  final VoidCallback? onResync;
  final ValueChanged<String> onDateColumnChanged;
  final void Function(DateTime? start, DateTime? end) onPeriodChanged;
  final ValueChanged<bool> onExcludeWeekendsChanged;
  final void Function(String column, String value) onValueToggled;
  final void Function(String column, String query) onQueryChanged;
  final VoidCallback onFiltersCleared;
  final VoidCallback onTableMore;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final showSideFilters = constraints.maxWidth >= 860;
        final chartHeight = wide ? 340.h : 300.h;
        final dashboard = this.dashboard;
        final filtered = filters.hasPeriod || filters.hasColumnFilters;
        final compact = DdtAdaptive.isCompact(context);
        final topInset = DdtShellMetrics.of(context).contentInsetTop;
        final controls = _KrrSectionControls(
          section: section,
          isRefreshing: isRefreshing,
          onSectionChanged: onSectionChanged,
          onResync: onResync,
        );
        final body = CustomScrollView(
          key: PageStorageKey('krr-${section.name}'),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: topInset)),
            SliverPadding(
              padding: EdgeInsets.only(bottom: 12.h),
              sliver: SliverToBoxAdapter(
                child: _KrrHeader(
                  dashboard: skeleton ? null : dashboard,
                  filtered: filtered,
                  errorMessage: errorMessage,
                  controlsSpacer: controls,
                  compact: compact,
                ),
              ),
            ),
            if (!skeleton && section == AnalyticsSection.table && dashboard != null) ...[
              SliverToBoxAdapter(
                child: _KrrTable(records: dashboard.records, onMore: onTableMore),
              ),
              SliverPadding(
                padding: EdgeInsets.only(top: 12.h),
                sliver: SliverToBoxAdapter(
                  child: KrrMissingAreaTable(
                    rows: dashboard.insights.missingArea,
                    total: dashboard.insights.missingAreaTotal,
                    onOpen: () => showKrrIssueDialog(
                      context,
                      filters: filters,
                      issue: 'missing_area:all',
                      title: 'Работы без округа и района',
                    ),
                  ),
                ),
              ),
            ] else if (section == AnalyticsSection.quality) ...[
              SliverToBoxAdapter(
                child: KrrQualityPanels(
                  insights: skeleton ? null : dashboard?.insights,
                  skeleton: skeleton || dashboard == null,
                  chartHeight: chartHeight,
                  wide: wide,
                  onOpen: (issue, title) => showKrrIssueDialog(
                    context,
                    filters: filters,
                    issue: issue,
                    title: title,
                  ),
                ),
              ),
            ] else ...[
              SliverToBoxAdapter(
                child: _KrrKpiGrid(
                  kpi: skeleton ? null : dashboard?.kpi,
                  insights: skeleton ? null : dashboard?.insights,
                  skeleton: skeleton || dashboard == null,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(top: 12.h),
                sliver: SliverToBoxAdapter(
                  child: _KrrChartGrid(
                    wide: wide,
                    chartHeight: chartHeight,
                    skeleton: skeleton || dashboard == null,
                    charts: skeleton ? null : dashboard?.charts,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(top: 12.h),
                sliver: SliverToBoxAdapter(
                  child: KrrWorkInsightPanels(
                    insights: skeleton ? null : dashboard?.insights,
                    charts: skeleton ? null : dashboard?.charts,
                    skeleton: skeleton || dashboard == null,
                    wide: wide,
                    chartHeight: chartHeight,
                    onOpen: (issue, title) => showKrrIssueDialog(
                      context,
                      filters: filters,
                      issue: issue,
                      title: title,
                    ),
                  ),
                ),
              ),
            ],
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: 8.h + DdtScrollEdgeFade.listBottomPadding(context),
              ),
              sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        );
        final scroll = Stack(
          children: [
            DdtSectionRefreshOverlay(
              isRefreshing: isRefreshing,
              child: DdtScrollEdgeFade(child: body),
            ),
            Positioned(
              top: topInset,
              right: 0,
              child: controls,
            ),
          ],
        );
        final filtersPanel = AnalyticsFiltersPanel(
          loading: skeleton || dashboard == null,
          columns: dashboard?.columns ?? const [],
          dateColumn: dashboard?.dateColumn ?? '',
          dateBounds: dashboard?.dateBounds ?? const {},
          filters: filters,
          onDateColumnChanged: onDateColumnChanged,
          onPeriodChanged: onPeriodChanged,
          onExcludeWeekendsChanged: onExcludeWeekendsChanged,
          onValueToggled: onValueToggled,
          onQueryChanged: onQueryChanged,
          onCleared: onFiltersCleared,
        );
        if (DdtAdaptive.isCompact(context)) {
          return DdtAdaptiveSectionColumns(
            sheetTitle: 'Фильтры',
            sheetIcon: DdtIcons.sliders,
            sidebar: filtersPanel,
            body: scroll,
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
              Expanded(child: scroll),
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
            Expanded(child: scroll),
          ],
        );
      },
    );
  }
}

class _KrrSectionControls extends StatelessWidget {
  const _KrrSectionControls({
    required this.section,
    required this.isRefreshing,
    required this.onSectionChanged,
    this.onResync,
  });

  final AnalyticsSection section;
  final bool isRefreshing;
  final ValueChanged<AnalyticsSection> onSectionChanged;
  final VoidCallback? onResync;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DdtSegmentedControl<AnalyticsSection>(
          segments: [
            for (final item in AnalyticsSection.forDashboard(AnalyticsDashboardKind.krrWorks))
              DdtSegmentedControlSegment(
                value: item,
                label: switch (item) {
                  AnalyticsSection.overview => 'Общая аналитика',
                  AnalyticsSection.quality => 'Качество данных',
                  AnalyticsSection.table => 'Таблица',
                  _ => item.label,
                },
              ),
          ],
          selected: section,
          onChanged: onSectionChanged,
        ),
        SizedBox(width: 8.w),
        if (onResync != null)
          IconButton(
            tooltip: 'Перезапросить данные DTW',
            onPressed: isRefreshing ? null : onResync,
            icon: DdtIcon(
              DdtIcons.refresh,
              color: DdtTheme.primaryColor,
              size: 22.sp,
            ),
          ),
      ],
    );
  }
}

class _KrrHeader extends StatelessWidget {
  const _KrrHeader({
    required this.dashboard,
    required this.filtered,
    required this.controlsSpacer,
    required this.compact,
    this.errorMessage,
  });

  final KrrDashboard? dashboard;
  final bool filtered;
  final Widget controlsSpacer;
  final bool compact;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final loaded = dashboard;
    final fetched = loaded == null
        ? ''
        : DateFormat('dd.MM.yyyy HH:mm').format(loaded.fetchedAt.toLocal());
    final count = loaded == null
        ? ''
        : filtered
        ? 'показано ${loaded.filteredCount} из ${loaded.totalCount}'
        : '${loaded.totalCount} версий';
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Версии работ КРР МР',
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
          '$count · снимок обновлён $fetched',
          style: DdtTheme.style(
            fontSize: DdtTypography.captionSize,
            color: DdtTheme.textMuted(context),
          ),
        ),
        if (errorMessage != null)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              errorMessage!,
              style: DdtTheme.style(
                fontSize: DdtTypography.captionSize,
                color: const Color(0xFFC62828),
              ),
            ),
          ),
      ],
    );
    final reserved = Visibility(
      visible: false,
      maintainSize: true,
      maintainState: true,
      maintainAnimation: true,
      child: controlsSpacer,
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          SizedBox(height: 10.h),
          Align(alignment: Alignment.centerRight, child: reserved),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        SizedBox(width: 12.w),
        reserved,
      ],
    );
  }
}

class _KrrKpiGrid extends StatelessWidget {
  const _KrrKpiGrid({
    required this.kpi,
    required this.insights,
    this.skeleton = false,
  });

  final KrrKpi? kpi;
  final KrrInsights? insights;
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    if (skeleton || kpi == null) {
      return _wrap(context, const [
        ('Количество версий работ КРР', DdtTheme.primaryColor),
        ('Количество уникальных работ КРР', Color(0xFF4A90C2)),
        ('Количество ОИВ', Color(0xFF7D6BC4)),
        ('Количество балансодержателей', Color(0xFFD67249)),
        ('Дельта работ', Color(0xFF6B7C93)),
        ('Включено в ДК', analyticsPositiveColor),
        ('Дата последнего изменения', Color(0xFFD4943A)),
        ('Заполненность', Color(0xFF3E9B74)),
        ('Завершённые работы', analyticsPositiveColor),
        ('В процессе реализации', Color(0xFF4A90C2)),
        ('Отменённые работы', Color(0xFFD65C5C)),
        ('Средняя площадь', Color(0xFF4A90C2)),
      ], values: const [
        ('0', 'в текущей выборке'),
        ('0', 'по идентификатору работы'),
        ('0', 'уникальные ведомственные ОИВ'),
        ('0', 'уникальные организации'),
        ('—', 'к вчерашнему снимку'),
        ('0', 'записи с признаком ДК'),
        ('—', 'по дате изменения версии'),
        ('0%', 'доля заполненных значений'),
        ('0', 'последняя версия работы'),
        ('0', 'последняя версия работы'),
        ('0', 'последняя версия работы'),
        ('—', 'средняя square'),
      ], skeleton: true);
    }
    final data = kpi!;
    final insight = insights;
    final delta = data.delta;
    final average = insight?.squareAvg;
    final lastChanged = data.lastChanged == null
        ? '—'
        : DateFormat('dd.MM.yyyy').format(data.lastChanged!.toLocal());
    final items = [
      ('Количество версий работ КРР', '${data.versions}', DdtTheme.primaryColor, 'в текущей выборке'),
      ('Количество уникальных работ КРР', '${data.uniqueWorks}', const Color(0xFF4A90C2), 'по идентификатору работы'),
      ('Количество ОИВ', '${data.oivCount}', const Color(0xFF7D6BC4), 'уникальные ведомственные ОИВ'),
      ('Количество балансодержателей', '${data.balanceHolders}', const Color(0xFFD67249), 'уникальные организации'),
      (
        'Дельта работ',
        delta == null ? '—' : (delta > 0 ? '+$delta' : '$delta'),
        delta == null || delta == 0
            ? const Color(0xFF6B7C93)
            : delta > 0
            ? analyticsPositiveColor
            : const Color(0xFFD65C5C),
        delta == null ? 'вчерашнего снимка нет' : 'к вчерашнему снимку',
      ),
      ('Включено в ДК', '${data.dkCount}', analyticsPositiveColor, 'записи с признаком ДК'),
      ('Дата последнего изменения', lastChanged, const Color(0xFFD4943A), 'по дате изменения версии'),
      ('Заполненность', '${data.fillPercent.toStringAsFixed(1)}%', const Color(0xFF3E9B74), 'доля заполненных значений'),
      ('Завершённые работы', '${insight?.completed ?? 0}', analyticsPositiveColor, 'последняя версия, статус завершения'),
      ('В процессе реализации', '${insight?.inProgress ?? 0}', const Color(0xFF4A90C2), 'последняя версия работы'),
      ('Отменённые работы', '${insight?.cancelled ?? 0}', const Color(0xFFD65C5C), 'последняя версия работы'),
      (
        'Средняя площадь',
        average == null ? 'Недоступно' : formatKrrNumber(average, digits: 1),
        const Color(0xFF4A90C2),
        average == null ? 'нет положительных значений square' : 'по работам с площадью',
      ),
    ];
    return _wrap(context, [
      for (final item in items) (item.$1, item.$3),
    ], values: [
      for (final item in items) (item.$2, item.$4),
    ]);
  }

  Widget _wrap(
    BuildContext context,
    List<(String, Color)> cards, {
    List<(String, String?)>? values,
    bool skeleton = false,
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
                  skeleton: skeleton,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KrrChartGrid extends StatefulWidget {
  const _KrrChartGrid({
    required this.wide,
    required this.chartHeight,
    required this.charts,
    this.skeleton = false,
  });

  final bool wide;
  final double chartHeight;
  final KrrCharts? charts;
  final bool skeleton;

  @override
  State<_KrrChartGrid> createState() => _KrrChartGridState();
}

class _KrrChartGridState extends State<_KrrChartGrid> {
  bool _createdIsLine = false;
  bool _changedIsLine = false;
  AnalyticsTrendGroupBy _createdGroup = AnalyticsTrendGroupBy.day;
  AnalyticsTrendGroupBy _changedGroup = AnalyticsTrendGroupBy.day;

  @override
  Widget build(BuildContext context) {
    final data = widget.charts;
    Widget plot(Widget Function(KrrCharts charts) build) {
      if (widget.skeleton || data == null) return const AnalyticsSkeletonFill();
      return build(data);
    }

    Widget panel(String title, Widget child, {String? subtitle, Widget? trailing}) {
      return AnalyticsPanel(
        title: title,
        subtitle: subtitle,
        headerTrailing: trailing,
        child: child,
      );
    }

    final created = panel(
      'Динамика создания версий работ КРР',
      plot(
        (charts) => AnalyticsTrendChart(
          trend: krrTrendBuckets(charts.created.forGroup(_createdGroup)),
          isLine: _createdIsLine,
          seriesName: 'Создано',
        ),
      ),
      subtitle: 'по дате создания версии',
      trailing: _KrrTrendControls(
        isLine: _createdIsLine,
        groupBy: _createdGroup,
        onTypeChanged: (value) => setState(() => _createdIsLine = value),
        onGroupChanged: (value) => setState(() => _createdGroup = value),
      ),
    );
    final changed = panel(
      'Динамика редактирования версий работ КРР',
      plot(
        (charts) => AnalyticsTrendChart(
          trend: krrTrendBuckets(charts.changed.forGroup(_changedGroup)),
          isLine: _changedIsLine,
          seriesName: 'Изменено',
        ),
      ),
      subtitle: 'по дате изменения версии',
      trailing: _KrrTrendControls(
        isLine: _changedIsLine,
        groupBy: _changedGroup,
        onTypeChanged: (value) => setState(() => _changedIsLine = value),
        onGroupChanged: (value) => setState(() => _changedGroup = value),
      ),
    );
    final oivClass = panel(
      'Классы ведомственных ОИВ',
      plot((charts) => AnalyticsDonutChart(points: charts.oivClass)),
    );
    final stage = panel(
      'Стадии работ',
      plot(
        (charts) => AnalyticsDonutChart(
          points: charts.stage,
          preferStatusColors: true,
        ),
      ),
    );
    final year = panel(
      'Год работ',
      plot((charts) => AnalyticsBarChart(points: charts.year)),
    );
    final status = panel(
      'Статусы',
      plot((charts) => AnalyticsBarChart(points: charts.status)),
    );
    final district = panel(
      'Округа',
      plot(
        (charts) => AnalyticsHorizontalBarChart(points: charts.district, limit: 12),
      ),
    );
    final program = panel(
      'Программы',
      plot(
        (charts) => AnalyticsHorizontalBarChart(points: charts.program, limit: 10),
      ),
    );
    final activation = panel(
      'Статусы актов',
      plot((charts) => AnalyticsDonutChart(points: charts.activation)),
    );

    Widget pair(Widget left, Widget right) {
      if (!widget.wide) {
        return Column(
          children: [
            SizedBox(height: widget.chartHeight, child: left),
            SizedBox(height: 12.h),
            SizedBox(height: widget.chartHeight, child: right),
          ],
        );
      }
      return SizedBox(
        height: widget.chartHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            SizedBox(width: 12.w),
            Expanded(child: right),
          ],
        ),
      );
    }

    return DashboardSkeletonScope(
      loading: widget.skeleton || data == null,
      child: Column(
      children: [
        SizedBox(height: widget.chartHeight, child: created),
        SizedBox(height: 12.h),
        SizedBox(height: widget.chartHeight, child: changed),
        SizedBox(height: 12.h),
        pair(oivClass, stage),
        SizedBox(height: 12.h),
        pair(year, status),
        SizedBox(height: 12.h),
        pair(district, program),
        SizedBox(height: 12.h),
        SizedBox(height: widget.chartHeight, child: activation),
      ],
    ),
    );
  }
}

class _KrrTrendControls extends StatelessWidget {
  const _KrrTrendControls({
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

    Widget select({
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
        select(
          width: 132,
          summary: isLine ? 'Линия' : 'Столбцы',
          options: typeOptions,
          selected: {isLine ? 'line' : 'bar'},
          onSelected: (key) => onTypeChanged(key == 'line'),
        ),
        Text('Группировка', style: labelStyle),
        select(
          width: 148,
          summary: switch (groupBy) {
            AnalyticsTrendGroupBy.day => 'по дням',
            AnalyticsTrendGroupBy.week => 'по неделям',
            AnalyticsTrendGroupBy.month => 'по месяцам',
          },
          options: groupOptions,
          selected: {groupBy.name},
          onSelected: (key) {
            onGroupChanged(
              AnalyticsTrendGroupBy.values.firstWhere(
                (item) => item.name == key,
                orElse: () => AnalyticsTrendGroupBy.day,
              ),
            );
          },
        ),
      ],
    );
  }
}

AnalyticsTrendBuckets krrTrendBuckets(List<AnalyticsCountPoint> points) {
  if (points.isEmpty) return const AnalyticsTrendBuckets();
  return AnalyticsTrendBuckets(
    labels: [for (final point in points) point.label],
    created: [for (final point in points) point.value],
  );
}

class _KrrTable extends StatelessWidget {
  const _KrrTable({required this.records, required this.onMore});

  final KrrDashboardRecords records;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final shown = records.items.length;
    final dateFormat = DateFormat('dd.MM.yyyy');
    String text(Map<String, dynamic> row, String key) {
      final value = row[key];
      if (value == null || value == '') return '—';
      if (key == 'dk') return value == true ? 'Да' : 'Нет';
      final isDate =
          key == 'changed_date_version' ||
          key.endsWith('_date') ||
          key.endsWith('_beg') ||
          key.endsWith('_end');
      if (isDate) {
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) return dateFormat.format(parsed.toLocal());
      }
      return value.toString();
    }

    return AnalyticsPanel(
      title: 'Таблица версий',
      subtitle: records.total > shown
          ? 'Показано $shown из ${records.total}'
          : '${records.total} записей',
      expandChild: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnalyticsDataTable(
            fitContent: true,
            columns: const [
              AnalyticsTableColumn('Версия', width: 220),
              AnalyticsTableColumn('Год', width: 70),
              AnalyticsTableColumn('Стадия', width: 120),
              AnalyticsTableColumn('Округ', width: 90),
              AnalyticsTableColumn('Район', width: 140),
              AnalyticsTableColumn('ОИВ', width: 180),
              AnalyticsTableColumn('Балансодержатель', width: 180),
              AnalyticsTableColumn('ДК', width: 60),
              AnalyticsTableColumn('Программа', width: 120),
              AnalyticsTableColumn('Статус', width: 140),
              AnalyticsTableColumn('Изменена', width: 110),
            ],
            rows: [
              for (final row in records.items)
                [
                  for (final key in const [
                    'name_work_version',
                    'work_year',
                    'stage',
                    'adm_district',
                    'district',
                    'departmental_oiv',
                    'balance_holder',
                    'dk',
                    'program',
                    'status_id_name',
                    'changed_date_version',
                  ])
                    Text(
                      text(row, key),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSmallSize,
                        color: DdtTheme.textPrimary(context),
                      ),
                    ),
                ],
            ],
          ),
          if (records.hasMore) ...[
            SizedBox(height: 12.h),
            Center(child: TextButton(onPressed: onMore, child: const Text('Показать ещё'))),
          ],
        ],
      ),
    );
  }
}

/// Starts the once-a-day KRR fetch when today's snapshot does not exist yet.

/// DTW fetch drawn over a dimmed dashboard skeleton.
class KrrSyncSurface extends StatefulWidget {
  const KrrSyncSurface({
    super.key,
    required this.hasData,
    required this.checking,
    required this.message,
    required this.onCompleted,
    required this.skeleton,
    required this.dashboardBuilder,
  });

  final bool hasData;
  final bool checking;
  final String message;
  final VoidCallback onCompleted;
  final Widget skeleton;
  final Widget Function(VoidCallback resync) dashboardBuilder;

  @override
  State<KrrSyncSurface> createState() => _KrrSyncSurfaceState();
}

class _KrrSyncSurfaceState extends State<KrrSyncSurface> {
  bool _syncing = false;
  int _stored = 0;
  int _total = 0;
  String? _error;

  Future<void> _start({required bool force}) async {
    setState(() {
      _syncing = true;
      _error = null;
      _stored = 0;
      _total = 0;
    });
    try {
      await krrApiInstance.syncUntilDone(
        force: force,
        onProgress: (stored, total) {
          if (!mounted) return;
          setState(() {
            _stored = stored;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() => _syncing = false);
      widget.onCompleted();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _cancel() {
    setState(() => _error = null);
    widget.onCompleted();
  }

  Future<void> _resync() async {
    final confirmed = await showDdtConfirm(
      context,
      title: 'Обновить данные КРР?',
      message:
          'Текущий снимок за сегодня будет загружен из DTW заново. Это может занять несколько минут.',
      cancelLabel: 'Отмена',
      confirmLabel: 'Обновить',
      destructive: false,
    );
    if (confirmed != true || !mounted) return;
    await _start(force: true);
  }

  @override
  Widget build(BuildContext context) {
    // Dim and the progress bar are only for an explicit DTW fetch.
    if (_syncing || _error != null) {
      final detail = _total > 0
          ? 'DTW · загружено $_stored из $_total'
          : 'Подключение к DTW…';
      return DashboardLoadVeil(
        skeleton: widget.skeleton,
        title: 'Загрузка данных',
        detail: detail,
        showProgress: _syncing,
        progress: _syncing && _total > 0 ? _stored / _total : null,
        error: _error,
        action: _syncing
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Button(
                    text: 'Загрузить данные',
                    onPressed: () => _start(force: widget.hasData),
                    borderRadius: DdtTheme.radius,
                  ),
                  SizedBox(height: 8.h),
                  Button(
                    text: 'Отмена',
                    type: ButtonType.text,
                    textColor: Colors.white,
                    onPressed: _cancel,
                    borderRadius: DdtTheme.radius,
                  ),
                ],
              ),
      );
    }
    if (!widget.hasData) {
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: widget.skeleton),
          if (!widget.checking)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: DdtTheme.style(
                          fontSize: DdtTypography.bodyLargeSize,
                          color: DdtTheme.textSecondary(context),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Button(
                        text: 'Загрузить данные',
                        onPressed: () => _start(force: false),
                        borderRadius: DdtTheme.radius,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return widget.dashboardBuilder(_resync);
  }
}


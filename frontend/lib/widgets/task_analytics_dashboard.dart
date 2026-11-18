import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/analytics_dashboard.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/analytics_formatters.dart';
import 'analytics_charts.dart';
import 'ddt_filter_dropdown.dart';

class TaskAnalyticsKpiGrid extends StatelessWidget {
  const TaskAnalyticsKpiGrid({super.key, required this.kpi, this.skeleton = false});

  final AnalyticsKpi? kpi;
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    if (skeleton || kpi == null) {
      return _grid(context, [
        ('Среднее время решения', Color(0xFF7D6BC4)),
        ('Решено задач', analyticsPositiveColor),
        ('Блокеры', Color(0xFFD65C5C)),
        ('Просрочен дедлайн', Color(0xFFD4943A)),
        ('Всего задач', AppColors.primary),
        ('В работе', Color(0xFF4A90C2)),
      ], skeleton: true);
    }
    final data = kpi!;
    final items = [
      (
        'Среднее время решения',
        formatAnalyticsDuration(data.medianResolutionHours),
        const Color(0xFF7D6BC4),
        'медиана по закрытым задачам',
      ),
      (
        'Решено задач',
        '${data.closed}',
        analyticsPositiveColor,
        '${data.open} в работе / открыто',
      ),
      (
        'Блокеры',
        '${data.errors}',
        const Color(0xFFD65C5C),
        'приоритет «Блокер»',
      ),
      (
        'Просрочен дедлайн',
        '${data.overdueOpen}',
        const Color(0xFFD4943A),
        'открытые и закрытые с нарушением срока',
      ),
      (
        'Всего задач',
        '${data.total}',
        AppColors.primary,
        '${data.waitingOpen} в статусе «В работе»',
      ),
      (
        'В работе',
        '${data.waitingOpen}',
        const Color(0xFF4A90C2),
        'статус «В работе»',
      ),
    ];

    return _grid(
      context,
      [for (final item in items) (item.$1, item.$3)],
      values: [for (final item in items) (item.$2, item.$4)],
    );
  }

  Widget _grid(
    BuildContext context,
    List<(String, Color)> cards, {
    List<(String, String?)>? values,
    bool skeleton = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
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
                  skeleton: skeleton || values == null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class TaskAnalyticsChartGrid extends StatelessWidget {
  const TaskAnalyticsChartGrid({
    super.key,
    required this.wide,
    required this.chartHeight,
    required this.tallChartHeight,
    required this.charts,
    this.skeleton = false,
    required this.trendIsLine,
    required this.trendGroupBy,
    required this.onTrendTypeChanged,
    required this.onTrendGroupChanged,
    required this.showSpaceCharts,
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
  final bool showSpaceCharts;

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
      title: 'Типы задач',
      child: plot((charts) => AnalyticsDonutChart(points: charts.type)),
    );

    final priorityCard = AnalyticsPanel(
      title: 'Приоритеты',
      child: plot(
        (charts) => AnalyticsDonutChart(
          points: charts.priority.isNotEmpty ? charts.priority : charts.block,
        ),
      ),
    );

    final statusCard = AnalyticsPanel(
      title: 'Статусы',
      child: plot(
        (charts) => AnalyticsDonutChart(
          points: charts.statusGroup,
          preferStatusColors: true,
        ),
      ),
    );

    final resolutionTrendCard = AnalyticsPanel(
      title: 'Динамика среднего времени решения',
      child: plot(
        (charts) => AnalyticsResolutionTrendChart(buckets: charts.dailyDetail),
      ),
    );

    final executorTrend = data?.executorTrend;
    final spaceRow = showSpaceCharts && (skeleton || executorTrend != null)
        ? _ResponsiveRow(
            wide: wide,
            height: tallChartHeight,
            gap: gap,
            children: [
              AnalyticsPanel(
                title: 'Топ исполнителей (закрыто по периодам)',
                child: plot(
                  (charts) => AnalyticsExecutorTrendChart(
                    trend: charts.executorTrend!,
                  ),
                ),
              ),
              AnalyticsPanel(
                title: 'Исполнители',
                child: plot((charts) => AnalyticsDonutChart(points: charts.executor)),
              ),
              AnalyticsPanel(
                title: 'Топ авторов',
                child: plot((charts) => AnalyticsDonutChart(points: charts.author)),
              ),
            ],
          )
        : null;

    final executorBar = !showSpaceCharts &&
            (skeleton || (data?.executor.isNotEmpty ?? false))
        ? AnalyticsPanel(
            title: 'Исполнители',
            child: plot(
              (charts) => AnalyticsHorizontalBarChart(points: charts.executor),
            ),
          )
        : null;

    if (!wide) {
      return Column(
        children: [
          SizedBox(height: tallChartHeight, child: trendCard),
          SizedBox(height: gap),
          SizedBox(height: chartHeight, child: typeCard),
          SizedBox(height: gap),
          SizedBox(height: chartHeight, child: priorityCard),
          SizedBox(height: gap),
          SizedBox(height: chartHeight, child: statusCard),
          SizedBox(height: gap),
          SizedBox(height: tallChartHeight, child: resolutionTrendCard),
          if (spaceRow != null) ...[SizedBox(height: gap), spaceRow],
          if (executorBar != null) ...[
            SizedBox(height: gap),
            SizedBox(height: chartHeight, child: executorBar),
          ],
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
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: priorityCard),
              SizedBox(width: 12.w),
              Expanded(child: statusCard),
            ],
          ),
        ),
        SizedBox(height: gap),
        SizedBox(height: tallChartHeight, child: resolutionTrendCard),
        if (spaceRow != null) ...[SizedBox(height: gap), spaceRow],
        if (executorBar != null) ...[
          SizedBox(height: gap),
          SizedBox(height: chartHeight, child: executorBar),
        ],
      ],
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

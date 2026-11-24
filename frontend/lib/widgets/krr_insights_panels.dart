import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/analytics_dashboard.dart';
import '../models/analytics_filters.dart';
import '../models/krr_dashboard.dart';
import '../services/krr_api.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/analytics_tables.dart';
import '../widgets/ddt_dialog.dart';
import '../widgets/ddt_filter_dropdown.dart';

String formatKrrNumber(num value, {int digits = 0}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(digits);
  final parts = fixed.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ' ',
  );
  final text = digits > 0 ? '$whole,${parts[1]}' : whole;
  return negative ? '-$text' : text;
}

String formatKrrPercent(double? value) =>
    value == null ? 'Недоступно' : '${value.toStringAsFixed(1)}%';

typedef KrrIssueOpener = void Function(String issue, String title);

class KrrWorkInsightPanels extends StatefulWidget {
  const KrrWorkInsightPanels({
    super.key,
    required this.insights,
    required this.charts,
    required this.wide,
    required this.chartHeight,
    required this.onOpen,
    this.skeleton = false,
  });

  final KrrInsights? insights;
  final KrrCharts? charts;
  final bool wide;
  final double chartHeight;
  final KrrIssueOpener onOpen;
  final bool skeleton;

  @override
  State<KrrWorkInsightPanels> createState() => _KrrWorkInsightPanelsState();
}

class _KrrWorkInsightPanelsState extends State<KrrWorkInsightPanels> {
  _KrrTrendMode _mode = _KrrTrendMode.versions;
  AnalyticsTrendGroupBy _group = AnalyticsTrendGroupBy.month;
  bool _byYear = false;
  bool _oivAscending = false;
  bool _oivExpanded = false;
  String _category = 'type_object';
  _KrrYearMetric _yearMetric = _KrrYearMetric.works;

  @override
  Widget build(BuildContext context) {
    final insights = widget.insights;
    final charts = widget.charts;
    final loading = widget.skeleton || insights == null || charts == null;
    Widget plot(Widget child) =>
        loading ? const AnalyticsSkeletonFill() : child;

    final created = _series(charts, created: true);
    final changed = _series(charts, created: false);
    final trend = mergeKrrTrend(created, changed, byYear: _byYear);
    final schedule = insights?.schedule ?? const KrrSchedule();
    final schedulePoints = [
      AnalyticsCountPoint(label: 'Досрочно', value: schedule.early),
      AnalyticsCountPoint(label: 'В срок', value: schedule.onTime),
      AnalyticsCountPoint(label: 'С опозданием', value: schedule.late),
      AnalyticsCountPoint(label: 'Не завершены', value: schedule.unfinished),
      AnalyticsCountPoint(label: 'Неполные даты', value: schedule.incompleteDates),
    ];
    final oiv = [...?insights?.oiv];
    oiv.sort((a, b) => _oivAscending ? a.value.compareTo(b.value) : b.value.compareTo(a.value));
    final categoryPoints = insights?.categories[_category] ?? const <AnalyticsCountPoint>[];
    final yearPoints = switch (_yearMetric) {
      _KrrYearMetric.works => insights?.yearWorks ?? const <AnalyticsCountPoint>[],
      _KrrYearMetric.versions => insights?.yearVersions ?? const <AnalyticsCountPoint>[],
      _KrrYearMetric.square => insights?.yearSquare ?? const <AnalyticsCountPoint>[],
    };

    Widget panel(String title, Widget child, {String? subtitle, Widget? trailing, double? height}) {
      return SizedBox(
        height: height ?? widget.chartHeight,
        child: AnalyticsPanel(
          title: title,
          subtitle: subtitle,
          headerTrailing: trailing,
          child: child,
        ),
      );
    }

    final flow = panel(
      'Динамика создания и редактирования',
      plot(
        AnalyticsTrendChart(
          trend: trend,
          isLine: true,
          secondarySeriesName: 'Изменённые',
        ),
      ),
      subtitle: insights?.snapshotNote ?? 'Текущий снимок версий',
      trailing: _modeControl(),
    );
    final stages = panel(
      'Распределение по статусам',
      plot(
        AnalyticsDonutChart(
          points: insights?.stageBuckets ?? const [],
          preferStatusColors: true,
          onSliceTap: (label) => widget.onOpen('stage:$label', label),
        ),
      ),
      subtitle: 'Последняя версия каждой работы',
    );
    final departments = panel(
      'Ведомственные ОИВ',
      plot(
        AnalyticsHorizontalBarChart(
          points: oiv,
          limit: _oivExpanded ? oiv.length : 10,
          onSelect: (label) => widget.onOpen('oiv:$label', label),
        ),
      ),
      subtitle: _oivExpanded ? 'Полный загруженный список' : 'TOP-10, нажмите столбец для списка работ',
      height: _oivExpanded ? (widget.chartHeight + 180.h) : widget.chartHeight,
      trailing: Wrap(
        spacing: 8.w,
        children: [
          TextButton(
            onPressed: loading ? null : () => setState(() => _oivAscending = !_oivAscending),
            child: Text(_oivAscending ? 'По возрастанию' : 'По убыванию'),
          ),
          TextButton(
            onPressed: loading ? null : () => setState(() => _oivExpanded = !_oivExpanded),
            child: Text(_oivExpanded ? 'Свернуть' : 'Весь список'),
          ),
        ],
      ),
    );
    final years = panel(
      'Динамика работ по годам',
      plot(
        AnalyticsBarChart(
          points: yearPoints,
          onBarTap: (label) => widget.onOpen(
            'year:${_yearMetric.name}:$label',
            '$label · ${_yearMetric.label}',
          ),
        ),
      ),
      subtitle: _yearMetric == _KrrYearMetric.square
          ? 'Сумма площади последних версий'
          : 'Нажмите столбец, чтобы открыть записи',
      trailing: _choice(
        summary: _yearMetric.label,
        options: const [
          DdtFilterOption(key: 'works', label: 'Работы'),
          DdtFilterOption(key: 'versions', label: 'Версии'),
          DdtFilterOption(key: 'square', label: 'Площадь'),
        ],
        selected: _yearMetric.name,
        onSelected: (key) => setState(() {
          _yearMetric = _KrrYearMetric.values.firstWhere((item) => item.name == key);
        }),
      ),
    );
    final plan = panel(
      'План и факт выполнения',
      plot(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScheduleSummary(schedule: schedule),
            SizedBox(height: 8.h),
            Expanded(
              child: AnalyticsBarChart(
                points: schedulePoints,
                colorForIndex: _scheduleColor,
                onBarTap: (label) {
                  const codes = {
                    'Досрочно': 'early',
                    'В срок': 'on_time',
                    'С опозданием': 'late',
                    'Не завершены': 'unfinished',
                    'Неполные даты': 'incomplete',
                  };
                  final code = codes[label];
                  if (code != null) widget.onOpen('schedule:$code', label);
                },
              ),
            ),
          ],
        ),
      ),
      subtitle: 'Незавершённые не считаются просроченными. Просрочка открытых работ: ${schedule.overdueOpen}',
    );
    final reasons = panel(
      'Причины отмены',
      plot(
        AnalyticsHorizontalBarChart(
          points: insights?.cancelReasons ?? const [],
          limit: 12,
          onSelect: (label) => widget.onOpen('cancel:$label', label),
        ),
      ),
      subtitle: 'Нажмите причину, чтобы открыть работы',
    );
    final categories = panel(
      'Распределение по категориям',
      plot(
        _category == 'card_type_name'
            ? const _UnavailableNote(
                text: 'Поле card_type_name в наборе данных отсутствует.',
              )
            : AnalyticsHorizontalBarChart(
                points: categoryPoints,
                limit: 12,
                onSelect: (label) => widget.onOpen(
                  'category:$_category:$label',
                  label,
                ),
              ),
      ),
      trailing: _choice(
        summary: _categoryLabel(_category),
        options: const [
          DdtFilterOption(key: 'type_object', label: 'Тип объекта'),
          DdtFilterOption(key: 'category_object_name', label: 'Категория'),
          DdtFilterOption(key: 'subcategory_object_name', label: 'Подкатегория'),
          DdtFilterOption(key: 'program', label: 'Программа'),
          DdtFilterOption(key: 'card_type_name', label: 'Тип карточки'),
        ],
        selected: _category,
        onSelected: (key) => setState(() => _category = key),
      ),
    );

    Widget pair(Widget left, Widget right) {
      if (!widget.wide) {
        return Column(
          children: [
            left,
            SizedBox(height: 12.h),
            right,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          SizedBox(width: 12.w),
          Expanded(child: right),
        ],
      );
    }

    return DashboardSkeletonScope(
      loading: loading,
      child: Column(
      children: [
        flow,
        SizedBox(height: 12.h),
        pair(stages, departments),
        SizedBox(height: 12.h),
        pair(years, plan),
        SizedBox(height: 12.h),
        pair(reasons, categories),
      ],
      ),
    );
  }

  List<AnalyticsCountPoint> _series(KrrCharts? charts, {required bool created}) {
    if (charts == null) return const [];
    final series = switch (_mode) {
      _KrrTrendMode.versions => created ? charts.created : charts.changed,
      _KrrTrendMode.works => created ? charts.createdWork : charts.changedWork,
      _KrrTrendMode.cards => created ? charts.createdCard : charts.changedCard,
    };
    if (_byYear) return series.month;
    return series.forGroup(_group);
  }

  Widget _modeControl() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 6.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _choice(
          summary: _mode.label,
          width: 150,
          options: [
            for (final item in _KrrTrendMode.values)
              DdtFilterOption(key: item.name, label: item.label),
          ],
          selected: _mode.name,
          onSelected: (key) => setState(() {
            _mode = _KrrTrendMode.values.firstWhere((item) => item.name == key);
          }),
        ),
        _choice(
          summary: _byYear
              ? 'по годам'
              : switch (_group) {
                  AnalyticsTrendGroupBy.day => 'по дням',
                  AnalyticsTrendGroupBy.week => 'по неделям',
                  AnalyticsTrendGroupBy.month => 'по месяцам',
                },
          width: 150,
          options: const [
            DdtFilterOption(key: 'day', label: 'по дням'),
            DdtFilterOption(key: 'week', label: 'по неделям'),
            DdtFilterOption(key: 'month', label: 'по месяцам'),
            DdtFilterOption(key: 'year', label: 'по годам'),
          ],
          selected: _byYear ? 'year' : _group.name,
          onSelected: (key) => setState(() {
            _byYear = key == 'year';
            if (!_byYear) {
              _group = AnalyticsTrendGroupBy.values.firstWhere(
                (item) => item.name == key,
              );
            }
          }),
        ),
      ],
    );
  }
}

enum _KrrTrendMode {
  versions('Версии'),
  works('Работы'),
  cards('Карточка');

  const _KrrTrendMode(this.label);
  final String label;
}

enum _KrrYearMetric {
  works('Работы'),
  versions('Версии'),
  square('Площадь');

  const _KrrYearMetric(this.label);
  final String label;
}

String _categoryLabel(String key) => switch (key) {
  'type_object' => 'Тип объекта',
  'category_object_name' => 'Категория',
  'subcategory_object_name' => 'Подкатегория',
  'program' => 'Программа',
  'card_type_name' => 'Тип карточки',
  _ => key,
};

class KrrQualityPanels extends StatelessWidget {
  const KrrQualityPanels({
    super.key,
    required this.insights,
    required this.chartHeight,
    required this.wide,
    required this.onOpen,
    this.skeleton = false,
  });

  final KrrInsights? insights;
  final double chartHeight;
  final bool wide;
  final KrrIssueOpener onOpen;
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    final loading = skeleton || insights == null;
    final data = insights ?? const KrrInsights();
    final quality = data.quality;
    return DashboardSkeletonScope(
      loading: loading,
      child: Column(
      children: [
        _QualityIndexSection(
          quality: quality,
          wide: wide,
          chartHeight: chartHeight,
          loading: loading,
        ),
        SizedBox(height: 12.h),
        _QualityBarPanel(
          title: 'Полнота заполнения',
          subtitle: 'Процент заполненных значений. Нажмите строку, чтобы открыть пропуски.',
          percentScale: true,
          points: [
            for (final field in data.fields)
              AnalyticsCountPoint(
                label: field.label,
                value: (field.percent ?? 0).round(),
              ),
          ],
          onSelect: (label) {
            for (final field in data.fields) {
              if (field.label == label && field.empty > 0) {
                onOpen('field:${field.key}', 'Не заполнено: ${field.label}');
                return;
              }
            }
          },
        ),
        SizedBox(height: 12.h),
        _QualityBarPanel(
          title: 'Логическая согласованность',
          subtitle: 'Доля работ без ошибки. Ближе к 100% — лучше. Нажмите строку, чтобы открыть ошибки.',
          percentScale: true,
          points: [
            for (final rule in data.rules)
              AnalyticsCountPoint(
                label: rule.title,
                value: data.works <= 0
                    ? 0
                    : (((data.works - rule.count.clamp(0, data.works)) / data.works) * 100).round(),
              ),
          ],
          onSelect: (label) {
            for (final rule in data.rules) {
              if (rule.title == label && rule.count > 0) {
                onOpen('rule:${rule.code}', rule.title);
                return;
              }
            }
          },
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: chartHeight,
          child: AnalyticsPanel(
            title: 'Версии работ',
            subtitle: data.worksMissingFirstVersion == null
                ? 'Проверка первой версии недоступна: номера version не числовые'
                : 'Повторы номера версии: ${data.repeatedVersionWorks}. Без первой версии: ${data.worksMissingFirstVersion}. Дубли id_unique: ${data.duplicateIdUnique}',
            child: AnalyticsBarChart(
              points: data.versionBuckets,
              onBarTap: (label) => onOpen('versions:$label', label),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        SizedBox(height: 12.h),
        SizedBox(
          height: chartHeight,
          child: wide
              ? Row(
                  children: [
                    Expanded(child: _freshnessPanel(data)),
                    SizedBox(width: 12.w),
                    Expanded(child: _stalePanel(data)),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: _freshnessPanel(data)),
                    SizedBox(height: 12.h),
                    Expanded(child: _stalePanel(data)),
                  ],
                ),
        ),
        if (data.rowsWithoutWorkId > 0) ...[
          SizedBox(height: 12.h),
          Text(
            'Строк без id_work: ${data.rowsWithoutWorkId}. Они входят в снимок версий и не входят в показатели уникальных работ.',
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              color: DdtTheme.textMuted(context),
            ),
          ),
        ],
      ],
      ),
    );
  }

  Widget _freshnessPanel(KrrInsights data) {
    final avg = data.freshnessAvgDays;
    final total = data.freshness.fold<int>(0, (sum, item) => sum + item.value);
    final shares = [
      for (final item in data.freshness)
        if (total > 0)
          '${item.label}: ${item.value} (${(item.value / total * 100).toStringAsFixed(0)}%)',
    ].join(' · ');
    final age = avg == null
        ? 'Средний возраст недоступен: нет дат изменения'
        : 'Средний возраст ${avg.toStringAsFixed(1)} дн. · с датой ${data.freshnessKnown}';
    return AnalyticsPanel(
      title: 'Актуальность',
      subtitle: shares.isEmpty ? age : '$age. $shares',
      child: AnalyticsBarChart(
        points: data.freshness,
        onBarTap: (label) => onOpen('freshness:$label', label),
      ),
    );
  }

  Widget _stalePanel(KrrInsights data) {
    return AnalyticsPanel(
      title: 'Дольше года без изменений',
      subtitle: 'По ведомствам, нажмите строку для записей',
      child: AnalyticsHorizontalBarChart(
        points: data.staleByOiv,
        limit: 10,
        onSelect: (label) => onOpen('stale_oiv:$label', label),
      ),
    );
  }
}

class KrrMissingAreaTable extends StatelessWidget {
  const KrrMissingAreaTable({
    super.key,
    required this.rows,
    required this.total,
    required this.onOpen,
  });

  final List<KrrIssueRow> rows;
  final int total;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AnalyticsPanel(
      title: 'Работы без округа и района',
      subtitle: total == 0 ? 'Таких записей нет' : 'Показано ${rows.length} из $total',
      expandChild: false,
      headerTrailing: total == 0
          ? null
          : TextButton(onPressed: onOpen, child: const Text('Все записи')),
      child: rows.isEmpty
          ? const SizedBox(height: 72, child: AnalyticsEmptyChart())
          : KrrIssueTable(rows: rows, problem: 'Нет округа и района', fitContent: true),
    );
  }
}

class _QualityIndexSection extends StatefulWidget {
  const _QualityIndexSection({
    required this.quality,
    required this.wide,
    required this.chartHeight,
    required this.loading,
  });

  final KrrQualityIndex quality;
  final bool wide;
  final double chartHeight;
  final bool loading;

  @override
  State<_QualityIndexSection> createState() => _QualityIndexSectionState();
}

class _QualityIndexSectionState extends State<_QualityIndexSection> {
  final _cardsKey = GlobalKey();
  double? _cardsHeight;

  void _syncGaugeHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.wide) return;
      final box = _cardsKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final next = box.size.height;
      final current = _cardsHeight;
      if (current != null && (next - current).abs() < 0.5) return;
      setState(() => _cardsHeight = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.quality.score;
    final parts = [
      ('Полнота', widget.quality.completeness, widget.quality.weights['completeness'], const Color(0xFF3E9B74)),
      ('Корректность', widget.quality.correctness, widget.quality.weights['correctness'], const Color(0xFF4A90C2)),
      ('Согласованность', widget.quality.consistency, widget.quality.weights['consistency'], const Color(0xFFD4943A)),
      ('Актуальность', widget.quality.freshness, widget.quality.weights['freshness'], const Color(0xFF7D6BC4)),
      ('Уникальность', widget.quality.uniqueness, widget.quality.weights['uniqueness'], analyticsPositiveColor),
    ];
    final gauge = AnalyticsPanel(
      title: 'Индекс качества данных',
      subtitle: 'Доля пройденных проверок',
      child: AnalyticsFillGauge(percent: score),
    );
    final cards = Column(
      children: [
        for (var index = 0; index < parts.length; index++) ...[
          if (index > 0) SizedBox(height: 8.h),
          AnalyticsKpiCard(
            label: parts[index].$1,
            value: formatKrrPercent(parts[index].$2),
            hint: parts[index].$3 == null
                ? null
                : 'вес ${(parts[index].$3! * 100).toStringAsFixed(0)}%',
            color: parts[index].$4,
            skeleton: widget.loading,
          ),
        ],
      ],
    );
    if (!widget.wide) {
      return Column(
        children: [
          SizedBox(height: widget.chartHeight, child: gauge),
          SizedBox(height: 12.h),
          cards,
        ],
      );
    }
    _syncGaugeHeight();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: _cardsHeight ?? widget.chartHeight,
            child: gauge,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          flex: 2,
          child: KeyedSubtree(key: _cardsKey, child: cards),
        ),
      ],
    );
  }
}

class _QualityBarPanel extends StatelessWidget {
  const _QualityBarPanel({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.onSelect,
    this.percentScale = false,
  });

  final String title;
  final String subtitle;
  final List<AnalyticsCountPoint> points;
  final ValueChanged<String> onSelect;
  final bool percentScale;

  @override
  Widget build(BuildContext context) {
    final rows = points.isEmpty ? 1 : points.length;
    return SizedBox(
      height: 88.h + rows * 32.h,
      child: AnalyticsPanel(
        title: title,
        subtitle: subtitle,
        child: points.isEmpty
            ? const AnalyticsEmptyChart()
            : AnalyticsHorizontalBarChart(
                points: points,
                limit: rows,
                onSelect: onSelect,
                percentScale: percentScale,
              ),
      ),
    );
  }
}

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.schedule});

  final KrrSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final style = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textSecondary(context),
    );
    final deviation = schedule.avgDeviationDays;
    final duration = schedule.avgDurationDays;
    return Text(
      'В срок ${formatKrrPercent(schedule.onTimeShare)} · досрочно ${formatKrrPercent(schedule.earlyShare)} · срыв ${formatKrrPercent(schedule.lateShare)}'
      ' · отклонение ${deviation == null ? 'недоступно' : '${deviation.toStringAsFixed(1)} дн.'}'
      ' · длительность ${duration == null ? 'недоступна' : '${duration.toStringAsFixed(1)} дн.'}',
      style: style,
    );
  }
}

class _UnavailableNote extends StatelessWidget {
  const _UnavailableNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: DdtTheme.style(
          fontSize: DdtTypography.labelSmallSize,
          color: DdtTheme.textMuted(context),
        ),
      ),
    );
  }
}

class KrrIssueTable extends StatelessWidget {
  const KrrIssueTable({
    super.key,
    required this.rows,
    required this.problem,
    this.fitContent = false,
  });

  final List<KrrIssueRow> rows;
  final String problem;
  final bool fitContent;

  @override
  Widget build(BuildContext context) {
    final style = DdtTheme.style(
      fontSize: DdtTypography.labelSmallSize,
      color: DdtTheme.textPrimary(context),
    );
    Widget cell(String text) => Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style);
    return AnalyticsDataTable(
      fitContent: fitContent,
      columns: const [
        AnalyticsTableColumn('id_unique', width: 110),
        AnalyticsTableColumn('id_work', width: 110),
        AnalyticsTableColumn('Версия', width: 220),
        AnalyticsTableColumn('Адрес', width: 180),
        AnalyticsTableColumn('Стадия', width: 120),
        AnalyticsTableColumn('Проблема', width: 180),
        AnalyticsTableColumn('Карточка', width: 90),
      ],
      rows: [
        for (final row in rows)
          [
            cell('${row.idUnique}'),
            cell(row.idWork?.toString() ?? '—'),
            cell(row.name ?? '—'),
            cell(row.address ?? '—'),
            cell(row.stage ?? '—'),
            cell(row.problem.isEmpty ? problem : row.problem),
            _IssueLink(url: row.link),
          ],
      ],
    );
  }
}

class _IssueLink extends StatelessWidget {
  const _IssueLink({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final link = url;
    if (link == null || link.isEmpty) {
      return Text(
        '—',
        style: DdtTheme.style(
          fontSize: DdtTypography.labelSmallSize,
          color: DdtTheme.textMuted(context),
        ),
      );
    }
    return TextButton(
      onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
      child: const Text('Открыть'),
    );
  }
}

Future<void> showKrrIssueDialog(
  BuildContext context, {
  required AnalyticsFilters filters,
  required String issue,
  required String title,
}) {
  return showDdtDialog<void>(
    context: context,
    width: 980,
    height: 640,
    builder: (dialogContext) => _KrrIssueDialog(
      filters: filters,
      issue: issue,
      title: title,
    ),
  );
}

class _KrrIssueDialog extends StatefulWidget {
  const _KrrIssueDialog({
    required this.filters,
    required this.issue,
    required this.title,
  });

  final AnalyticsFilters filters;
  final String issue;
  final String title;

  @override
  State<_KrrIssueDialog> createState() => _KrrIssueDialogState();
}

class _KrrIssueDialogState extends State<_KrrIssueDialog> {
  KrrIssuePage? _page;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await krrApiInstance.issues(
        filters: widget.filters,
        issue: widget.issue,
      );
      if (!mounted) return;
      setState(() => _page = page);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.panelTitleSize,
                    fontWeight: FontWeight.w800,
                    color: DdtTheme.textPrimary(context),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (page != null)
            Text(
              'Найдено ${page.total}. Показаны первые ${page.items.length}.',
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSmallSize,
                color: DdtTheme.textMuted(context),
              ),
            ),
          SizedBox(height: 8.h),
          Expanded(
            child: page == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : Text(
                            _error.toString().replaceFirst('Exception: ', ''),
                            style: DdtTheme.style(
                              fontSize: DdtTypography.labelSmallSize,
                              color: const Color(0xFFD65C5C),
                            ),
                          ),
                  )
                : KrrIssueTable(rows: page.items, problem: page.problem),
          ),
        ],
      ),
    );
  }
}

Widget _choice({
  required String summary,
  required List<DdtFilterOption> options,
  required String selected,
  required ValueChanged<String> onSelected,
  double width = 168,
}) {
  return SizedBox(
    width: width.w,
    child: DdtSearchableFilterDropdown(
      summary: summary,
      active: false,
      multi: false,
      options: options,
      selected: {selected},
      onSelected: onSelected,
    ),
  );
}

Color _scheduleColor(int index) => switch (index) {
  0 => analyticsPositiveColor,
  1 => const Color(0xFF4A90C2),
  2 => const Color(0xFFD65C5C),
  3 => const Color(0xFF6B7C93),
  _ => const Color(0xFFD4943A),
};

AnalyticsTrendBuckets mergeKrrTrend(
  List<AnalyticsCountPoint> created,
  List<AnalyticsCountPoint> changed, {
  required bool byYear,
}) {
  final createdMap = <int, int>{};
  final changedMap = <int, int>{};
  final labels = <int, String>{};
  void take(List<AnalyticsCountPoint> points, Map<int, int> target) {
    for (final point in points) {
      final key = _trendKey(point.label, byYear: byYear);
      if (key == null) continue;
      target[key] = (target[key] ?? 0) + point.value;
      labels[key] = byYear ? '$key' : point.label;
    }
  }

  take(created, createdMap);
  take(changed, changedMap);
  final keys = {...createdMap.keys, ...changedMap.keys}.toList()..sort();
  if (keys.isEmpty) return const AnalyticsTrendBuckets();
  return AnalyticsTrendBuckets(
    labels: [for (final key in keys) labels[key] ?? '$key'],
    created: [for (final key in keys) createdMap[key] ?? 0],
    closed: [for (final key in keys) changedMap[key] ?? 0],
  );
}

int? _trendKey(String label, {required bool byYear}) {
  final parts = label.split('.');
  if (parts.length == 2) {
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || year == null) return null;
    return byYear ? year : year * 100 + month;
  }
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final shortYear = int.tryParse(parts[2]);
    if (day == null || month == null || shortYear == null) return null;
    final year = 2000 + shortYear;
    if (byYear) return year;
    return year * 10000 + month * 100 + day;
  }
  return int.tryParse(label);
}

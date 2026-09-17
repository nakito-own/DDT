import 'dart:math' as math;

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/analytics_dashboard.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';

const _palette = <Color>[
  Color(0xFF1976D2),
  Color(0xFF2E7D32),
  Color(0xFFF9A825),
  Color(0xFF7B1FA2),
  Color(0xFF00838F),
  Color(0xFFC62828),
  Color(0xFF546E7A),
  Color(0xFFEF6C00),
];

const _chartDuration = Duration(milliseconds: 420);
const _chartCurve = Curves.easeOutCubic;

Color analyticsStatusColor(String label) {
  final text = label.toLowerCase();
  if (text.contains('заверш')) return const Color(0xFF2E7D32);
  if (text.contains('ожидан')) return const Color(0xFFF9A825);
  if (text.contains('процесс')) return const Color(0xFF1976D2);
  if (text.contains('назнач')) return const Color(0xFF7B1FA2);
  return const Color(0xFF546E7A);
}

Color analyticsSeriesColor(int index) => _palette[index % _palette.length];

class AnalyticsPanel extends StatelessWidget {
  const AnalyticsPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.expandChild = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: DdtTheme.style(
              fontSize: DdtTypography.sectionTitleSize,
              fontWeight: FontWeight.w700,
              color: DdtTheme.textPrimary(context),
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle!,
              style: DdtTheme.style(
                fontSize: DdtTypography.captionSize,
                color: DdtTheme.textMuted(context),
              ),
            ),
          ],
          SizedBox(height: 16.h),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class AnalyticsKpiCard extends StatelessWidget {
  const AnalyticsKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.hint,
  });

  final String label;
  final String value;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 42.h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.captionSize,
                    fontWeight: FontWeight.w600,
                    color: DdtTheme.textMuted(context),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.displaySize,
                    fontWeight: FontWeight.w800,
                    color: DdtTheme.textPrimary(context),
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.microSize,
                      color: DdtTheme.textMuted(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyticsEmptyChart extends StatelessWidget {
  const AnalyticsEmptyChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Нет данных по выбранным темам',
        textAlign: TextAlign.center,
        style: DdtTheme.style(color: DdtTheme.textMuted(context)),
      ),
    );
  }
}

class AnalyticsDonutChart extends StatelessWidget {
  const AnalyticsDonutChart({super.key, required this.points});

  final List<AnalyticsCountPoint> points;

  @override
  Widget build(BuildContext context) {
    final total = points.fold<int>(0, (sum, item) => sum + item.value);
    if (total == 0) return const AnalyticsEmptyChart();

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2,
              centerSpaceRadius: 46,
              pieTouchData: PieTouchData(enabled: true),
              sections: [
                for (final point in points)
                  PieChartSectionData(
                    value: point.value.toDouble(),
                    color: analyticsStatusColor(point.label),
                    radius: 28,
                    title: '${((point.value / total) * 100).round()}%',
                    titleStyle: DdtTheme.style(
                      fontSize: DdtTypography.microSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            duration: _chartDuration,
            curve: _chartCurve,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          flex: 6,
          child: ListView.separated(
            itemCount: points.length,
            separatorBuilder: (_, _) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              final point = points[index];
              final percent = (point.value / total * 100).round();
              return Row(
                children: [
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: analyticsStatusColor(point.label),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      point.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSmallSize,
                        color: DdtTheme.textSecondary(context),
                      ),
                    ),
                  ),
                  Text(
                    '${point.value} · $percent%',
                    style: DdtTheme.style(
                      fontSize: DdtTypography.labelSmallSize,
                      fontWeight: FontWeight.w700,
                      color: DdtTheme.textPrimary(context),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class AnalyticsBarChart extends StatelessWidget {
  const AnalyticsBarChart({
    super.key,
    required this.points,
    this.colorForIndex,
    this.onBarTap,
  });

  final List<AnalyticsCountPoint> points;
  final Color Function(int index)? colorForIndex;
  final ValueChanged<String>? onBarTap;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const AnalyticsEmptyChart();

    final maxValue = points.fold<int>(1, (sum, item) => math.max(sum, item.value));
    final gridColor = DdtTheme.textMuted(context).withValues(alpha: 0.18);
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textMuted(context),
    );

    return BarChart(
      BarChartData(
        maxY: maxValue * 1.18,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: math.max(1, (maxValue / 4).ceilToDouble()),
          getDrawingHorizontalLine: (value) => FlLine(
            color: gridColor,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text('${value.toInt()}', style: labelStyle);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: SizedBox(
                    width: 56.w,
                    child: Text(
                      points[index].label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (event is! FlTapUpEvent) return;
            final index = response?.spot?.touchedBarGroupIndex;
            if (index == null || index < 0 || index >= points.length) return;
            onBarTap?.call(points[index].label);
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => DdtTheme.pickerSurfaceColor(context),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final point = points[group.x];
              return BarTooltipItem(
                '${point.label}\n${point.value}',
                DdtTheme.style(
                  fontSize: DdtTypography.labelSmallSize,
                  fontWeight: FontWeight.w700,
                  color: DdtTheme.textPrimary(context),
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var index = 0; index < points.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: points[index].value.toDouble(),
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                  color: colorForIndex?.call(index) ?? analyticsSeriesColor(index),
                ),
              ],
            ),
        ],
      ),
      duration: _chartDuration,
      curve: _chartCurve,
    );
  }
}

class AnalyticsWeeklyChart extends StatelessWidget {
  const AnalyticsWeeklyChart({super.key, required this.points});

  final List<AnalyticsCountPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const AnalyticsEmptyChart();

    final maxValue = points.fold<int>(1, (sum, item) => math.max(sum, item.value));
    final gridColor = DdtTheme.textMuted(context).withValues(alpha: 0.18);
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textMuted(context),
    );
    final spots = [
      for (var index = 0; index < points.length; index++)
        FlSpot(index.toDouble(), points[index].value.toDouble()),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(1, points.length - 1).toDouble(),
        minY: 0,
        maxY: maxValue * 1.18,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: gridColor,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => DdtTheme.pickerSurfaceColor(context),
            getTooltipItems: (touched) {
              return [
                for (final spot in touched)
                  LineTooltipItem(
                    '${points[spot.x.toInt()].label}\n${spot.y.toInt()}',
                    DdtTheme.style(
                      fontSize: DdtTypography.labelSmallSize,
                      fontWeight: FontWeight.w700,
                      color: DdtTheme.textPrimary(context),
                    ),
                  ),
              ];
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text('${value.toInt()}', style: labelStyle);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(points[index].label, style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.primary,
                strokeWidth: 2,
                strokeColor: DdtTheme.pickerSurfaceColor(context),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
      duration: _chartDuration,
      curve: _chartCurve,
    );
  }
}

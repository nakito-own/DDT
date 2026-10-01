import 'dart:math' as math;

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/analytics_dashboard.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/analytics_formatters.dart';

/// Closed and success series: lighter and more saturated than a dark forest green.
const analyticsPositiveColor = Color(0xFF22C55E);

List<Color> get _palette => [
  AppColors.primary,
  analyticsPositiveColor,
  const Color(0xFFF9A825),
  const Color(0xFF7B1FA2),
  const Color(0xFF00838F),
  const Color(0xFFC62828),
  const Color(0xFF546E7A),
  const Color(0xFFEF6C00),
];

const _chartDuration = Duration(milliseconds: 420);
const _chartCurve = Curves.easeOutCubic;
const _axisChartHeight = 260.0;

Color _chartTooltipBg(BuildContext context) =>
    DdtTheme.chartTooltipBackground(context);

TextStyle _chartTooltipTextStyle(BuildContext context) =>
    DdtTheme.chartTooltipTextStyle(context);

BorderSide _chartTooltipBorder(BuildContext context) =>
    BorderSide(color: DdtTheme.textMuted(context).withValues(alpha: 0.35));

BoxDecoration _chartTooltipDecoration(BuildContext context) => BoxDecoration(
  color: _chartTooltipBg(context),
  borderRadius: BorderRadius.circular(4),
  border: Border.fromBorderSide(_chartTooltipBorder(context)),
);

const _tooltipPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
const _tooltipIn = Duration(milliseconds: 150);
const _tooltipOut = Duration(milliseconds: 75);

/// Slightly tighter than the previous rod caps.
const _rodRadiusWide = 4.0;
const _rodRadius = 3.0;
const _rodRadiusThin = 2.0;

/// Grows rods when the plot has spare width, and keeps [minWidth] when crowded.
double _flexibleRodWidth({
  required double chartWidth,
  required int groupCount,
  required int rodsPerGroup,
  required double minWidth,
  double axisReserve = 32,
  double barsSpace = 2,
  double maxWidth = 48,
}) {
  if (groupCount <= 0 || rodsPerGroup <= 0) return minWidth;
  if (!chartWidth.isFinite || chartWidth <= 0) return minWidth;
  final plot = math.max(0.0, chartWidth - axisReserve);
  final innerGaps = math.max(0, rodsPerGroup - 1) * barsSpace;
  final slot = plot / groupCount;
  final width = (slot * 0.68 - innerGaps) / rodsPerGroup;
  if (!width.isFinite) return minWidth;
  return width.clamp(minWidth, maxWidth);
}

/// Thickens horizontal bars when each row has spare height.
double _horizontalBarThickness({
  required double chartHeight,
  required int rowCount,
  required double minHeight,
  required double maxHeight,
  required double rowPadding,
}) {
  if (rowCount <= 0 || !chartHeight.isFinite || chartHeight <= 0) {
    return minHeight;
  }
  final room = chartHeight / rowCount - rowPadding;
  if (!room.isFinite || room <= minHeight) return minHeight;
  final thickness = minHeight + (room - minHeight) * 0.35;
  return thickness.clamp(minHeight, math.min(maxHeight, room));
}

Offset? _flEventGlobalPosition(FlTouchEvent touch) {
  return switch (touch) {
    FlPointerHoverEvent(:final event) => event.position,
    FlPointerEnterEvent(:final event) => event.position,
    FlPointerExitEvent(:final event) => event.position,
    FlTapDownEvent(:final details) => details.globalPosition,
    FlTapUpEvent(:final details) => details.globalPosition,
    FlPanDownEvent(:final details) => details.globalPosition,
    FlPanStartEvent(:final details) => details.globalPosition,
    FlPanUpdateEvent(:final details) => details.globalPosition,
    FlLongPressStart(:final details) => details.globalPosition,
    FlLongPressMoveUpdate(:final details) => details.globalPosition,
    FlLongPressEnd(:final details) => details.globalPosition,
    _ => null,
  };
}

void _syncChartTooltip({
  required _ChartTooltipController tooltip,
  required FlTouchEvent event,
  required bool visible,
  required String message,
  Offset? chartLocal,
}) {
  if (!visible || !event.isInterestedForInteractions) {
    tooltip.hide();
    return;
  }
  final global = _flEventGlobalPosition(event);
  final local = event.localPosition;
  if (global == null) return;
  final anchor = chartLocal == null || local == null
      ? global
      : global - local + chartLocal;
  tooltip.show(message, anchor);
}

class _ChartTooltipController extends ChangeNotifier {
  String? message;
  Offset? globalAnchor;

  void show(String nextMessage, Offset anchor) {
    if (message == nextMessage &&
        globalAnchor != null &&
        (globalAnchor! - anchor).distanceSquared < 0.25) {
      return;
    }
    message = nextMessage;
    globalAnchor = anchor;
    notifyListeners();
  }

  void hide() {
    if (message == null && globalAnchor == null) return;
    message = null;
    globalAnchor = null;
    notifyListeners();
  }

  @override
  void dispose() {
    message = null;
    globalAnchor = null;
    super.dispose();
  }
}

/// Keeps the chart subtree stable while the tooltip fades in and out.
class _ChartTooltipHost extends StatefulWidget {
  const _ChartTooltipHost({required this.builder});

  final Widget Function(_ChartTooltipController tooltip) builder;

  @override
  State<_ChartTooltipHost> createState() => _ChartTooltipHostState();
}

class _ChartTooltipHostState extends State<_ChartTooltipHost> {
  final _tooltip = _ChartTooltipController();

  @override
  void dispose() {
    _tooltip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.builder(_tooltip),
        _ChartTooltipOverlay(controller: _tooltip),
      ],
    );
  }
}

class _ChartTooltipOverlay extends StatefulWidget {
  const _ChartTooltipOverlay({required this.controller});

  final _ChartTooltipController controller;

  @override
  State<_ChartTooltipOverlay> createState() => _ChartTooltipOverlayState();
}

class _ChartTooltipOverlayState extends State<_ChartTooltipOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final CurvedAnimation _curved;
  late final Animation<double> _scale;
  String? _message;
  Offset? _anchor;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: _tooltipIn,
      reverseDuration: _tooltipOut,
    );
    _curved = CurvedAnimation(
      parent: _anim,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
    _scale = Tween<double>(begin: 0.92, end: 1).animate(_curved);
    _anim.addStatusListener(_onStatus);
    widget.controller.addListener(_onController);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted) return;
    if (widget.controller.message != null) return;
    if (_message == null) return;
    setState(() {
      _message = null;
      _anchor = null;
    });
  }

  void _onController() {
    if (!mounted) return;
    final next = widget.controller.message;
    final global = widget.controller.globalAnchor;
    if (next == null || global == null) {
      if (_anim.status != AnimationStatus.dismissed) _anim.reverse();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    final wasHidden =
        _message == null || _anim.status == AnimationStatus.dismissed;
    setState(() {
      _message = next;
      _anchor = box.globalToLocal(global);
    });
    if (wasHidden) {
      _anim.forward(from: 0);
    } else if (_anim.status == AnimationStatus.reverse) {
      _anim.forward();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _anim.removeStatusListener(_onStatus);
    _curved.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final anchor = _anchor;
    return Positioned.fill(
      child: IgnorePointer(
        child: message == null || anchor == null
            ? const SizedBox.shrink()
            : CustomSingleChildLayout(
                delegate: _ChartTooltipPositionDelegate(anchor),
                child: FadeTransition(
                  opacity: _curved,
                  child: ScaleTransition(
                    alignment: Alignment.bottomCenter,
                    scale: _scale,
                    child: _ChartTooltipBubble(message: message),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ChartTooltipBubble extends StatelessWidget {
  const _ChartTooltipBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: DecoratedBox(
        decoration: _chartTooltipDecoration(context),
        child: Padding(
          padding: _tooltipPadding,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: _chartTooltipTextStyle(context),
          ),
        ),
      ),
    );
  }
}

class _ChartTooltipPositionDelegate extends SingleChildLayoutDelegate {
  const _ChartTooltipPositionDelegate(this.anchor);

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(maxWidth: math.min(240, constraints.maxWidth));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const margin = 8.0;
    final maxLeft = math.max(margin, size.width - childSize.width - margin);
    final maxTop = math.max(margin, size.height - childSize.height - margin);
    var left = anchor.dx - childSize.width / 2;
    var top = anchor.dy - childSize.height - margin;
    if (top < margin) top = anchor.dy + margin;
    left = left.clamp(margin, maxLeft).toDouble();
    top = top.clamp(margin, maxTop).toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _ChartTooltipPositionDelegate oldDelegate) =>
      oldDelegate.anchor != anchor;
}

Widget _chartHoverTooltip({
  required BuildContext context,
  required String message,
  required Widget child,
}) {
  return Tooltip(
    message: message,
    waitDuration: Duration.zero,
    preferBelow: false,
    constraints: const BoxConstraints(maxWidth: 240),
    decoration: _chartTooltipDecoration(context),
    textStyle: _chartTooltipTextStyle(context),
    padding: _tooltipPadding,
    child: child,
  );
}

/// Plot area that fills the panel body (no nested scroll views).
Widget _chartPlot(
  BuildContext context, {
  required Widget child,
  double? height,
}) {
  if (height != null) {
    return SizedBox(width: double.infinity, height: height.h, child: child);
  }
  return LayoutBuilder(
    builder: (context, constraints) {
      final plotHeight =
          constraints.maxHeight.isFinite && constraints.maxHeight > 0
          ? constraints.maxHeight
          : _axisChartHeight.h;
      return SizedBox(width: double.infinity, height: plotHeight, child: child);
    },
  );
}

Color analyticsStatusColor(String label) {
  final text = label.toLowerCase();
  if (text.contains('закры') || text.contains('заверш')) {
    return analyticsPositiveColor;
  }
  if (text.contains('ожидан')) return const Color(0xFFF9A825);
  if (text.contains('процесс') || text.contains('работ')) {
    return AppColors.primary;
  }
  if (text.contains('назнач')) return const Color(0xFF7B1FA2);
  return const Color(0xFF546E7A);
}

Color analyticsSeriesColor(int index) => _palette[index % _palette.length];

Color analyticsSliceColor(String label, int index) {
  final status = analyticsStatusColor(label);
  if (status != const Color(0xFF546E7A)) return status;
  return analyticsSeriesColor(index);
}

int _chartLabelStep(int count, {int maxLabels = 6}) {
  if (count <= maxLabels) return 1;
  return (count / maxLabels).ceil();
}

class AnalyticsPanel extends StatelessWidget {
  const AnalyticsPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.expandChild = true,
    this.headerTrailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool expandChild;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                  ],
                ),
              ),
              if (headerTrailing != null)
                Align(alignment: Alignment.topRight, child: headerTrailing!),
            ],
          ),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.displaySize,
                      fontWeight: FontWeight.w800,
                      color: DdtTheme.textPrimary(context),
                    ),
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
        'Нет данных для текущих фильтров',
        textAlign: TextAlign.center,
        style: DdtTheme.style(color: DdtTheme.textMuted(context)),
      ),
    );
  }
}

class AnalyticsDonutChart extends StatelessWidget {
  const AnalyticsDonutChart({
    super.key,
    required this.points,
    this.preferStatusColors = false,
  });

  final List<AnalyticsCountPoint> points;
  final bool preferStatusColors;

  @override
  Widget build(BuildContext context) {
    final total = points.fold<int>(0, (sum, item) => sum + item.value);
    if (total == 0) return const AnalyticsEmptyChart();

    Color sliceColor(int index, AnalyticsCountPoint point) {
      if (preferStatusColors) {
        return analyticsSliceColor(point.label, index);
      }
      return analyticsSeriesColor(index);
    }

    return _ChartTooltipHost(
      builder: (tooltip) => LayoutBuilder(
        builder: (context, constraints) {
          final boundedHeight =
              constraints.maxHeight.isFinite && constraints.maxHeight > 0;
          final plotHeight = boundedHeight ? constraints.maxHeight : 220.h;
          final sideBySide = constraints.maxWidth >= 420 && plotHeight >= 180;
          final chartSize = sideBySide
              ? math.min(
                  plotHeight - 12,
                  math.min(constraints.maxWidth * 0.42, 220.h),
                )
              : math.min(
                  constraints.maxWidth * 0.55,
                  math.max(140.h, plotHeight * 0.42),
                );

          final pie = SizedBox(
            height: chartSize,
            width: chartSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 2,
                    centerSpaceRadius: chartSize * 0.32,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        final index =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
                        if (!event.isInterestedForInteractions ||
                            index < 0 ||
                            index >= points.length) {
                          tooltip.hide();
                          return;
                        }
                        final point = points[index];
                        final percent = (point.value / total * 100).round();
                        _syncChartTooltip(
                          tooltip: tooltip,
                          event: event,
                          visible: true,
                          message: '${point.label}\n${point.value} · $percent%',
                        );
                      },
                    ),
                    sections: [
                      for (var index = 0; index < points.length; index++)
                        PieChartSectionData(
                          value: points[index].value.toDouble(),
                          color: sliceColor(index, points[index]),
                          radius: chartSize * 0.2,
                          title: points[index].value / total * 100 >= 12
                              ? '${(points[index].value / total * 100).round()}%'
                              : '',
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: DdtTheme.style(
                        fontSize: DdtTypography.sectionTitleSize,
                        fontWeight: FontWeight.w800,
                        color: DdtTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      'всего',
                      style: DdtTheme.style(
                        fontSize: DdtTypography.microSize,
                        color: DdtTheme.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          final legendGap = 36.w;
          final legendWidth = sideBySide
              ? math.min(
                  268.w,
                  math.max(160.w, constraints.maxWidth - chartSize - legendGap),
                )
              : math.min(constraints.maxWidth - 8.w, 320.w);

          Widget legendRow(int index) {
            final point = points[index];
            final percent = (point.value / total * 100).round();
            final color = sliceColor(index, point);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 3.h),
                  child: Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
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
                SizedBox(width: 8.w),
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
          }

          final legendPanel = SizedBox(
            width: legendWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < points.length; index++) ...[
                  if (index > 0) SizedBox(height: 8.h),
                  legendRow(index),
                ],
              ],
            ),
          );

          if (!sideBySide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: legendPanel,
                  ),
                ),
                SizedBox(height: 8.h),
                Expanded(flex: 4, child: Center(child: pie)),
              ],
            );
          }

          return SizedBox(
            height: boundedHeight ? plotHeight : null,
            width: constraints.maxWidth,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  pie,
                  SizedBox(width: legendGap),
                  legendPanel,
                ],
              ),
            ),
          );
        },
      ),
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

    final maxValue = points.fold<int>(
      1,
      (sum, item) => math.max(sum, item.value),
    );
    final gridColor = DdtTheme.textMuted(context).withValues(alpha: 0.18);
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textMuted(context),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final rodWidth = _flexibleRodWidth(
          chartWidth: constraints.maxWidth,
          groupCount: points.length,
          rodsPerGroup: 1,
          minWidth: 14,
          axisReserve: 28,
          maxWidth: 52,
        );
        final chart = _ChartTooltipHost(
          builder: (tooltip) => BarChart(
            BarChartData(
              maxY: maxValue * 1.18,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: math.max(1, (maxValue / 4).ceilToDouble()),
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: gridColor, strokeWidth: 1),
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
                bottomTitles: _chartBottomAxis(
                  labels: points.map((p) => p.label).toList(),
                  labelStyle: labelStyle,
                  maxLabels: 6,
                  angled: points.length > 6,
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  final spot = response?.spot;
                  if (event is FlTapUpEvent &&
                      spot != null &&
                      spot.touchedBarGroupIndex >= 0 &&
                      spot.touchedBarGroupIndex < points.length) {
                    onBarTap?.call(points[spot.touchedBarGroupIndex].label);
                  }
                  if (spot == null ||
                      spot.touchedBarGroupIndex < 0 ||
                      spot.touchedBarGroupIndex >= points.length) {
                    _syncChartTooltip(
                      tooltip: tooltip,
                      event: event,
                      visible: false,
                      message: '',
                    );
                    return;
                  }
                  final point = points[spot.touchedBarGroupIndex];
                  _syncChartTooltip(
                    tooltip: tooltip,
                    event: event,
                    visible: true,
                    message: '${point.label}\n${point.value}',
                    chartLocal: spot.offset,
                  );
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (_, _, _, _) => null,
                ),
              ),
              barGroups: [
                for (var index = 0; index < points.length; index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: points[index].value.toDouble(),
                        width: rodWidth,
                        borderRadius: BorderRadius.circular(_rodRadiusWide),
                        color:
                            colorForIndex?.call(index) ??
                            analyticsSeriesColor(index),
                      ),
                    ],
                  ),
              ],
            ),
            duration: _chartDuration,
            curve: _chartCurve,
          ),
        );

        return _chartPlot(context, child: chart);
      },
    );
  }
}

class AnalyticsWeeklyChart extends StatelessWidget {
  const AnalyticsWeeklyChart({super.key, required this.points});

  final List<AnalyticsCountPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const AnalyticsEmptyChart();

    final maxValue = points.fold<int>(
      1,
      (sum, item) => math.max(sum, item.value),
    );
    final gridColor = DdtTheme.textMuted(context).withValues(alpha: 0.18);
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textMuted(context),
    );
    final spots = [
      for (var index = 0; index < points.length; index++)
        FlSpot(index.toDouble(), points[index].value.toDouble()),
    ];

    return _ChartTooltipHost(
      builder: (tooltip) => LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, points.length - 1).toDouble(),
          minY: 0,
          maxY: maxValue * 1.18,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: gridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchCallback: (event, response) {
              final spots = response?.lineBarSpots;
              if (spots == null || spots.isEmpty) {
                _syncChartTooltip(
                  tooltip: tooltip,
                  event: event,
                  visible: false,
                  message: '',
                );
                return;
              }
              final spot = spots.first;
              final index = spot.x.toInt();
              if (index < 0 || index >= points.length) {
                tooltip.hide();
                return;
              }
              _syncChartTooltip(
                tooltip: tooltip,
                event: event,
                visible: true,
                message: '${points[index].label}\n${spot.y.toInt()}',
              );
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touched) => [for (final _ in touched) null],
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
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
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
      ),
    );
  }
}

class AnalyticsTrendChart extends StatelessWidget {
  const AnalyticsTrendChart({
    super.key,
    required this.trend,
    required this.isLine,
  });

  final AnalyticsTrendBuckets trend;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const AnalyticsEmptyChart();

    final maxValue = [...trend.created, ...trend.closed].fold<int>(1, math.max);
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textMuted(context),
    );
    final gridColor = DdtTheme.textMuted(context).withValues(alpha: 0.18);
    final axisTitles = _chartAxisTitles(
      labels: trend.labels,
      labelStyle: labelStyle,
      maxLabels: 7,
      angled: trend.labels.length > 8,
    );

    if (isLine) {
      final createdSpots = [
        for (var i = 0; i < trend.created.length; i++)
          FlSpot(i.toDouble(), trend.created[i].toDouble()),
      ];
      final closedSpots = [
        for (var i = 0; i < trend.closed.length; i++)
          FlSpot(i.toDouble(), trend.closed[i].toDouble()),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ChartLegend(
            items: [
              _LegendItem('Создано', Color(0xFF1976D2)),
              _LegendItem('Закрыто', analyticsPositiveColor),
            ],
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: _chartPlot(
              context,
              child: _ChartTooltipHost(
                builder: (tooltip) => LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: math.max(1, trend.labels.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxValue * 1.18,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) =>
                          FlLine(color: gridColor, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: axisTitles,
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchCallback: (event, response) {
                        final spots = response?.lineBarSpots;
                        if (spots == null || spots.isEmpty) {
                          tooltip.hide();
                          return;
                        }
                        final sorted = [...spots]
                          ..sort((a, b) => a.barIndex.compareTo(b.barIndex));
                        final lines = <String>[
                          for (final spot in sorted)
                            if (spot.x.toInt() >= 0 &&
                                spot.x.toInt() < trend.labels.length)
                              '${trend.labels[spot.x.toInt()]}\n'
                                  '${spot.barIndex == 0 ? 'Создано' : 'Закрыто'}: '
                                  '${spot.y.toInt()}',
                        ];
                        if (lines.isEmpty) {
                          tooltip.hide();
                          return;
                        }
                        _syncChartTooltip(
                          tooltip: tooltip,
                          event: event,
                          visible: true,
                          message: lines.join('\n'),
                        );
                      },
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touched) => [
                          for (final _ in touched) null,
                        ],
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: createdSpots,
                        isCurved: true,
                        color: _palette[0],
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: trend.labels.length <= 24,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: _palette[0],
                                strokeWidth: 1.5,
                                strokeColor: DdtTheme.pickerSurfaceColor(
                                  context,
                                ),
                              ),
                        ),
                      ),
                      LineChartBarData(
                        spots: closedSpots,
                        isCurved: true,
                        color: _palette[1],
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: trend.labels.length <= 24,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: _palette[1],
                                strokeWidth: 1.5,
                                strokeColor: DdtTheme.pickerSurfaceColor(
                                  context,
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                  duration: _chartDuration,
                  curve: _chartCurve,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ChartLegend(
          items: [
            _LegendItem('Создано', Color(0xFF1976D2)),
            _LegendItem('Закрыто', analyticsPositiveColor),
          ],
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: _chartPlot(
            context,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rodWidth = _flexibleRodWidth(
                  chartWidth: constraints.maxWidth,
                  groupCount: trend.labels.length,
                  rodsPerGroup: 2,
                  minWidth: 10,
                  axisReserve: 32,
                  maxWidth: 28,
                );
                return _ChartTooltipHost(
                  builder: (tooltip) => BarChart(
                    BarChartData(
                      maxY: maxValue * 1.22,
                      alignment: BarChartAlignment.spaceAround,
                      groupsSpace: 10,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: math.max(
                          1,
                          (maxValue / 4).ceilToDouble(),
                        ),
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: gridColor, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: axisTitles,
                      barTouchData: BarTouchData(
                        touchCallback: (event, response) {
                          final spot = response?.spot;
                          final index = spot?.touchedBarGroupIndex;
                          if (spot == null ||
                              index == null ||
                              index < 0 ||
                              index >= trend.labels.length) {
                            tooltip.hide();
                            return;
                          }
                          final kind = spot.touchedRodDataIndex == 0
                              ? 'Создано'
                              : 'Закрыто';
                          _syncChartTooltip(
                            tooltip: tooltip,
                            event: event,
                            visible: true,
                            message:
                                '${trend.labels[index]}\n$kind: ${spot.touchedRodData.toY.toInt()}',
                            chartLocal: spot.offset,
                          );
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (_, _, _, _) => null,
                        ),
                      ),
                      barGroups: [
                        for (
                          var index = 0;
                          index < trend.labels.length;
                          index++
                        )
                          BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: trend.created[index].toDouble(),
                                width: rodWidth,
                                borderRadius: BorderRadius.circular(_rodRadius),
                                color: _palette[0],
                              ),
                              BarChartRodData(
                                toY: trend.closed[index].toDouble(),
                                width: rodWidth,
                                borderRadius: BorderRadius.circular(_rodRadius),
                                color: _palette[1],
                              ),
                            ],
                          ),
                      ],
                    ),
                    duration: _chartDuration,
                    curve: _chartCurve,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class AnalyticsHorizontalBarChart extends StatelessWidget {
  AnalyticsHorizontalBarChart({
    super.key,
    required List<AnalyticsCountPoint> points,
    this.limit = 10,
  }) : _entries = [for (final p in points) (p.label, p.value.toDouble())],
       _format = _formatCount;

  AnalyticsHorizontalBarChart.hours({
    super.key,
    required List<AnalyticsHoursPoint> points,
    this.limit = 1 << 20,
  }) : _entries = [for (final p in points) (p.label, p.hours)],
       _format = formatAnalyticsHoursAxis;

  final List<(String, double)> _entries;
  final String Function(double value) _format;
  final int limit;

  static String _formatCount(double value) => '${value.round()}';

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return const AnalyticsEmptyChart();

    final visible = _entries.take(limit).toList();
    final maxValue = visible.fold<double>(
      1,
      (max, item) => math.max(max, item.$2),
    );

    final valueStyle = DdtTheme.style(
      fontSize: DdtTypography.labelSmallSize,
      fontWeight: FontWeight.w700,
      color: DdtTheme.textPrimary(context),
    );
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.labelSmallSize,
      color: DdtTheme.textSecondary(context),
    );

    final rowPadding = 6.h;
    return LayoutBuilder(
      builder: (context, constraints) {
        final barHeight = _horizontalBarThickness(
          chartHeight: constraints.maxHeight,
          rowCount: visible.length,
          minHeight: 7.h,
          maxHeight: 14.h,
          rowPadding: rowPadding,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < visible.length; index++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: rowPadding / 2),
                  child: Builder(
                    builder: (context) {
                      final (label, value) = visible[index];
                      final fraction = value / maxValue;
                      return _chartHoverTooltip(
                        context: context,
                        message: '$label\n${_format(value)}',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 11,
                              child: Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                                style: labelStyle,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              flex: 13,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  minHeight: barHeight,
                                  backgroundColor: DdtTheme.textMuted(
                                    context,
                                  ).withValues(alpha: 0.12),
                                  color: analyticsSeriesColor(index),
                                ),
                              ),
                            ),
                            SizedBox(width: 6.w),
                            SizedBox(
                              width: 36.w,
                              child: Text(
                                _format(value),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                textAlign: TextAlign.right,
                                style: valueStyle,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AnalyticsStackedStatusChart extends StatelessWidget {
  const AnalyticsStackedStatusChart({super.key, required this.data});

  final AnalyticsStatusByCategory data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const AnalyticsEmptyChart();

    final maxValue = [
      for (var i = 0; i < data.categories.length; i++)
        data.closed[i] + data.inProgress[i] + data.waiting[i],
    ].fold<int>(1, math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ChartLegend(
          items: [
            _LegendItem('Закрыто', analyticsPositiveColor),
            _LegendItem('В работе', Color(0xFF1976D2)),
            _LegendItem('Ожидание действий от клиента', Color(0xFFF9A825)),
          ],
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: _chartPlot(
            context,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rodWidth = _flexibleRodWidth(
                  chartWidth: constraints.maxWidth,
                  groupCount: data.categories.length,
                  rodsPerGroup: 1,
                  minWidth: 18,
                  axisReserve: 28,
                  maxWidth: 56,
                );
                return _ChartTooltipHost(
                  builder: (tooltip) => BarChart(
                    BarChartData(
                      maxY: maxValue * 1.15,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(show: false),
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
                              return Text(
                                '${value.toInt()}',
                                style: DdtTheme.style(
                                  fontSize: DdtTypography.microSize,
                                  color: DdtTheme.textMuted(context),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: _chartBottomAxis(
                          labels: data.categories,
                          labelStyle: DdtTheme.style(
                            fontSize: DdtTypography.microSize,
                            color: DdtTheme.textMuted(context),
                          ),
                          maxLabels: 6,
                          labelWidth: 80,
                          angled: true,
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchCallback: (event, response) {
                          final spot = response?.spot;
                          final index = spot?.touchedBarGroupIndex;
                          if (spot == null ||
                              index == null ||
                              index < 0 ||
                              index >= data.categories.length) {
                            tooltip.hide();
                            return;
                          }
                          _syncChartTooltip(
                            tooltip: tooltip,
                            event: event,
                            visible: true,
                            message:
                                '${data.categories[index]}\n'
                                'Закрыто: ${data.closed[index]}\n'
                                'В работе: ${data.inProgress[index]}\n'
                                'Ожидание: ${data.waiting[index]}',
                            chartLocal: spot.offset,
                          );
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (_, _, _, _) => null,
                        ),
                      ),
                      barGroups: [
                        for (
                          var index = 0;
                          index < data.categories.length;
                          index++
                        )
                          BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY:
                                    (data.closed[index] +
                                            data.inProgress[index] +
                                            data.waiting[index])
                                        .toDouble(),
                                width: rodWidth,
                                borderRadius: BorderRadius.circular(_rodRadius),
                                rodStackItems: [
                                  BarChartRodStackItem(
                                    0,
                                    data.closed[index].toDouble(),
                                    _palette[1],
                                  ),
                                  BarChartRodStackItem(
                                    data.closed[index].toDouble(),
                                    (data.closed[index] +
                                            data.inProgress[index])
                                        .toDouble(),
                                    _palette[0],
                                  ),
                                  BarChartRodStackItem(
                                    (data.closed[index] +
                                            data.inProgress[index])
                                        .toDouble(),
                                    (data.closed[index] +
                                            data.inProgress[index] +
                                            data.waiting[index])
                                        .toDouble(),
                                    _palette[2],
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                    duration: _chartDuration,
                    curve: _chartCurve,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class AnalyticsDailyDetailChart extends StatelessWidget {
  const AnalyticsDailyDetailChart({super.key, required this.buckets});

  final List<AnalyticsDailyBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const AnalyticsEmptyChart();

    final maxCount = buckets.fold<int>(
      1,
      (max, bucket) => math.max(max, math.max(bucket.created, bucket.closed)),
    );
    final maxReaction = buckets.fold<double>(
      1,
      (max, bucket) => math.max(max, bucket.avgReactionHours ?? 0),
    );
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textMuted(context),
    );
    final titles = _chartAxisTitles(
      labels: [for (final bucket in buckets) _shortDayLabel(bucket.day)],
      labelStyle: labelStyle,
      maxLabels: 8,
      angled: buckets.length > 10,
    );
    // Same reserved sizes as [titles] so the line points sit over bar groups.
    final hiddenTitles = FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: titles.leftTitles.sideTitles.reservedSize,
          getTitlesWidget: (_, _) => const SizedBox.shrink(),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: titles.bottomTitles.sideTitles.reservedSize,
          getTitlesWidget: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
    final reactionColor = _palette[3];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartLegend(
          items: [
            _LegendItem('Создано', _palette[0]),
            _LegendItem('Закрыто', _palette[1]),
            _LegendItem('Ср. реакция (ч)', reactionColor),
          ],
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: _chartPlot(
            context,
            child: _ChartTooltipHost(
              builder: (tooltip) => Stack(
                children: [
                  Positioned.fill(
                    child: _bars(context, maxCount, titles, tooltip),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LineChart(
                        LineChartData(
                          minX: -0.5,
                          maxX: buckets.length - 0.5,
                          minY: 0,
                          maxY: maxReaction * 1.18,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: hiddenTitles,
                          lineTouchData: const LineTouchData(enabled: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (var i = 0; i < buckets.length; i++)
                                  if (buckets[i].avgReactionHours != null)
                                    FlSpot(
                                      i.toDouble(),
                                      buckets[i].avgReactionHours!,
                                    ),
                              ],
                              isCurved: true,
                              preventCurveOverShooting: true,
                              color: reactionColor,
                              barWidth: 2,
                              dotData: FlDotData(
                                getDotPainter: (spot, percent, bar, index) =>
                                    FlDotCirclePainter(
                                      radius: 2.5,
                                      color: reactionColor,
                                      strokeWidth: 0,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        duration: _chartDuration,
                        curve: _chartCurve,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bars(
    BuildContext context,
    int maxCount,
    FlTitlesData titles,
    _ChartTooltipController tooltip,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rodWidth = _flexibleRodWidth(
          chartWidth: constraints.maxWidth,
          groupCount: buckets.length,
          rodsPerGroup: 2,
          minWidth: 8,
          axisReserve: 32,
          maxWidth: 22,
        );
        return BarChart(
          BarChartData(
            maxY: maxCount * 1.18,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: false),
            titlesData: titles,
            barTouchData: BarTouchData(
              touchCallback: (event, response) {
                final spot = response?.spot;
                final index = spot?.touchedBarGroupIndex;
                if (spot == null ||
                    index == null ||
                    index < 0 ||
                    index >= buckets.length) {
                  tooltip.hide();
                  return;
                }
                final bucket = buckets[index];
                _syncChartTooltip(
                  tooltip: tooltip,
                  event: event,
                  visible: true,
                  message:
                      '${_shortDayLabel(bucket.day)}\n'
                      'Создано: ${bucket.created}\n'
                      'Закрыто: ${bucket.closed}\n'
                      'Ср. реакция: ${formatAnalyticsReaction(bucket.avgReactionHours)}',
                  chartLocal: spot.offset,
                );
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (_, _, _, _) => null,
              ),
            ),
            barGroups: [
              for (var index = 0; index < buckets.length; index++)
                BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: buckets[index].created.toDouble(),
                      width: rodWidth,
                      borderRadius: BorderRadius.circular(_rodRadiusThin),
                      color: _palette[0],
                    ),
                    BarChartRodData(
                      toY: buckets[index].closed.toDouble(),
                      width: rodWidth,
                      borderRadius: BorderRadius.circular(_rodRadiusThin),
                      color: _palette[1],
                    ),
                  ],
                ),
            ],
          ),
          duration: _chartDuration,
          curve: _chartCurve,
        );
      },
    );
  }
}

class AnalyticsSolvedChart extends StatelessWidget {
  const AnalyticsSolvedChart({super.key, required this.data});

  final AnalyticsSolvedBuckets data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const AnalyticsEmptyChart();

    final maxValue = [...data.solved, ...data.confirmed].fold<int>(1, math.max);
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textMuted(context),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ChartLegend(
          items: [
            _LegendItem('Решено', analyticsPositiveColor),
            _LegendItem('Подтверждение', Color(0xFF1976D2)),
          ],
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: _chartPlot(
            context,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rodWidth = _flexibleRodWidth(
                  chartWidth: constraints.maxWidth,
                  groupCount: data.labels.length,
                  rodsPerGroup: 2,
                  minWidth: 10,
                  axisReserve: 28,
                  maxWidth: 28,
                );
                return _ChartTooltipHost(
                  builder: (tooltip) => BarChart(
                    BarChartData(
                      maxY: maxValue * 1.18,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: false),
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
                              return Text(
                                '${value.toInt()}',
                                style: labelStyle,
                              );
                            },
                          ),
                        ),
                        bottomTitles: _chartBottomAxis(
                          labels: data.labels,
                          labelStyle: labelStyle,
                          maxLabels: 6,
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchCallback: (event, response) {
                          final spot = response?.spot;
                          final index = spot?.touchedBarGroupIndex;
                          if (spot == null ||
                              index == null ||
                              index < 0 ||
                              index >= data.labels.length) {
                            tooltip.hide();
                            return;
                          }
                          final kind = spot.touchedRodDataIndex == 0
                              ? 'Решено'
                              : 'Подтверждение';
                          _syncChartTooltip(
                            tooltip: tooltip,
                            event: event,
                            visible: true,
                            message:
                                '${data.labels[index]}\n$kind: ${spot.touchedRodData.toY.toInt()}',
                            chartLocal: spot.offset,
                          );
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (_, _, _, _) => null,
                        ),
                      ),
                      barGroups: [
                        for (var index = 0; index < data.labels.length; index++)
                          BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: data.solved[index].toDouble(),
                                width: rodWidth,
                                borderRadius: BorderRadius.circular(_rodRadius),
                                color: _palette[1],
                              ),
                              BarChartRodData(
                                toY: data.confirmed[index].toDouble(),
                                width: rodWidth,
                                borderRadius: BorderRadius.circular(_rodRadius),
                                color: _palette[0],
                              ),
                            ],
                          ),
                      ],
                    ),
                    duration: _chartDuration,
                    curve: _chartCurve,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem {
  const _LegendItem(this.label, this.color);
  final String label;
  final Color color;
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items});

  final List<_LegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12.w,
      runSpacing: 6.h,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                item.label,
                style: DdtTheme.style(
                  fontSize: DdtTypography.microSize,
                  color: DdtTheme.textMuted(context),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

String _shortDayLabel(String day) {
  final parts = day.split('-');
  if (parts.length == 3) return '${parts[2]}.${parts[1]}';
  return day;
}

AxisTitles _chartBottomAxis({
  required List<String> labels,
  required TextStyle labelStyle,
  int maxLabels = 6,
  double labelWidth = 64,
  bool angled = false,
}) {
  final step = _chartLabelStep(labels.length, maxLabels: maxLabels);
  final reserved = angled ? 56.0 : 40.0;
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: reserved,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final index = value.toInt();
        if (index < 0 || index >= labels.length) {
          return const SizedBox.shrink();
        }
        if (index % step != 0 && index != labels.length - 1) {
          return const SizedBox.shrink();
        }
        final label = labels[index];
        final text = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: labelStyle,
        );
        return SideTitleWidget(
          meta: meta,
          child: SizedBox(
            width: labelWidth,
            child: angled ? Transform.rotate(angle: -0.55, child: text) : text,
          ),
        );
      },
    ),
  );
}

FlTitlesData _chartAxisTitles({
  required List<String> labels,
  required TextStyle labelStyle,
  int maxLabels = 6,
  bool angled = false,
}) {
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 32,
        getTitlesWidget: (value, meta) {
          if (value == 0 || value == meta.max) {
            return const SizedBox.shrink();
          }
          return Text('${value.toInt()}', style: labelStyle);
        },
      ),
    ),
    bottomTitles: _chartBottomAxis(
      labels: labels,
      labelStyle: labelStyle,
      maxLabels: maxLabels,
      angled: angled || labels.length > 10,
    ),
  );
}

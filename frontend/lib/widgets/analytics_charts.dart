import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/analytics_dashboard.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/analytics_formatters.dart';
import 'ddt_section_refresh.dart';

/// Closed and success series outside charts (KPI stripes, tables).
const analyticsPositiveColor = Color(0xFF3E9B74);

Color analyticsPercentScaleColor(double percent) {
  final t = (percent / 100).clamp(0.0, 1.0);
  const red = Color(0xFFD65C5C);
  const amber = Color(0xFFD4943A);
  const green = Color(0xFF3E9B74);
  if (t < 0.5) return Color.lerp(red, amber, t / 0.5)!;
  return Color.lerp(amber, green, (t - 0.5) / 0.5)!;
}

/// Chart series: same hues, kept quieter and less saturated.
const _chartBlue = Color(0xFF4E78C2);
const _chartGreen = Color(0xFF3A9474);
const _chartAmber = Color(0xFFC48A3C);
const _chartViolet = Color(0xFF7468BE);
const _chartCyan = Color(0xFF3E92BE);
const _chartRose = Color(0xFFC25E6C);
const _chartIndigo = Color(0xFF5C68B4);
const _chartOrange = Color(0xFFC66A44);
const _chartTeal = Color(0xFF3D8C84);
const _chartPlum = Color(0xFF8E5C78);
const _chartOlive = Color(0xFF7C8A48);
const _chartGold = Color(0xFFA89050);
const _chartClay = Color(0xFFA56A56);
const _chartMoss = Color(0xFF5A8A64);
const _chartSteel = Color(0xFF5A7A96);
const _chartWine = Color(0xFF9A5568);
const _chartNeutral = Color(0xFF738196);

List<Color> get _palette => const [
  _chartBlue,
  _chartGreen,
  _chartAmber,
  _chartViolet,
  _chartCyan,
  _chartRose,
  _chartIndigo,
  _chartOrange,
  _chartTeal,
  _chartPlum,
  _chartOlive,
  _chartGold,
  _chartClay,
  _chartMoss,
  _chartSteel,
  _chartWine,
];

/// Pie slices close into a ring, so the last color must also differ from the first.
List<Color> _donutSliceColors(
  List<AnalyticsCountPoint> points, {
  required bool preferStatusColors,
}) {
  final colors = <Color>[];
  for (var index = 0; index < points.length; index++) {
    final last = index == points.length - 1;
    var shift = 0;
    Color color;
    while (true) {
      color = preferStatusColors && shift == 0
          ? analyticsSliceColor(points[index].label, index)
          : _palette[(index + shift) % _palette.length];
      final sameAsPrevious = colors.isNotEmpty && color == colors.last;
      final sameAsFirst = last && colors.length > 1 && color == colors.first;
      if (!sameAsPrevious && !sameAsFirst) break;
      shift++;
      if (shift > _palette.length) break;
    }
    colors.add(color);
  }
  return colors;
}

const _chartDuration = Duration(milliseconds: 200);
const _chartCurve = Curves.easeOutCubic;
const _axisChartHeight = 260.0;

Color _chartTooltipBg(BuildContext context) =>
    DdtTheme.chartTooltipBackground(context);

TextStyle _chartTooltipTextStyle(BuildContext context) =>
    DdtTheme.chartTooltipTextStyle(context);

BorderSide _chartTooltipBorder(BuildContext context) =>
    BorderSide(color: DdtTheme.borderStrong(context));

BoxDecoration _chartTooltipDecoration(BuildContext context) => BoxDecoration(
  color: _chartTooltipBg(context),
  borderRadius: BorderRadius.circular(8),
  border: Border.fromBorderSide(_chartTooltipBorder(context)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);

const _tooltipPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
const _tooltipIn = Duration(milliseconds: 150);
const _tooltipOut = Duration(milliseconds: 75);

const _rodRadiusWide = 6.0;
const _rodRadius = 4.0;
const _rodRadiusThin = 3.0;
const _hoverGrow = 3.0;

/// Tracks the series under the pointer so rods and slices can react.
class _ChartHover extends StatefulWidget {
  const _ChartHover({required this.builder});

  final Widget Function(int? hover, ValueChanged<int?> setHover) builder;

  @override
  State<_ChartHover> createState() => _ChartHoverState();
}

class _ChartHoverState extends State<_ChartHover> {
  int? _hover;

  void _setHover(int? next) {
    if (_hover == next) return;
    setState(() => _hover = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(_hover, _setHover);
}

Color _seriesPaint(Color color, {required bool hot, required bool dimmed}) {
  if (dimmed) return color.withValues(alpha: 0.38);
  if (hot) return Color.lerp(color, Colors.white, 0.16)!;
  return color;
}

Gradient _rodGradient(Color color, {required bool hot, required bool dimmed}) {
  if (dimmed) {
    final faded = color.withValues(alpha: 0.38);
    return LinearGradient(colors: [faded, faded]);
  }
  final top = Color.lerp(color, Colors.white, hot ? 0.16 : 0.08)!;
  return LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [color, top],
  );
}

BarChartRodData _chartRod({
  required double toY,
  required double width,
  required double radius,
  required Color color,
  required bool hot,
  required bool dimmed,
  List<BarChartRodStackItem>? stack,
}) {
  final grown = hot && !dimmed ? width + _hoverGrow : width;
  final paint = _seriesPaint(color, hot: hot, dimmed: dimmed);
  return BarChartRodData(
    toY: toY,
    width: grown,
    borderRadius: BorderRadius.circular(radius),
    color: stack == null ? null : paint,
    gradient: stack == null ? _rodGradient(color, hot: hot, dimmed: dimmed) : null,
    rodStackItems: [
      for (final item in stack ?? const <BarChartRodStackItem>[])
        if (dimmed)
          BarChartRodStackItem(
            item.fromY,
            item.toY,
            item.color?.withValues(alpha: 0.38) ?? paint,
          )
        else
          BarChartRodStackItem(
            item.fromY,
            item.toY,
            null,
            gradient: _rodGradient(item.color ?? color, hot: hot, dimmed: false),
          ),
    ],
  );
}

BarTouchData _responsiveBarTouch({
  required void Function(FlTouchEvent event, BarTouchResponse? response) onTouch,
}) {
  return BarTouchData(
    enabled: true,
    touchExtraThreshold: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
    mouseCursorResolver: (event, response) {
      final index = response?.spot?.touchedBarGroupIndex ?? -1;
      if (index >= 0) return SystemMouseCursors.click;
      return MouseCursor.defer;
    },
    touchCallback: onTouch,
    touchTooltipData: BarTouchTooltipData(
      getTooltipItem: (_, _, _, _) => null,
    ),
  );
}

List<TouchedSpotIndicatorData> _spotIndicators(
  LineChartBarData bar,
  List<int> indexes,
  Color surface,
) {
  final lineColor = (bar.color ?? _chartBlue).withValues(alpha: 0.55);
  return [
    for (final _ in indexes)
      TouchedSpotIndicatorData(
        FlLine(color: lineColor, strokeWidth: 1.5, dashArray: const [4, 4]),
        FlDotData(
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 6.5,
            color: barData.color ?? _chartBlue,
            strokeWidth: 3,
            strokeColor: surface,
          ),
        ),
      ),
  ];
}

LineTouchData _responsiveLineTouch(
  BuildContext context, {
  required void Function(FlTouchEvent event, LineTouchResponse? response) onTouch,
}) {
  final surface = DdtTheme.pickerSurfaceColor(context);
  return LineTouchData(
    handleBuiltInTouches: true,
    touchSpotThreshold: 24,
    mouseCursorResolver: (event, response) {
      final spots = response?.lineBarSpots;
      if (spots != null && spots.isNotEmpty) return SystemMouseCursors.click;
      return MouseCursor.defer;
    },
    touchCallback: onTouch,
    getTouchedSpotIndicator: (bar, indexes) =>
        _spotIndicators(bar, indexes, surface),
    touchTooltipData: LineTouchTooltipData(
      getTooltipItems: (touched) => [for (final _ in touched) null],
    ),
  );
}

BarAreaData _lineArea(Color color) => BarAreaData(
  show: true,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      color.withValues(alpha: 0.18),
      color.withValues(alpha: 0.02),
    ],
  ),
);

FlDotData _lineDots(
  BuildContext context,
  Color color, {
  bool show = true,
}) {
  return FlDotData(
    show: show,
    getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
      radius: 3.6,
      color: color,
      strokeWidth: 2,
      strokeColor: DdtTheme.pickerSurfaceColor(context),
    ),
  );
}

Shadow _lineShadow(Color color) => Shadow(
  color: color.withValues(alpha: 0.16),
  blurRadius: 6,
  offset: const Offset(0, 2),
);

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
  if (text.contains('закры') || text.contains('заверш')) return _chartGreen;
  if (text.contains('ожидан')) return _chartAmber;
  if (text.contains('процесс') || text.contains('работ')) return _chartBlue;
  if (text.contains('назнач')) return _chartViolet;
  return _chartNeutral;
}

Color analyticsSeriesColor(int index) => _palette[index % _palette.length];

Color analyticsSliceColor(String label, int index) {
  final status = analyticsStatusColor(label);
  if (status != _chartNeutral) return status;
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
    this.skeleton = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool expandChild;
  final Widget? headerTrailing;
  final bool skeleton;

  Widget _panel(BuildContext context, {required bool forMeasure}) {
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(16.w),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expand = expandChild && constraints.maxHeight.isFinite;
          final body = forMeasure && expand ? const SizedBox.expand() : child;
          return Column(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
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
                  if (!forMeasure && headerTrailing != null)
                    Align(alignment: Alignment.topRight, child: headerTrailing!),
                ],
              ),
              SizedBox(height: 16.h),
              if (expand) Expanded(child: body) else body,
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = skeleton || DashboardSkeletonScope.of(context);
    return DashboardCardReveal(
      loading: loading,
      skeleton: DashboardGrayCard(
        child: _panel(context, forMeasure: true),
      ),
      child: _panel(context, forMeasure: false),
    );
  }
}

/// Marks a dashboard section whose chart cards should render as gray plates.
class DashboardSkeletonScope extends InheritedWidget {
  const DashboardSkeletonScope({
    super.key,
    required this.loading,
    required super.child,
  });

  final bool loading;

  static bool of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DashboardSkeletonScope>();
    return scope?.loading ?? false;
  }

  @override
  bool updateShouldNotify(DashboardSkeletonScope oldWidget) {
    return loading != oldWidget.loading;
  }
}

/// Solid gray stand-in. With a [child], the plate takes that child's size
/// and hides it, so the placeholder matches the loaded widget.
class DashboardGrayCard extends StatelessWidget {
  const DashboardGrayCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final plate = _shimmerPlate(context);
    if (child == null) return SizedBox.expand(child: plate);
    return Stack(
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainState: true,
          maintainAnimation: true,
          child: child!,
        ),
        Positioned.fill(child: plate),
      ],
    );
  }

  Widget _shimmerPlate(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: DdtTheme.radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: isDark ? const Color(0xFF2A2F3A) : const Color(0xFFE3E6EE),
          ),
          const DdtShimmerSweep(visible: true, intensity: 0.4),
        ],
      ),
    );
  }
}

/// Fades a gray placeholder into the loaded widget without a size jump.
class DashboardCardReveal extends StatelessWidget {
  const DashboardCardReveal({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) {
        return Stack(
          fit: StackFit.passthrough,
          alignment: Alignment.topCenter,
          children: [
            ...previous,
            ?current,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey<bool>(loading),
        child: loading ? skeleton : child,
      ),
      ),
    );
  }
}

/// Pale shimmer block used in place of a chart or value while data loads.
class AnalyticsSkeletonFill extends StatelessWidget {
  const AnalyticsSkeletonFill({super.key, this.height, this.width, this.radius});

  final double? height;
  final double? width;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pale = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(8.r),
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: pale),
            const DdtShimmerSweep(visible: true, intensity: 0.4),
          ],
        ),
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
    this.skeleton = false,
  });

  final String label;
  final String value;
  final Color color;
  final String? hint;
  final bool skeleton;

  Widget _card(BuildContext context) {
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
                    value.isEmpty ? '0' : value,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

  @override
  Widget build(BuildContext context) {
    return DashboardCardReveal(
      loading: skeleton,
      skeleton: DashboardGrayCard(child: _card(context)),
      child: _card(context),
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
    this.onSliceTap,
    this.centerLabel,
    this.centerCaption,
  });

  final List<AnalyticsCountPoint> points;
  final bool preferStatusColors;
  final ValueChanged<String>? onSliceTap;
  final String? centerLabel;
  final String? centerCaption;

  @override
  Widget build(BuildContext context) {
    final total = points.fold<int>(0, (sum, item) => sum + item.value);
    if (total == 0) return const AnalyticsEmptyChart();

    final sliceColors = _donutSliceColors(
      points,
      preferStatusColors: preferStatusColors,
    );
    Color sliceColor(int index, AnalyticsCountPoint point) => sliceColors[index];

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 8.h),
      child: _ChartHover(
      builder: (hover, setHover) => _ChartTooltipHost(
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
                    sectionsSpace: 0.6,
                    centerSpaceRadius: chartSize * 0.32,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      mouseCursorResolver: (event, response) {
                        final index =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
                        if (index >= 0) return SystemMouseCursors.click;
                        return MouseCursor.defer;
                      },
                      touchCallback: (event, response) {
                        final index =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
                        if (event is FlTapUpEvent &&
                            index >= 0 &&
                            index < points.length) {
                          onSliceTap?.call(points[index].label);
                        }
                        if (!event.isInterestedForInteractions ||
                            index < 0 ||
                            index >= points.length) {
                          setHover(null);
                          tooltip.hide();
                          return;
                        }
                        setHover(index);
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
                          color: () {
                            final base = sliceColor(index, points[index]);
                            final hot = hover == index;
                            final dimmed = hover != null && !hot;
                            if (dimmed) return base.withValues(alpha: 0.4);
                            if (hot) return Color.lerp(base, Colors.white, 0.12)!;
                            return base;
                          }(),
                          radius: chartSize * (hover == index ? 0.27 : 0.2),
                          cornerRadius: 4,
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
                      centerLabel ?? '$total',
                      style: DdtTheme.style(
                        fontSize: DdtTypography.sectionTitleSize,
                        fontWeight: FontWeight.w800,
                        color: DdtTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      centerCaption ?? 'всего',
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

          final legendGap = 16.w;
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
            final hot = hover == index;
            final dimmed = hover != null && !hot;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setHover(index),
              onExit: (_) => setHover(null),
              child: GestureDetector(
              onTap: onSliceTap == null
                  ? null
                  : () => onSliceTap!(points[index].label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: hot
                      ? color.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 3.h),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: hot ? 12.w : 10.w,
                        height: hot ? 12.w : 10.w,
                        decoration: BoxDecoration(
                          color: dimmed ? color.withValues(alpha: 0.4) : color,
                          borderRadius: BorderRadius.circular(3.r),
                          boxShadow: hot
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.28),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
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
                          fontWeight: hot ? FontWeight.w700 : FontWeight.w500,
                          color: dimmed
                              ? DdtTheme.textMuted(context)
                              : DdtTheme.textSecondary(context),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${point.value} · $percent%',
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSmallSize,
                        fontWeight: FontWeight.w700,
                        color: dimmed
                            ? DdtTheme.textMuted(context)
                            : DdtTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          }

          final legendPanel = SizedBox(
            width: legendWidth,
            child: LayoutBuilder(
              builder: (context, legendConstraints) {
                final maxHeight = legendConstraints.maxHeight;
                final column = Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < points.length; index++) ...[
                      if (index > 0) SizedBox(height: 4.h),
                      legendRow(index),
                    ],
                  ],
                );
                if (!maxHeight.isFinite || maxHeight <= 0) return column;
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: legendWidth),
                    child: column,
                  ),
                );
              },
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
    ),
    ),
    );
  }
}

class AnalyticsFillGauge extends StatelessWidget {
  const AnalyticsFillGauge({super.key, required this.percent});

  final double? percent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxHeight.isFinite || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        if (side <= 0) return const SizedBox.shrink();
        final value = (percent ?? 0).clamp(0, 100).toDouble();
        final rest = math.max(0.0, 100 - value);
        final color = percent == null
            ? _chartNeutral
            : value >= 90
            ? _chartGreen
            : value >= 70
            ? _chartAmber
            : _chartRose;
        final label = percent == null ? '—' : '${value.round()}%';
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 0,
                    centerSpaceRadius: side * 0.34,
                    sections: [
                      PieChartSectionData(
                        value: value <= 0 ? 0.001 : value,
                        color: color,
                        radius: side * 0.12,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: rest <= 0 ? 0.001 : rest,
                        color: Colors.transparent,
                        radius: side * 0.12,
                        showTitle: false,
                      ),
                    ],
                  ),
                  duration: _chartDuration,
                  curve: _chartCurve,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: side * 0.56,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: DdtTheme.style(
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            color: DdtTheme.textPrimary(context),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'индекс',
                      style: DdtTheme.style(
                        fontSize: DdtTypography.microSize,
                        color: DdtTheme.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
        final chart = _ChartHover(
          builder: (hover, setHover) => _ChartTooltipHost(
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
              barTouchData: _responsiveBarTouch(
                onTouch: (event, response) {
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
                    setHover(null);
                    _syncChartTooltip(
                      tooltip: tooltip,
                      event: event,
                      visible: false,
                      message: '',
                    );
                    return;
                  }
                  setHover(spot.touchedBarGroupIndex);
                  final point = points[spot.touchedBarGroupIndex];
                  _syncChartTooltip(
                    tooltip: tooltip,
                    event: event,
                    visible: true,
                    message: '${point.label}\n${point.value}',
                    chartLocal: spot.offset,
                  );
                },
              ),
              barGroups: [
                for (var index = 0; index < points.length; index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      _chartRod(
                        toY: points[index].value.toDouble(),
                        width: rodWidth,
                        radius: _rodRadiusWide,
                        color:
                            colorForIndex?.call(index) ??
                            analyticsSeriesColor(index),
                        hot: hover == index,
                        dimmed: hover != null && hover != index,
                      ),
                    ],
                  ),
              ],
            ),
            duration: _chartDuration,
            curve: _chartCurve,
          ),
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
          lineTouchData: _responsiveLineTouch(
            context,
            onTouch: (event, response) {
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
              color: _chartBlue,
              barWidth: 3.2,
              isStrokeCapRound: true,
              shadow: _lineShadow(_chartBlue),
              dotData: _lineDots(context, _chartBlue),
              belowBarData: _lineArea(_chartBlue),
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
    this.seriesName,
    this.secondarySeriesName = 'Закрыто',
  });

  final AnalyticsTrendBuckets trend;
  final bool isLine;

  /// When set, only the first series is drawn and labeled with this name.
  final String? seriesName;
  final String secondarySeriesName;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const AnalyticsEmptyChart();

    final single = seriesName != null;
    final primaryLabel = seriesName ?? 'Создано';
    final legend = _ChartLegend(
      items: [
        _LegendItem(primaryLabel, _palette[0]),
        if (!single) _LegendItem(secondarySeriesName, _palette[1]),
      ],
    );
    final maxValue = (single ? trend.created : [...trend.created, ...trend.closed])
        .fold<int>(1, math.max);
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
          legend,
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
                    lineTouchData: _responsiveLineTouch(
                      context,
                      onTouch: (event, response) {
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
                                  '${single || spot.barIndex == 0 ? primaryLabel : secondarySeriesName}: '
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
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: createdSpots,
                        isCurved: true,
                        isStrokeCapRound: true,
                        color: _palette[0],
                        barWidth: 3,
                        shadow: _lineShadow(_palette[0]),
                        belowBarData: _lineArea(_palette[0]),
                        dotData: _lineDots(
                          context,
                          _palette[0],
                          show: trend.labels.length <= 24,
                        ),
                      ),
                      if (!single)
                        LineChartBarData(
                          spots: closedSpots,
                          isCurved: true,
                          isStrokeCapRound: true,
                          color: _palette[1],
                          barWidth: 3,
                          shadow: _lineShadow(_palette[1]),
                          dotData: _lineDots(
                            context,
                            _palette[1],
                            show: trend.labels.length <= 24,
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
        legend,
        SizedBox(height: 8.h),
        Expanded(
          child: _chartPlot(
            context,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rodWidth = _flexibleRodWidth(
                  chartWidth: constraints.maxWidth,
                  groupCount: trend.labels.length,
                  rodsPerGroup: single ? 1 : 2,
                  minWidth: 10,
                  axisReserve: 32,
                  maxWidth: 28,
                );
                return _ChartHover(
                  builder: (hover, setHover) => _ChartTooltipHost(
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
                      barTouchData: _responsiveBarTouch(
                        onTouch: (event, response) {
                          final spot = response?.spot;
                          final index = spot?.touchedBarGroupIndex;
                          if (spot == null ||
                              index == null ||
                              index < 0 ||
                              index >= trend.labels.length) {
                            setHover(null);
                            tooltip.hide();
                            return;
                          }
                          setHover(index);
                          final kind = single || spot.touchedRodDataIndex == 0
                              ? primaryLabel
                              : secondarySeriesName;
                          _syncChartTooltip(
                            tooltip: tooltip,
                            event: event,
                            visible: true,
                            message:
                                '${trend.labels[index]}\n$kind: ${spot.touchedRodData.toY.toInt()}',
                            chartLocal: spot.offset,
                          );
                        },
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
                              _chartRod(
                                toY: trend.created[index].toDouble(),
                                width: rodWidth,
                                radius: _rodRadius,
                                color: _palette[0],
                                hot: hover == index,
                                dimmed: hover != null && hover != index,
                              ),
                              if (!single)
                                _chartRod(
                                  toY: trend.closed[index].toDouble(),
                                  width: rodWidth,
                                  radius: _rodRadius,
                                  color: _palette[1],
                                  hot: hover == index,
                                  dimmed: hover != null && hover != index,
                                ),
                            ],
                          ),
                      ],
                    ),
                    duration: _chartDuration,
                    curve: _chartCurve,
                  ),
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
    this.onSelect,
    this.percentScale = false,
  }) : _entries = [for (final p in points) (p.label, p.value.toDouble())],
       _format = _formatCount;

  AnalyticsHorizontalBarChart.hours({
    super.key,
    required List<AnalyticsHoursPoint> points,
    this.limit = 1 << 20,
    this.onSelect,
    this.percentScale = false,
  }) : _entries = [for (final p in points) (p.label, p.hours)],
       _format = formatAnalyticsHoursAxis;

  final List<(String, double)> _entries;
  final String Function(double value) _format;
  final int limit;
  final ValueChanged<String>? onSelect;
  final bool percentScale;

  static String _formatCount(double value) => '${value.round()}';

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return const AnalyticsEmptyChart();

    final visible = _entries.take(limit).toList();
    final maxValue = percentScale
        ? 100.0
        : visible.fold<double>(1, (max, item) => math.max(max, item.$2));

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
                      final fraction = (value / maxValue).clamp(0.0, 1.0);
                      final row = _ShareBarRow(
                        label: label,
                        valueText: percentScale ? '${value.round()}%' : _format(value),
                        fraction: fraction,
                        color: percentScale
                            ? analyticsPercentScaleColor(value)
                            : analyticsSeriesColor(index),
                        barHeight: barHeight,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      );
                      if (onSelect == null) return row;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => onSelect!(label),
                          child: row,
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
        _ChartLegend(
          items: [
            _LegendItem('Закрыто', _palette[1]),
            _LegendItem('В работе', _palette[0]),
            _LegendItem('Ожидание действий от клиента', _palette[2]),
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
                return _ChartHover(
                  builder: (hover, setHover) => _ChartTooltipHost(
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
                      barTouchData: _responsiveBarTouch(
                        onTouch: (event, response) {
                          final spot = response?.spot;
                          final index = spot?.touchedBarGroupIndex;
                          if (spot == null ||
                              index == null ||
                              index < 0 ||
                              index >= data.categories.length) {
                            setHover(null);
                            tooltip.hide();
                            return;
                          }
                          setHover(index);
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
                              _chartRod(
                                toY:
                                    (data.closed[index] +
                                            data.inProgress[index] +
                                            data.waiting[index])
                                        .toDouble(),
                                width: rodWidth,
                                radius: _rodRadius,
                                color: _palette[0],
                                hot: hover == index,
                                dimmed: hover != null && hover != index,
                                stack: [
                                  BarChartRodStackItem(
                                    0,
                                    data.closed[index].toDouble(),
                                    _palette[1],
                                  ),
                                  BarChartRodStackItem(
                                    data.closed[index].toDouble(),
                                    (data.closed[index] + data.inProgress[index])
                                        .toDouble(),
                                    _palette[0],
                                  ),
                                  BarChartRodStackItem(
                                    (data.closed[index] + data.inProgress[index])
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
                              isStrokeCapRound: true,
                              color: reactionColor,
                              barWidth: 2.8,
                              shadow: _lineShadow(reactionColor),
                              dotData: _lineDots(context, reactionColor),
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
        return _ChartHover(
          builder: (hover, setHover) => BarChart(
          BarChartData(
            maxY: maxCount * 1.18,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: false),
            titlesData: titles,
            barTouchData: _responsiveBarTouch(
              onTouch: (event, response) {
                final spot = response?.spot;
                final index = spot?.touchedBarGroupIndex;
                if (spot == null ||
                    index == null ||
                    index < 0 ||
                    index >= buckets.length) {
                  setHover(null);
                  tooltip.hide();
                  return;
                }
                setHover(index);
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
            ),
            barGroups: [
              for (var index = 0; index < buckets.length; index++)
                BarChartGroupData(
                  x: index,
                  barRods: [
                    _chartRod(
                      toY: buckets[index].created.toDouble(),
                      width: rodWidth,
                      radius: _rodRadiusThin,
                      color: _palette[0],
                      hot: hover == index,
                      dimmed: hover != null && hover != index,
                    ),
                    _chartRod(
                      toY: buckets[index].closed.toDouble(),
                      width: rodWidth,
                      radius: _rodRadiusThin,
                      color: _palette[1],
                      hot: hover == index,
                      dimmed: hover != null && hover != index,
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
        _ChartLegend(
          items: [
            _LegendItem('Решено', _palette[1]),
            _LegendItem('Подтверждение', _palette[0]),
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
                return _ChartHover(
                  builder: (hover, setHover) => _ChartTooltipHost(
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
                      barTouchData: _responsiveBarTouch(
                        onTouch: (event, response) {
                          final spot = response?.spot;
                          final index = spot?.touchedBarGroupIndex;
                          if (spot == null ||
                              index == null ||
                              index < 0 ||
                              index >= data.labels.length) {
                            setHover(null);
                            tooltip.hide();
                            return;
                          }
                          setHover(index);
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
                      ),
                      barGroups: [
                        for (var index = 0; index < data.labels.length; index++)
                          BarChartGroupData(
                            x: index,
                            barRods: [
                              _chartRod(
                                toY: data.solved[index].toDouble(),
                                width: rodWidth,
                                radius: _rodRadius,
                                color: _palette[1],
                                hot: hover == index,
                                dimmed: hover != null && hover != index,
                              ),
                              _chartRod(
                                toY: data.confirmed[index].toDouble(),
                                width: rodWidth,
                                radius: _rodRadius,
                                color: _palette[0],
                                hot: hover == index,
                                dimmed: hover != null && hover != index,
                              ),
                            ],
                          ),
                      ],
                    ),
                    duration: _chartDuration,
                    curve: _chartCurve,
                  ),
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

class AnalyticsResolutionTrendChart extends StatelessWidget {
  const AnalyticsResolutionTrendChart({super.key, required this.buckets});

  final List<AnalyticsDailyBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final points = buckets
        .where((bucket) => bucket.avgResolutionHours != null)
        .toList();
    if (points.isEmpty) return const AnalyticsEmptyChart();

    final maxValue = points.fold<double>(
      1,
      (max, bucket) => math.max(max, bucket.avgResolutionHours ?? 0),
    );
    final gridColor = DdtTheme.textMuted(context).withValues(alpha: 0.18);
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textMuted(context),
    );
    final lineColor = _palette[3];

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
          titlesData: _chartAxisTitles(
            labels: [for (final bucket in points) _shortDayLabel(bucket.day)],
            labelStyle: labelStyle,
            maxLabels: 8,
            angled: points.length > 10,
          ),
          lineTouchData: _responsiveLineTouch(
            context,
            onTouch: (event, response) {
              final spots = response?.lineBarSpots;
              if (spots == null || spots.isEmpty) {
                tooltip.hide();
                return;
              }
              final index = spots.first.x.toInt();
              if (index < 0 || index >= points.length) {
                tooltip.hide();
                return;
              }
              final bucket = points[index];
              _syncChartTooltip(
                tooltip: tooltip,
                event: event,
                visible: true,
                message:
                    '${_shortDayLabel(bucket.day)}\n'
                    'Ср. время решения: ${formatAnalyticsDuration(bucket.avgResolutionHours)}',
              );
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var index = 0; index < points.length; index++)
                  FlSpot(
                    index.toDouble(),
                    points[index].avgResolutionHours ?? 0,
                  ),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              isStrokeCapRound: true,
              color: lineColor,
              barWidth: 3,
              shadow: _lineShadow(lineColor),
              belowBarData: _lineArea(lineColor),
              dotData: _lineDots(context, lineColor),
            ),
          ],
        ),
        duration: _chartDuration,
        curve: _chartCurve,
      ),
    );
  }
}

class AnalyticsExecutorTrendChart extends StatelessWidget {
  const AnalyticsExecutorTrendChart({super.key, required this.trend});

  final AnalyticsExecutorTrend trend;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const AnalyticsEmptyChart();

    final maxValue = trend.series.fold<int>(1, (max, series) {
      final peak = series.values.fold<int>(0, math.max);
      return math.max(max, peak);
    });
    final gridColor = DdtTheme.textMuted(context).withValues(alpha: 0.18);
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      color: DdtTheme.textMuted(context),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartLegend(
          items: [
            for (var index = 0; index < trend.series.length; index++)
              _LegendItem(
                trend.series[index].name,
                analyticsSeriesColor(index),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        Expanded(
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
                titlesData: _chartAxisTitles(
                  labels: trend.labels,
                  labelStyle: labelStyle,
                  maxLabels: 8,
                  angled: trend.labels.length > 8,
                ),
                lineTouchData: _responsiveLineTouch(
                  context,
                  onTouch: (event, response) {
                    final spots = response?.lineBarSpots;
                    if (spots == null || spots.isEmpty) {
                      tooltip.hide();
                      return;
                    }
                    final index = spots.first.x.toInt();
                    if (index < 0 || index >= trend.labels.length) {
                      tooltip.hide();
                      return;
                    }
                    final lines = <String>[
                      trend.labels[index],
                      for (final series in trend.series)
                        if (index < series.values.length)
                          '${series.name}: ${series.values[index]}',
                    ];
                    _syncChartTooltip(
                      tooltip: tooltip,
                      event: event,
                      visible: true,
                      message: lines.join('\n'),
                    );
                  },
                ),
                lineBarsData: [
                  for (var index = 0; index < trend.series.length; index++)
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < trend.series[index].values.length; i++)
                          FlSpot(
                            i.toDouble(),
                            trend.series[index].values[i].toDouble(),
                          ),
                      ],
                      isCurved: true,
                      preventCurveOverShooting: true,
                      isStrokeCapRound: true,
                      color: analyticsSeriesColor(index),
                      barWidth: 2.6,
                      shadow: _lineShadow(analyticsSeriesColor(index)),
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
              duration: _chartDuration,
              curve: _chartCurve,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareBarRow extends StatefulWidget {
  const _ShareBarRow({
    required this.label,
    required this.valueText,
    required this.fraction,
    required this.color,
    required this.barHeight,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String valueText;
  final double fraction;
  final Color color;
  final double barHeight;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  State<_ShareBarRow> createState() => _ShareBarRowState();
}

class _ShareBarRowState extends State<_ShareBarRow> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) {
    final color = _hot
        ? Color.lerp(widget.color, Colors.white, 0.18)!
        : widget.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hot = true),
      onExit: (_) => setState(() => _hot = false),
      child: _chartHoverTooltip(
        context: context,
        message: '${widget.label}\n${widget.valueText}',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: _hot
                ? widget.color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 11,
                child: Text(
                  widget.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: widget.labelStyle.copyWith(
                    fontWeight: _hot ? FontWeight.w700 : FontWeight.w500,
                    color: _hot ? DdtTheme.textPrimary(context) : null,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 13,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: widget.fraction,
                    minHeight: _hot ? widget.barHeight + 3 : widget.barHeight,
                    backgroundColor: widget.color.withValues(
                      alpha: _hot ? 0.18 : 0.1,
                    ),
                    color: color,
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              SizedBox(
                width: 36.w,
                child: Text(
                  widget.valueText,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.right,
                  style: widget.valueStyle.copyWith(
                    color: _hot ? widget.color : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

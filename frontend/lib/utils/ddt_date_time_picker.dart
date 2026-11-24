import 'dart:async';
import 'dart:ui';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../widgets/ddt_app_input.dart';
import '../widgets/ddt_arrow_tooltip.dart';
import '../widgets/ddt_context_menu.dart';
import '../widgets/ddt_desktop_shortcuts.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_side_panel.dart';
import '../theme/ddt_typography.dart';

/// Локаль для Material date/time picker: русский язык, понедельник — первый день недели.
const ddtPickerLocale = Locale('ru', 'RU');

const _kPickerTipWidth = 360.0;
const _kPickerTipHeight = 560.0;

Future<DateTime?> showDdtDateTimePicker({
  required BuildContext context,
  required DateTime initialDateTime,
  DateTime? firstDate,
  DateTime? lastDate,
  BuildContext? anchorContext,
}) {
  final first = firstDate ?? DateTime(2020);
  final last = lastDate ?? DateTime(2100);
  var initial = initialDateTime;
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  final anchor = anchorContext ?? context;
  if (!DdtTheme.isCompactLayout(context)) {
    final rect = ddtContextMenuAnchorRect(
      context: context,
      anchorContext: anchor,
    );
    if (rect != null && _isFieldAnchor(rect)) {
      return _showAnchoredDateTimePicker(
        context: context,
        anchorRect: rect,
        initialDateTime: initial,
        firstDate: first,
        lastDate: last,
      );
    }
  }

  return showDdtSidePanelDialog<DateTime>(
    context,
    builder: (dialogContext) {
      return MediaQuery(
        data: MediaQuery.of(
          dialogContext,
        ).copyWith(alwaysUse24HourFormat: true),
        child: _DdtDateTimePickerDialog(
          initialDateTime: initial,
          firstDate: first,
          lastDate: last,
        ),
      );
    },
  );
}

/// A control, not the page itself. A page-sized box stays a centered dialog.
bool _isFieldAnchor(Rect rect) => rect.height <= 180 && rect.width <= 760;

Future<DateTime?> _showAnchoredDateTimePicker({
  required BuildContext context,
  required Rect anchorRect,
  required DateTime initialDateTime,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final theme = Theme.of(context);
  final completer = Completer<DateTime?>();
  late OverlayEntry entry;
  var closed = false;

  void close(DateTime? value) {
    if (closed) return;
    closed = true;
    entry.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      return Theme(
        data: theme,
        child: _DdtDateTimeTooltip(
          anchorRect: anchorRect,
          initialDateTime: initialDateTime,
          firstDate: firstDate,
          lastDate: lastDate,
          onClosed: close,
        ),
      );
    },
  );
  overlay.insert(entry);
  return completer.future;
}

Future<DateTime?> showDdtDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDdtSidePanelDialog<DateTime>(
    context,
    builder: (dialogContext) {
      return Localizations.override(
        context: dialogContext,
        locale: ddtPickerLocale,
        child: DatePickerDialog(
          initialDate: initialDate,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime(2100),
        ),
      );
    },
  );
}

Future<TimeOfDay?> showDdtTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showDdtSidePanelDialog<TimeOfDay>(
    context,
    builder: (dialogContext) {
      return MediaQuery(
        data: MediaQuery.of(
          dialogContext,
        ).copyWith(alwaysUse24HourFormat: true),
        child: TimePickerDialog(
          initialTime: initialTime,
          initialEntryMode: TimePickerEntryMode.inputOnly,
        ),
      );
    },
  );
}

class _DdtDateTimePickerDialog extends StatefulWidget {
  const _DdtDateTimePickerDialog({
    required this.initialDateTime,
    required this.firstDate,
    required this.lastDate,
    this.anchored = false,
    this.onSelected,
  });

  final DateTime initialDateTime;
  final DateTime firstDate;
  final DateTime lastDate;

  /// Desktop popover. The centered dialog keeps the modal route.
  final bool anchored;
  final ValueChanged<DateTime?>? onSelected;

  @override
  State<_DdtDateTimePickerDialog> createState() =>
      _DdtDateTimePickerDialogState();
}

class _DdtDateTimePickerDialogState extends State<_DdtDateTimePickerDialog> {
  late DateTime _selectedDate;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDateTime.year,
      widget.initialDateTime.month,
      widget.initialDateTime.day,
    );
    _hourController = TextEditingController(
      text: _twoDigits(widget.initialDateTime.hour),
    );
    _minuteController = TextEditingController(
      text: _twoDigits(widget.initialDateTime.minute),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  bool _parseTime({required bool showError}) {
    final hour = int.tryParse(_hourController.text.trim());
    final minute = int.tryParse(_minuteController.text.trim());

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      if (showError) {
        setState(() => _timeError = 'Введите время в формате ЧЧ:ММ');
      }
      return false;
    }

    _hourController.text = _twoDigits(hour);
    _minuteController.text = _twoDigits(minute);
    if (showError) {
      setState(() => _timeError = null);
    }
    return true;
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
  }

  void _stepHour(int delta) => _stepField(_hourController, delta, 24);

  void _stepMinute(int delta) => _stepField(_minuteController, delta, 60);

  void _stepField(TextEditingController controller, int delta, int modulo) {
    final parsed = int.tryParse(controller.text.trim());
    final base = parsed != null && parsed >= 0 && parsed < modulo ? parsed : 0;
    final next = (base + delta) % modulo;
    setState(() {
      controller.text = _twoDigits(next < 0 ? next + modulo : next);
      _timeError = null;
    });
  }

  void _close(DateTime? value) {
    final selected = widget.onSelected;
    if (selected != null) {
      selected(value);
      return;
    }
    Navigator.of(context).pop(value);
  }

  void _confirm() {
    if (!_parseTime(showError: true)) return;

    final hour = int.parse(_hourController.text);
    final minute = int.parse(_minuteController.text);

    _close(
      DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
        minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.anchored) {
      return _AnchoredDateTimePicker(host: this);
    }
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final textPrimary = DdtTheme.textPrimary(context);
    final textMuted = DdtTheme.textMuted(context);
    final surfaceColor = DdtTheme.pickerSurfaceColor(
      context,
    ).withValues(alpha: isDark ? 0.80 : 0.86);

    final card = ClipRRect(
      borderRadius: DdtTheme.radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          constraints: BoxConstraints(maxWidth: 360.w),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: DdtTheme.radius,
            border: Border.all(color: DdtTheme.glassBorderColor(brightness)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Выберите дату и время',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.panelTitleSize,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(
                      context,
                    ).colorScheme.copyWith(surface: Colors.transparent),
                  ),
                  child: CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    currentDate: DateTime.now(),
                    onDateChanged: (date) =>
                        setState(() => _selectedDate = date),
                  ),
                ),
                Divider(color: DdtTheme.sidePanelDivider(context)),
                SizedBox(height: 8.h),
                Text(
                  'Время',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSize,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        controller: _hourController,
                        fillColor: DdtTheme.pickerInputFillColor(context),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text(
                        ':',
                        style: DdtTheme.style(
                          fontSize: DdtTypography.pageTitleSize,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _TimeField(
                        controller: _minuteController,
                        fillColor: DdtTheme.pickerInputFillColor(context),
                      ),
                    ),
                  ],
                ),
                if (_timeError != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    _timeError!,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.labelSmallSize,
                      color: AppColors.error,
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _close(null),
                      child: const Text('Отмена'),
                    ),
                    TextButton(onPressed: _confirm, child: const Text('ОК')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: card,
    );
  }
}

class _AnchoredDateTimePicker extends StatelessWidget {
  const _AnchoredDateTimePicker({required this.host});

  final _DdtDateTimePickerDialogState host;

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.textPrimary(context);
    final textMuted = DdtTheme.textMuted(context);
    final calendar = Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(surface: Colors.transparent),
      ),
      child: CalendarDatePicker(
        initialDate: host._selectedDate,
        firstDate: host.widget.firstDate,
        lastDate: host.widget.lastDate,
        currentDate: DateTime.now(),
        onDateChanged: host._selectDate,
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'Выберите дату и время',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.panelTitleSize,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: DdtTheme.sidePanelTextPrimary(context),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Закрыть',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => host._close(null),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: DdtIcon(
                        DdtIcons.close,
                        size: 15,
                        color: DdtTheme.sidePanelTextSecondary(context),
                        semanticLabel: 'Закрыть',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: calendar,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Время',
              textAlign: TextAlign.center,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSize,
                fontWeight: FontWeight.w600,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeSpinner(
                  controller: host._hourController,
                  fillColor: DdtTheme.pickerInputFillColor(context),
                  upLabel: 'Час позже',
                  downLabel: 'Час раньше',
                  onStep: host._stepHour,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    ':',
                    style: DdtTheme.style(
                      fontSize: DdtTypography.pageTitleSize,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                _TimeSpinner(
                  controller: host._minuteController,
                  fillColor: DdtTheme.pickerInputFillColor(context),
                  upLabel: 'Минута позже',
                  downLabel: 'Минута раньше',
                  onStep: host._stepMinute,
                ),
              ],
            ),
            if (host._timeError != null) ...[
              const SizedBox(height: 6),
              Text(
                host._timeError!,
                textAlign: TextAlign.center,
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSmallSize,
                  color: AppColors.error,
                ),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => host._close(null),
                  child: const Text('Отмена'),
                ),
                TextButton(onPressed: host._confirm, child: const Text('ОК')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSpinner extends StatelessWidget {
  const _TimeSpinner({
    required this.controller,
    required this.fillColor,
    required this.upLabel,
    required this.downLabel,
    required this.onStep,
  });

  final TextEditingController controller;
  final Color fillColor;
  final String upLabel;
  final String downLabel;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: DdtIcons.chevronUp,
          label: upLabel,
          onTap: () => onStep(1),
        ),
        SizedBox(
          width: 72,
          child: _TimeField(controller: controller, fillColor: fillColor),
        ),
        _StepButton(
          icon: DdtIcons.chevronDown,
          label: downLabel,
          onTap: () => onStep(-1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: DdtIcon(
            icon,
            size: 14,
            color: DdtTheme.sidePanelTextSecondary(context),
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}

class _DdtDateTimeTooltip extends StatefulWidget {
  const _DdtDateTimeTooltip({
    required this.anchorRect,
    required this.initialDateTime,
    required this.firstDate,
    required this.lastDate,
    required this.onClosed,
  });

  final Rect anchorRect;
  final DateTime initialDateTime;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?> onClosed;

  @override
  State<_DdtDateTimeTooltip> createState() => _DdtDateTimeTooltipState();
}

class _DdtDateTimeTooltipState extends State<_DdtDateTimeTooltip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  var _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss([DateTime? value]) async {
    if (_closing) return;
    _closing = true;
    await _controller.reverse();
    if (!mounted) return;
    widget.onClosed(value);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final placement = ddtPlaceArrowTooltip(
      screen: media.size,
      padding: media.padding,
      anchor: widget.anchorRect,
      maxWidth: _kPickerTipWidth,
      maxHeight: _kPickerTipHeight,
    );
    final rect = ddtFitTipInside(placement.outer, null);

    return DdtPageShortcuts(
      onEscape: () => unawaited(_dismiss()),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            unawaited(_dismiss());
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final t = _animation.value;
            final offset = ddtTipSlideOffset(placement.side, (1 - t) * 8);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => unawaited(_dismiss()),
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: rect.left + offset.dx,
                  top: rect.top + offset.dy,
                  width: rect.width,
                  height: rect.height,
                  child: Opacity(
                    opacity: t,
                    child: Transform.scale(
                      alignment: ddtTipScaleAlignment(placement.side),
                      scale: 0.94 + 0.06 * t,
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          },
          child: DdtArrowTip(
            side: placement.side,
            arrowCenter: placement.arrowCenter,
            showArrow: placement.showArrow,
            child: MediaQuery(
              data: media.copyWith(alwaysUse24HourFormat: true),
              child: _DdtDateTimePickerDialog(
                initialDateTime: widget.initialDateTime,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                anchored: true,
                onSelected: (value) => unawaited(_dismiss(value)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.controller, required this.fillColor});

  final TextEditingController controller;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return DdtAppInput(
      controller: controller,
      hint: '00',
      variant: DdtInputVariant.compact,
      type: InputType.number,
      textAlign: TextAlign.center,
      fillColor: fillColor,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
    );
  }
}

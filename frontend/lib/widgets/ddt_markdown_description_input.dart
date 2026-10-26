import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:markdown_live/markdown_live.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_icon.dart';
import 'ddt_markdown_live_controller.dart';

/// WYSIWYG Markdown description field (raw Markdown in [MarkdownLiveController.text]).
class DdtMarkdownDescriptionInput extends StatefulWidget {
  const DdtMarkdownDescriptionInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.label = 'Описание',
    this.hint = 'Markdown: заголовки, списки, ссылки…',
    this.minLines = 4,
    this.plain = false,
  });

  final DdtMarkdownLiveController controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final int minLines;

  /// Текст без рамки и заливки: разметка остаётся, поле выглядит как описание.
  final bool plain;

  static MarkdownLiveTheme themeFor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? MarkdownLiveTheme.dark() : MarkdownLiveTheme.light();
    final textPrimary = DdtTheme.sidePanelTextPrimary(context);
    final textMuted = DdtTheme.sidePanelTextMuted(context);
    final primary = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    final codeBg = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    // Package defaults are 32px. A TextField line is sized from the body
    // style, so that heading paints outside the field — worst on the first line.
    TextStyle heading(double size) => DdtTheme.style(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.35,
      color: textPrimary,
    );

    return base.copyWith(
      baseStyle: DdtTheme.style(
        fontSize: DdtTypography.bodySize,
        height: 1.45,
        color: textPrimary,
      ),
      boldStyle: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
      italicStyle: TextStyle(fontStyle: FontStyle.italic, color: textPrimary),
      boldItalicStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: textPrimary,
      ),
      strikethroughStyle: TextStyle(
        decoration: TextDecoration.lineThrough,
        color: textMuted,
      ),
      inlineCodeStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: DdtTypography.labelSize,
        backgroundColor: codeBg,
        color: textPrimary,
      ),
      heading1Style: heading(DdtTypography.pageTitleSize),
      heading2Style: heading(DdtTypography.panelTitleSize),
      heading3Style: heading(DdtTypography.sectionTitleSize),
      heading4Style: heading(DdtTypography.bodyLargeSize),
      heading5Style: heading(DdtTypography.bodySize),
      heading6Style: heading(DdtTypography.labelSize),
      linkTextStyle: TextStyle(
        color: primary,
        decoration: TextDecoration.underline,
        decorationColor: primary,
      ),
      syntaxRevealStyle: TextStyle(
        color: textMuted,
        fontSize: DdtTypography.labelSize,
        fontWeight: FontWeight.w300,
      ),
      cursorColor: primary,
      selectionColor: primary.withValues(alpha: 0.22),
    );
  }

  @override
  State<DdtMarkdownDescriptionInput> createState() =>
      _DdtMarkdownDescriptionInputState();
}

class _DdtMarkdownDescriptionInputState
    extends State<DdtMarkdownDescriptionInput> {
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;
  bool _hovering = false;
  bool _focused = false;
  Brightness? _syncedBrightness;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _focused = _focusNode.hasFocus;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_syncedBrightness == brightness) return;
    _syncedBrightness = brightness;
    widget.controller.theme = DdtMarkdownDescriptionInput.themeFor(context);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = _focused
        ? DdtTheme.inputFillColorFocused(context)
        : (_hovering
              ? DdtTheme.inputFillColorHover(context)
              : DdtTheme.inputFillColor(context));
    final border = _focused
        ? DdtTheme.primaryColor
        : (_hovering
              ? DdtTheme.borderStrong(context)
              : DdtTheme.borderSubtle(context));

    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    final toolbar = MarkdownLiveToolbar(
      controller: widget.controller,
      backgroundColor: Colors.transparent,
      activeColor: accent,
      inactiveColor: DdtTheme.sidePanelTextSecondary(context),
      iconSize: widget.plain ? 14.sp : 16.sp,
      height: widget.plain ? 32.h : 34.h,
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      spacing: widget.plain ? 1 : 0,
      borderRadius: BorderRadius.zero,
      showDividers: true,
    );
    final toolbarBody = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        toolbar,
        _ListFormatButton(
          controller: widget.controller,
          icon: DdtIcons.listUl,
          tooltip: 'Маркированный список',
          activeOf: (controller) => controller.bulletListActive,
          onPressed: widget.controller.toggleBulletList,
          height: widget.plain ? 32.h : 34.h,
          iconSize: widget.plain ? 13.sp : 14.sp,
          activeColor: accent,
        ),
        _ListFormatButton(
          controller: widget.controller,
          icon: DdtIcons.listOl,
          tooltip: 'Нумерованный список',
          activeOf: (controller) => controller.numberedListActive,
          onPressed: widget.controller.toggleNumberedList,
          height: widget.plain ? 32.h : 34.h,
          iconSize: widget.plain ? 13.sp : 14.sp,
          activeColor: accent,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              fontWeight: FontWeight.w600,
              color: DdtTheme.sidePanelTextPrimary(context),
            ),
          ),
          SizedBox(height: 7.h),
        ],
        if (widget.plain) SizedBox(height: 16.h),
        Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.plain
                  ? (isDark
                        ? DdtTheme.darkWidget
                        : const Color(0xFFF3F6FB))
                  : DdtTheme.inputFillColor(context),
              borderRadius: widget.plain
                  ? DdtTheme.radius
                  : DdtTheme.inputControlBorderRadius,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : DdtTheme.borderSubtle(context),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: toolbarBody,
            ),
          ),
        ),
        SizedBox(height: widget.plain ? 10.h : 6.h),
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedContainer(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            clipBehavior: Clip.antiAlias,
            decoration: widget.plain
                ? const BoxDecoration()
                : BoxDecoration(
                    color: fill,
                    borderRadius: DdtTheme.inputControlBorderRadius,
                    border: Border.all(color: border),
                    boxShadow: _focused
                        ? DdtTheme.inputFocusShadow(context)
                        : null,
                  ),
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: InputDecorationTheme(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  isCollapsed: widget.plain,
                  contentPadding: widget.plain ? EdgeInsets.zero : null,
                  constraints: widget.plain
                      ? const BoxConstraints(minWidth: 0, minHeight: 0)
                      : null,
                ),
              ),
              child: MarkdownLiveEditor(
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: widget.minLines,
                maxLines: null,
                padding: EdgeInsets.zero,
                strutStyle: StrutStyle(
                  fontSize: DdtTypography.bodySize,
                  height: 1.45,
                  leading: 0.25,
                  forceStrutHeight: false,
                ),
                decoration: InputDecoration(
                  isCollapsed: widget.plain,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    height: 1.55,
                    color: DdtTheme.inputHintStyle(context).color,
                  ),
                  contentPadding: widget.plain
                      ? EdgeInsets.only(top: 4.h, bottom: 2.h)
                      : EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 10.h,
                        ),
                  constraints: widget.plain
                      ? const BoxConstraints(minWidth: 0, minHeight: 0)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListFormatButton extends StatelessWidget {
  const _ListFormatButton({
    required this.controller,
    required this.icon,
    required this.tooltip,
    required this.activeOf,
    required this.onPressed,
    required this.height,
    required this.iconSize,
    required this.activeColor,
  });

  final DdtMarkdownLiveController controller;
  final FaIconData icon;
  final String tooltip;
  final bool Function(DdtMarkdownLiveController controller) activeOf;
  final VoidCallback onPressed;
  final double height;
  final double iconSize;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final inactive = DdtTheme.sidePanelTextSecondary(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = activeOf(controller);
        final color = active ? activeColor : inactive;
        return Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Material(
              color: active
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onPressed,
                child: SizedBox(
                  width: height - 8,
                  height: height - 8,
                  child: Center(
                    child: DdtIcon(icon, size: iconSize, color: color),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

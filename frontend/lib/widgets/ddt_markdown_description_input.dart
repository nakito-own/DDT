import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:markdown_live/markdown_live.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_markdown_live_controller.dart';

/// WYSIWYG Markdown description field (raw Markdown in [MarkdownLiveController.text]).
class DdtMarkdownDescriptionInput extends StatefulWidget {
  const DdtMarkdownDescriptionInput({
    super.key,
    required this.controller,
    this.label = 'Описание',
    this.hint = 'Markdown: заголовки, списки, ссылки…',
    this.minLines = 4,
  });

  final DdtMarkdownLiveController controller;
  final String? label;
  final String? hint;
  final int minLines;

  static MarkdownLiveTheme themeFor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? MarkdownLiveTheme.dark() : MarkdownLiveTheme.light();
    final textPrimary = DdtTheme.sidePanelTextPrimary(context);
    final textMuted = DdtTheme.sidePanelTextMuted(context);
    final primary = AppColors.primary;
    final codeBg = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    TextStyle heading(TextStyle? style) =>
        (style ?? const TextStyle()).copyWith(color: textPrimary);

    return base.copyWith(
      baseStyle: DdtTheme.style(
        fontSize: DdtTypography.bodySize,
        height: 1.55,
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
      heading1Style: heading(base.heading1Style),
      heading2Style: heading(base.heading2Style),
      heading3Style: heading(base.heading3Style),
      heading4Style: heading(base.heading4Style),
      heading5Style: heading(base.heading5Style),
      heading6Style: heading(base.heading6Style),
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
  bool _hovering = false;
  bool _focused = false;
  Brightness? _syncedBrightness;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
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
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final fill = DdtTheme.inputFillColor(context);
    final border = _focused
        ? AppColors.primary
        : DdtTheme.inputBorderColor(context).withValues(
            alpha: _hovering ? 0.55 : 0.5,
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
        MarkdownLiveToolbar(
          controller: widget.controller,
          backgroundColor: fill,
          activeColor: AppColors.primary,
          inactiveColor: DdtTheme.sidePanelTextSecondary(context),
          iconSize: 17.sp,
          height: 36.h,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          spacing: 0,
          borderRadius: DdtTheme.inputControlBorderRadius,
          showDividers: true,
        ),
        SizedBox(height: 8.h),
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedContainer(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: DdtTheme.inputControlBorderRadius,
              border: Border.all(color: border),
              boxShadow: _focused ? DdtTheme.inputFocusShadow(context) : null,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                ),
              ),
              child: MarkdownLiveEditor(
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: widget.minLines,
                maxLines: null,
                padding: EdgeInsets.zero,
                decoration: InputDecoration(
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 10.h,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

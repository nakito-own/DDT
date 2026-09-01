import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';

enum DdtInputVariant { standard, compact, pill }

/// Единый стилизованный TextField с анимацией фокуса и hover.
class DdtAppInput extends StatefulWidget {
  const DdtAppInput({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.prefixIcon,
    this.suffixIcon,
    this.type = InputType.text,
    this.variant = DdtInputVariant.standard,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.controller,
    this.focusNode,
    this.validator,
    this.inputFormatters,
    this.textInputAction,
    this.autofocus = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLength,
    this.maxLines,
    this.minLines,
    this.width,
    this.height,
    this.contentPadding,
    this.fillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.textColor,
    this.style,
    this.labelStyle,
    this.hintStyle,
    this.suffixIconOnPressed,
    this.suffix,
    this.prefix,
    this.errorText,
    this.borderRadius,
    this.borderWidth = 1.0,
    this.textAlign = TextAlign.start,
    this.obscureText,
  });

  final String? label;
  final String? hint;
  final String? initialValue;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final InputType type;
  final DdtInputVariant variant;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool readOnly;
  final bool enabled;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? textColor;
  final TextStyle? style;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final VoidCallback? suffixIconOnPressed;
  final Widget? suffix;
  final Widget? prefix;
  final String? errorText;
  final BorderRadius? borderRadius;
  final double borderWidth;
  final TextAlign textAlign;
  final bool? obscureText;

  @override
  State<DdtAppInput> createState() => _DdtAppInputState();
}

class _DdtAppInputState extends State<DdtAppInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _hovering = false;
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _obscureText = widget.obscureText ?? widget.type == InputType.password;
  }

  @override
  void didUpdateWidget(covariant DdtAppInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscureText != null && widget.obscureText != _obscureText) {
      _obscureText = widget.obscureText!;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() => setState(() {});

  bool get _isFocused => _focusNode.hasFocus;
  BorderRadius get _radius {
    if (widget.borderRadius != null) return widget.borderRadius!;
    return switch (widget.variant) {
      DdtInputVariant.standard => DdtTheme.inputControlBorderRadius,
      DdtInputVariant.compact => DdtTheme.inputControlBorderRadius,
      DdtInputVariant.pill => BorderRadius.circular(999),
    };
  }

  double get _minControlHeight {
    return switch (widget.variant) {
      DdtInputVariant.standard => DdtTheme.inputControlHeight,
      DdtInputVariant.compact => DdtTheme.compactInputControlHeight,
      DdtInputVariant.pill => DdtTheme.inputControlHeight,
    };
  }

  EdgeInsetsGeometry get _contentPadding {
    if (widget.contentPadding != null) return widget.contentPadding!;
    final multiline =
        widget.type == InputType.multiline || (_resolvedMaxLines ?? 1) > 1;
    return switch (widget.variant) {
      DdtInputVariant.standard => EdgeInsets.symmetric(
        horizontal: DdtTheme.inputHorizontalPadding,
        vertical: multiline ? 12 : 0,
      ),
      DdtInputVariant.compact => EdgeInsets.symmetric(
        horizontal: 10,
        vertical: multiline ? 7 : 0,
      ),
      DdtInputVariant.pill => EdgeInsets.symmetric(
        horizontal: 14,
        vertical: multiline ? 9 : 0,
      ),
    };
  }

  Color _fillColor(BuildContext context) {
    if (widget.fillColor != null) return widget.fillColor!;
    if (!widget.enabled) {
      return DdtTheme.inputFillColor(context).withValues(alpha: 0.55);
    }
    if (_isFocused) return DdtTheme.inputFillColorFocused(context);
    if (_hovering) return DdtTheme.inputFillColorHover(context);
    return DdtTheme.inputFillColor(context);
  }

  Color _borderColor(BuildContext context, {required bool hasError}) {
    if (hasError) return AppColors.error;
    if (!widget.enabled) {
      return DdtTheme.inputBorderColor(context).withValues(alpha: 0.35);
    }
    if (_isFocused) {
      return widget.focusedBorderColor ?? AppColors.primary;
    }
    if (_hovering) {
      return (widget.borderColor ?? DdtTheme.inputBorderColor(context))
          .withValues(alpha: 0.58);
    }
    return (widget.borderColor ?? DdtTheme.inputBorderColor(context))
        .withValues(alpha: 0.34);
  }

  List<BoxShadow>? _boxShadow(BuildContext context, {required bool hasError}) {
    if (!_isFocused || hasError || !widget.enabled) return null;
    return DdtTheme.inputFocusShadow(context);
  }

  BoxConstraints get _iconConstraints => BoxConstraints.tightFor(
    width: _minControlHeight,
    height: _minControlHeight,
  );

  Widget? _buildPrefixIcon(BuildContext context) {
    if (widget.prefix != null) return widget.prefix;
    if (widget.prefixIcon == null) return null;

    final iconColor =
        DdtTheme.inputHintStyle(context).color ?? DdtTheme.textMuted(context);

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Icon(widget.prefixIcon, size: 18, color: iconColor),
    );
  }

  Widget? _buildSuffixIcon(BuildContext context) {
    if (widget.suffix != null) return widget.suffix;

    if (widget.type == InputType.password) {
      return IconButton(
        icon: Icon(
          _obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 18,
          color:
              DdtTheme.inputHintStyle(context).color ??
              DdtTheme.textMuted(context),
        ),
        onPressed: widget.enabled
            ? () => setState(() => _obscureText = !_obscureText)
            : null,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: _iconConstraints,
        splashRadius: 16,
      );
    }

    if (widget.suffixIcon == null) return null;

    return IconButton(
      icon: Icon(
        widget.suffixIcon,
        size: 18,
        color:
            DdtTheme.inputHintStyle(context).color ??
            DdtTheme.textMuted(context),
      ),
      onPressed: widget.enabled ? widget.suffixIconOnPressed : null,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: _iconConstraints,
      splashRadius: 16,
    );
  }

  TextInputType _keyboardType() {
    if (widget.type == InputType.multiline || (_resolvedMaxLines ?? 1) > 1) {
      return TextInputType.multiline;
    }

    return switch (widget.type) {
      InputType.text ||
      InputType.search ||
      InputType.custom => TextInputType.text,
      InputType.password => TextInputType.visiblePassword,
      InputType.email => TextInputType.emailAddress,
      InputType.number => TextInputType.number,
      InputType.phone => TextInputType.phone,
      InputType.multiline => TextInputType.multiline,
    };
  }

  List<TextInputFormatter>? _formatters() {
    if (widget.inputFormatters != null) return widget.inputFormatters;
    return switch (widget.type) {
      InputType.number ||
      InputType.phone => [FilteringTextInputFormatter.digitsOnly],
      _ => null,
    };
  }

  int? get _resolvedMaxLines {
    if (widget.type == InputType.multiline) return widget.maxLines ?? 5;
    if (widget.variant == DdtInputVariant.pill) return widget.maxLines ?? 4;
    return 1;
  }

  int? get _resolvedMinLines {
    if (widget.type == InputType.multiline) return widget.minLines ?? 3;
    if (widget.variant == DdtInputVariant.pill) return widget.minLines ?? 1;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final field = FormField<String>(
      initialValue: _controller.text,
      enabled: widget.enabled,
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(_controller.text),
      builder: (fieldState) {
        final validationError = widget.errorText?.isNotEmpty == true
            ? widget.errorText
            : fieldState.errorText;
        final hasError = validationError?.isNotEmpty == true;
        final singleLine = _resolvedMaxLines == 1;
        final prefix = _buildPrefixIcon(context);
        final suffix = _buildSuffixIcon(context);
        final singleLinePadding =
            widget.contentPadding ??
            EdgeInsets.only(
              left: prefix == null ? DdtTheme.inputHorizontalPadding : 2,
              right: suffix == null ? DdtTheme.inputHorizontalPadding : 2,
            );
        final textField = TextField(
          controller: _controller,
          focusNode: _focusNode,
          obscureText: _obscureText,
          keyboardType: _keyboardType(),
          textInputAction: widget.textInputAction,
          textAlign: widget.textAlign,
          textAlignVertical: TextAlignVertical.center,
          maxLength: widget.maxLength,
          maxLines: _resolvedMaxLines,
          minLines: _resolvedMinLines,
          autofocus: widget.autofocus,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          onChanged: (value) {
            fieldState.didChange(value);
            widget.onChanged?.call(value);
          },
          onSubmitted: widget.onSubmitted,
          onTap: widget.onTap,
          inputFormatters: _formatters(),
          style:
              widget.style ??
              DdtTheme.style(
                fontSize: DdtTypography.bodySize,
                height: 1.3,
                color: widget.textColor ?? DdtTheme.textPrimary(context),
              ),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: false,
            isDense: true,
            isCollapsed: singleLine,
            constraints: const BoxConstraints(),
            contentPadding: singleLine ? EdgeInsets.zero : _contentPadding,
            prefixIcon: singleLine ? null : prefix,
            suffixIcon: singleLine ? null : suffix,
            prefixIconConstraints: _iconConstraints,
            suffixIconConstraints: widget.suffix == null
                ? _iconConstraints
                : const BoxConstraints(),
            hintStyle: widget.hintStyle ?? DdtTheme.inputHintStyle(context),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            counterText: '',
          ),
        );
        final inputContent = singleLine
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (prefix != null)
                    SizedBox(
                      width: _minControlHeight,
                      height: _minControlHeight,
                      child: Center(child: prefix),
                    ),
                  Expanded(
                    child: Padding(
                      padding: singleLinePadding,
                      child: Transform.translate(
                        offset: const Offset(0, -2),
                        child: textField,
                      ),
                    ),
                  ),
                  ?suffix,
                ],
              )
            : textField;

        final control = MouseRegion(
          onEnter: widget.enabled
              ? (_) => setState(() => _hovering = true)
              : null,
          onExit: (_) => setState(() => _hovering = false),
          cursor: widget.enabled
              ? SystemMouseCursors.text
              : SystemMouseCursors.basic,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: widget.enabled
                ? (_) {
                    if (!_focusNode.hasFocus) {
                      _focusNode.requestFocus();
                    }
                  }
                : null,
            child: AnimatedContainer(
              duration: DdtTheme.selectionAnimationDuration,
              curve: DdtTheme.selectionAnimationCurve,
              width: widget.width,
              height: widget.height ?? (singleLine ? _minControlHeight : null),
              constraints: singleLine
                  ? null
                  : BoxConstraints(minHeight: _minControlHeight),
              decoration: BoxDecoration(
                color: _fillColor(context),
                borderRadius: _radius,
                border: Border.all(
                  color: _borderColor(context, hasError: hasError),
                  width: widget.borderWidth,
                ),
                boxShadow: _boxShadow(context, hasError: hasError),
              ),
              child: inputContent,
            ),
          ),
        );

        if (!hasError) return control;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            control,
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 5),
              child: Text(
                validationError!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DdtTheme.style(
                  fontSize: DdtTypography.captionSize,
                  height: 1.25,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (widget.label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label!,
          style:
              widget.labelStyle ??
              DdtTheme.style(
                fontSize: DdtTypography.labelSize,
                fontWeight: FontWeight.w600,
                color: _isFocused
                    ? AppColors.primary
                    : DdtTheme.textSecondary(context),
              ),
        ),
        const SizedBox(height: 7),
        field,
      ],
    );
  }
}

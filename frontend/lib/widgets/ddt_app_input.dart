import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ddt_theme.dart';

/// [AppInput] с цветами и типографикой из [DdtTheme].
class DdtAppInput extends StatelessWidget {
  const DdtAppInput({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.prefixIcon,
    this.suffixIcon,
    this.type = InputType.text,
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
    this.focusedBorderWidth = 2.0,
    this.textAlign = TextAlign.start,
  });

  final String? label;
  final String? hint;
  final String? initialValue;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final InputType type;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
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
  final double focusedBorderWidth;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          floatingLabelStyle: DdtTheme.inputFloatingLabelStyle(context),
        ),
      ),
      child: AppInput(
        label: label,
        hint: hint,
        initialValue: initialValue,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        type: type,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        controller: controller,
        focusNode: focusNode,
        validator: validator,
        inputFormatters: inputFormatters,
        textInputAction: textInputAction,
        autofocus: autofocus,
        readOnly: readOnly,
        enabled: enabled,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: minLines,
        width: width,
        height: height,
        contentPadding: contentPadding,
        fillColor: fillColor ?? DdtTheme.inputFillColor(context),
        borderColor: borderColor ?? DdtTheme.inputBorderColor(context),
        focusedBorderColor: focusedBorderColor ?? AppColors.primary,
        textColor: textColor ?? DdtTheme.textPrimary(context),
        style: style,
        labelStyle: labelStyle ?? DdtTheme.inputLabelStyle(context),
        hintStyle: hintStyle ?? DdtTheme.inputHintStyle(context),
        suffixIconOnPressed: suffixIconOnPressed,
        suffix: suffix,
        prefix: prefix,
        errorText: errorText,
        borderRadius: borderRadius ?? DdtTheme.radius,
        borderWidth: borderWidth,
        focusedBorderWidth: focusedBorderWidth,
        textAlign: textAlign,
      ),
    );
  }
}

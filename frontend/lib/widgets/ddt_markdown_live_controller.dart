import 'package:flutter/widgets.dart';
import 'package:markdown_live/markdown_live.dart';

/// Markdown controller that never shows raw syntax markers in the editor.
class DdtMarkdownLiveController extends MarkdownLiveController {
  DdtMarkdownLiveController({super.text, super.theme});

  static const TextStyle _hiddenSyntaxStyle = TextStyle(
    fontSize: 0.01,
    letterSpacing: 0,
    wordSpacing: 0,
    color: Color(0x00000000),
    height: 0.01,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = (theme.baseStyle ?? const TextStyle()).merge(style);

    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final parsedTokens = tokens;
    if (parsedTokens.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    final children = <TextSpan>[];

    for (final token in parsedTokens) {
      if (token.isSyntax) {
        children.add(
          TextSpan(text: token.text, style: baseStyle.merge(_hiddenSyntaxStyle)),
        );
      } else {
        children.add(
          TextSpan(
            text: token.text,
            style: baseStyle.merge(_styleForType(token.type)),
          ),
        );
      }
    }

    return TextSpan(style: baseStyle, children: children);
  }

  TextStyle? _styleForType(MarkdownType type) {
    switch (type) {
      case MarkdownType.bold:
        return theme.boldStyle;
      case MarkdownType.italic:
        return theme.italicStyle;
      case MarkdownType.boldItalic:
        return theme.boldItalicStyle;
      case MarkdownType.strikethrough:
        return theme.strikethroughStyle;
      case MarkdownType.inlineCode:
        return theme.inlineCodeStyle;
      case MarkdownType.heading1:
        return theme.heading1Style;
      case MarkdownType.heading2:
        return theme.heading2Style;
      case MarkdownType.heading3:
        return theme.heading3Style;
      case MarkdownType.heading4:
        return theme.heading4Style;
      case MarkdownType.heading5:
        return theme.heading5Style;
      case MarkdownType.heading6:
        return theme.heading6Style;
      case MarkdownType.linkText:
        return theme.linkTextStyle;
      case MarkdownType.linkUrl:
        return theme.linkUrlStyle;
      case MarkdownType.plain:
        return TextStyle(color: theme.baseStyle?.color);
    }
  }
}

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown_live/markdown_live.dart';

/// Markdown controller that never shows raw syntax markers in the editor.
class DdtMarkdownLiveController extends MarkdownLiveController {
  DdtMarkdownLiveController({super.text, super.theme});

  bool _deferredNotifyScheduled = false;

  /// [MarkdownLiveEditor] assigns [theme] during build, which notifies
  /// [MarkdownLiveToolbar] listeners and triggers setState-in-build.
  @override
  void notifyListeners() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      super.notifyListeners();
      return;
    }
    if (_deferredNotifyScheduled) return;
    _deferredNotifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _deferredNotifyScheduled = false;
      super.notifyListeners();
    });
  }

  /// Near-zero size hides `#`, `**`, and the rest. A tiny [TextStyle.height]
  /// collapses the first line, so a heading paints outside the field.
  static const TextStyle _hiddenSyntaxStyle = TextStyle(
    fontSize: 0.01,
    letterSpacing: 0,
    wordSpacing: 0,
    color: Color(0x00000000),
    height: 1,
  );

  static final RegExp _bulletPrefix = RegExp(r'^[-*]\s');
  static final RegExp _numberPrefix = RegExp(r'^\d+\.\s');

  /// Toggles a `- ` prefix on each selected line.
  void toggleBulletList() => _toggleLinePrefix(_bulletPrefix, (index, line) {
    if (_numberPrefix.hasMatch(line)) {
      return '- ${line.replaceFirst(_numberPrefix, '')}';
    }
    return '- $line';
  });

  /// Toggles a `1. ` prefix on each selected line.
  void toggleNumberedList() => _toggleLinePrefix(_numberPrefix, (index, line) {
    final body = _bulletPrefix.hasMatch(line)
        ? line.replaceFirst(_bulletPrefix, '')
        : line;
    return '${index + 1}. $body';
  });

  bool get bulletListActive => _selectionLines.any(
    (line) => line.isNotEmpty && _bulletPrefix.hasMatch(line),
  );

  bool get numberedListActive => _selectionLines.any(
    (line) => line.isNotEmpty && _numberPrefix.hasMatch(line),
  );

  List<String> get _selectionLines {
    if (!selection.isValid || text.isEmpty) return const [];
    final bounds = _lineBounds(text, selection.start, selection.end);
    return text.substring(bounds.$1, bounds.$2).split('\n');
  }

  void _toggleLinePrefix(
    RegExp pattern,
    String Function(int index, String line) prefixLine,
  ) {
    final current = text;
    final sel = selection;
    if (!sel.isValid) return;

    final bounds = _lineBounds(current, sel.start, sel.end);
    final block = current.substring(bounds.$1, bounds.$2);
    final lines = block.split('\n');
    final contentLines = lines.where((line) => line.isNotEmpty);
    final remove =
        contentLines.isNotEmpty && contentLines.every(pattern.hasMatch);
    final nextLines = <String>[];
    var index = 0;
    if (lines.length == 1 && lines.first.isEmpty && !remove) {
      nextLines.add(prefixLine(0, ''));
    }
    for (final line in lines) {
      if (lines.length == 1 && line.isEmpty && !remove) continue;
      if (line.isEmpty) {
        nextLines.add(line);
        continue;
      }
      if (remove) {
        nextLines.add(line.replaceFirst(pattern, ''));
      } else if (pattern.hasMatch(line)) {
        nextLines.add(line);
      } else {
        nextLines.add(prefixLine(index, line));
      }
      index++;
    }
    final nextBlock = nextLines.join('\n');
    final nextText = current.replaceRange(bounds.$1, bounds.$2, nextBlock);
    final shift = nextBlock.length - block.length;
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: (sel.extentOffset + shift).clamp(0, nextText.length),
      ),
    );
  }

  (int, int) _lineBounds(String current, int start, int end) {
    final from = start.clamp(0, current.length);
    final to = end.clamp(from, current.length);
    // A caret at offset 0 sits before the first character. Searching at index
    // 0 would treat a leading newline as already passed and produce an empty
    // range that substring rejects.
    final newline = from == 0 ? -1 : current.lastIndexOf('\n', from - 1);
    final lineStart = newline == -1 ? 0 : newline + 1;
    var lineEnd = current.indexOf('\n', to);
    if (lineEnd == -1 || lineEnd < lineStart) lineEnd = current.length;
    return (lineStart, lineEnd);
  }

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
          TextSpan(
            text: token.text,
            style: baseStyle.merge(_hiddenSyntaxStyle),
          ),
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

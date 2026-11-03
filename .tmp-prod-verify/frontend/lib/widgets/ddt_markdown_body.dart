import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';

/// Renders [Markdown](https://spec.commonmark.org/) using `markdown` → HTML → [HtmlWidget].
class DdtMarkdownBody extends StatelessWidget {
  const DdtMarkdownBody({
    super.key,
    required this.data,
    this.textColor,
    this.fontSize,
    this.lineHeight = 1.55,
  });

  final String data;
  final Color? textColor;
  final double? fontSize;
  final double lineHeight;

  static String markdownToHtml(String source) {
    return md.markdownToHtml(
      source,
      extensionSet: md.ExtensionSet.gitHubWeb,
    );
  }

  /// Plain text for short previews (cards, snippets).
  static String plainTextPreview(String source) {
    var text = source.replaceAll('\r\n', '\n');
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
    text = text.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^>\s?', multiLine: true), '');
    text = text.replaceAll(RegExp(r'[*_~]'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  static String _cssColor(Color color) {
    final value = color.toARGB32();
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        textColor ??
        DdtTheme.sidePanelTextPrimary(context);
    final baseStyle = DdtTheme.style(
      fontSize: fontSize ?? DdtTypography.bodySize,
      height: lineHeight,
      color: color,
    );
    final codeBackground = isDark
        ? 'rgba(255, 255, 255, 0.10)'
        : 'rgba(0, 0, 0, 0.06)';
    final blockquoteBorder = DdtTheme.glassBorderColor(
      Theme.of(context).brightness,
    ).withValues(alpha: 0.45);

    return SelectionArea(
      child: HtmlWidget(
        markdownToHtml(data),
        textStyle: baseStyle,
        onTapUrl: (url) async {
          final uri = Uri.tryParse(url);
          if (uri == null) return true;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        },
        customStylesBuilder: (element) {
          switch (element.localName) {
            case 'h1':
            case 'h2':
            case 'h3':
            case 'h4':
              return {
                'margin-top': '0.85em',
                'margin-bottom': '0.4em',
                'font-weight': '700',
                'line-height': '1.25',
              };
            case 'p':
              return {'margin-top': '0', 'margin-bottom': '0.65em'};
            case 'ul':
            case 'ol':
              return {
                'margin-top': '0.25em',
                'margin-bottom': '0.65em',
                'padding-left': '1.35em',
              };
            case 'li':
              return {'margin-bottom': '0.25em'};
            case 'code':
              return {
                'background-color': codeBackground,
                'padding': '2px 5px',
                'border-radius': '4px',
                'font-family': 'monospace',
                'font-size': '0.92em',
              };
            case 'pre':
              return {
                'background-color': codeBackground,
                'padding': '10px 12px',
                'border-radius': '8px',
                'overflow-x': 'auto',
                'margin-top': '0.35em',
                'margin-bottom': '0.75em',
              };
            case 'blockquote':
              return {
                'border-left': '3px solid ${_cssColor(blockquoteBorder)}',
                'padding-left': '12px',
                'margin-left': '0',
                'margin-top': '0.35em',
                'margin-bottom': '0.75em',
                'opacity': '0.92',
              };
            case 'a':
              return {
                'color': _cssColor(AppColors.primary),
                'text-decoration': 'underline',
              };
            case 'hr':
              return {
                'border': '0',
                'border-top':
                    '1px solid ${_cssColor(DdtTheme.sidePanelDivider(context))}',
                'margin': '0.85em 0',
              };
            default:
              return null;
          }
        },
      ),
    );
  }
}

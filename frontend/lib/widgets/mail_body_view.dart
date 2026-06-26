import 'package:flutter/material.dart';

import '../theme/ddt_theme.dart';
import 'mail_html_document.dart';
import 'mail_html_renderer.dart';

class MailBodyView extends StatefulWidget {
  const MailBodyView({
    super.key,
    required this.messageId,
    required this.body,
    required this.bodyType,
    this.fallback,
  });

  final String messageId;
  final String body;
  final String bodyType;
  final String? fallback;

  @override
  State<MailBodyView> createState() => _MailBodyViewState();
}

class _MailBodyViewState extends State<MailBodyView>
    with AutomaticKeepAliveClientMixin {
  String? _cachedHtml;

  @override
  bool get wantKeepAlive => true;

  bool get _isHtml => widget.bodyType == 'html';

  @override
  void didUpdateWidget(MailBodyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId ||
        oldWidget.body != widget.body ||
        oldWidget.bodyType != widget.bodyType) {
      _cachedHtml = null;
    }
  }

  String get _content {
    if (widget.body.isNotEmpty) return widget.body;
    return widget.fallback ?? '';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final content = _content;
    if (content.isEmpty) {
      return Text(
        'Содержимое письма недоступно',
        style: DdtTheme.style(
          fontSize: 14,
          color: DdtTheme.taskCardTextSecondary(context),
        ),
      );
    }

    if (_isHtml) {
      _cachedHtml ??= MailHtmlDocument.prepare(content);
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: DdtTheme.radius,
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: DdtTheme.radius,
          child: SizedBox.expand(
            child: MailHtmlRenderer(
              viewId: 'mail-html-${widget.messageId.hashCode}',
              html: _cachedHtml!,
            ),
          ),
        ),
      );
    }

    return SelectableText(
      content,
      style: DdtTheme.style(
        fontSize: 14,
        height: 1.6,
        color: DdtTheme.taskCardTextPrimary(context),
      ),
    );
  }
}

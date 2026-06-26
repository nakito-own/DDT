import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/ddt_theme.dart';

class MailHtmlRenderer extends StatelessWidget {
  const MailHtmlRenderer({
    super.key,
    required this.viewId,
    required this.html,
  });

  final String viewId;
  final String html;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: HtmlWidget(
        html,
        textStyle: DdtTheme.style(
          fontSize: 14,
          height: 1.6,
          color: const Color(0xFF1A1A1A),
        ),
        onTapUrl: (url) async {
          final uri = Uri.tryParse(url);
          if (uri == null) return true;

          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          return launched;
        },
      ),
    );
  }
}

import 'dart:js_interop';

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class MailHtmlRenderer extends StatefulWidget {
  const MailHtmlRenderer({super.key, required this.viewId, required this.html});

  final String viewId;
  final String html;

  @override
  State<MailHtmlRenderer> createState() => _MailHtmlRendererState();
}

class _MailHtmlRendererState extends State<MailHtmlRenderer> {
  static final Set<String> _registeredViews = <String>{};

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
  }

  void _registerViewFactory() {
    if (_registeredViews.contains(widget.viewId)) return;

    _registeredViews.add(widget.viewId);
    final html = widget.html;

    ui_web.platformViewRegistry.registerViewFactory(widget.viewId, (_) {
      return web.HTMLIFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.backgroundColor = '#ffffff'
        ..style.overflow = 'auto'
        ..referrerPolicy = 'no-referrer-when-downgrade'
        ..setAttribute('scrolling', 'yes')
        ..srcdoc = html.toJS;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: HtmlElementView(viewType: widget.viewId),
    );
  }
}

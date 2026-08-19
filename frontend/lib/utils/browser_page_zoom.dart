import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:web/web.dart' as web;

@JS('ddtSyncFlutterViewport')
external void _syncFlutterViewportJs();

void syncFlutterViewport() {
  if (!kIsWeb) {
    return;
  }

  try {
    _syncFlutterViewportJs();
  } catch (_) {}
}

class FlutterViewportSyncScope extends StatefulWidget {
  const FlutterViewportSyncScope({super.key, required this.child});

  final Widget child;

  @override
  State<FlutterViewportSyncScope> createState() =>
      _FlutterViewportSyncScopeState();
}

class _FlutterViewportSyncScopeState extends State<FlutterViewportSyncScope>
    with WidgetsBindingObserver {
  web.EventListener? _visualViewportListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (kIsWeb) {
      _visualViewportListener = ((web.Event _) {
        syncFlutterViewport();
      }).toJS;

      final visualViewport = web.window.visualViewport;
      visualViewport?.addEventListener('resize', _visualViewportListener);
      visualViewport?.addEventListener('scroll', _visualViewportListener);
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      syncFlutterViewport();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    if (kIsWeb) {
      final visualViewport = web.window.visualViewport;
      final listener = _visualViewportListener;
      if (visualViewport != null && listener != null) {
        visualViewport.removeEventListener('resize', listener);
        visualViewport.removeEventListener('scroll', listener);
      }
    }

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    syncFlutterViewport();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

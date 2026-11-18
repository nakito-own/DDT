import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'ddt_desktop_shortcuts.dart';

abstract final class DdtDesktopKeyRelay {
  static var _installed = false;

  static void ensureInstalled() {
    if (_installed || !ddtDesktopWeb) return;
    _installed = true;
    web.window.addEventListener(
      'keydown',
      (web.Event event) {
        if (event.defaultPrevented) return;
        final keyEvent = event as web.KeyboardEvent;
        final handled = DdtDesktopShortcutRegistry.handleBrowserKey(
          key: keyEvent.key,
          shift: keyEvent.shiftKey,
          meta: keyEvent.metaKey,
          control: keyEvent.ctrlKey,
          alt: keyEvent.altKey,
          composing: keyEvent.isComposing,
          repeat: keyEvent.repeat,
          flutterHandled: false,
        );
        if (!handled) return;
        event.preventDefault();
        event.stopImmediatePropagation();
      }.toJS,
      true.toJS,
    );
  }
}

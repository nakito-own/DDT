import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ddt_desktop_key_relay.dart';

/// Desktop browsers. Phones and tablets keep the platform keyboard behavior.
bool get ddtDesktopWeb {
  if (!kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => false,
    _ => true,
  };
}

enum DdtDesktopKeyEffect { ignore, escape, fieldEnter, commandEnter }

/// What the desktop-web key relay should do with one keydown.
///
/// Flutter's own shortcut walk runs first. When it already handled the event,
/// [flutterHandled] is set and this returns [DdtDesktopKeyEffect.ignore] so a
/// menu or dialog is not closed twice.
DdtDesktopKeyEffect ddtDesktopKeyEffect({
  required String key,
  required bool shift,
  required bool meta,
  required bool control,
  required bool alt,
  required bool composing,
  required bool repeat,
  required bool flutterHandled,
  required bool fieldEnterBound,
  required bool escapeBound,
  required bool commandEnterBound,
}) {
  if (flutterHandled || composing || repeat) return DdtDesktopKeyEffect.ignore;
  if (key == 'Escape') {
    if (shift || meta || control || alt || !escapeBound) {
      return DdtDesktopKeyEffect.ignore;
    }
    return DdtDesktopKeyEffect.escape;
  }
  final enter = key == 'Enter' || key == 'NumpadEnter';
  if (!enter || alt) return DdtDesktopKeyEffect.ignore;
  if (meta || control) {
    if (shift || !commandEnterBound) return DdtDesktopKeyEffect.ignore;
    return DdtDesktopKeyEffect.commandEnter;
  }
  if (shift || !fieldEnterBound) return DdtDesktopKeyEffect.ignore;
  return DdtDesktopKeyEffect.fieldEnter;
}

/// Closes a menu, dialog, or dropdown that is sitting above [context].
///
/// Returns true when something was popped and the page itself should stay.
bool ddtPopOverlayIfAny(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route != null && !route.isCurrent) {
    Navigator.of(context).maybePop();
    return true;
  }
  return false;
}

class _ShortcutBinding {
  _ShortcutBinding({this.onEscape, this.onCommandEnter});

  VoidCallback? onEscape;
  VoidCallback? onCommandEnter;
}

/// Page-level Escape and Cmd/Ctrl+Enter, plus Enter for a focused field.
///
/// On desktop web the browser delivers keys to the hidden text input, so the
/// relay listens on the window. Elsewhere the same actions use Flutter
/// shortcuts, which only run while focus is inside [child].
class DdtPageShortcuts extends StatefulWidget {
  const DdtPageShortcuts({
    super.key,
    required this.child,
    this.onEscape,
    this.onCommandEnter,
  });

  final Widget child;
  final VoidCallback? onEscape;
  final VoidCallback? onCommandEnter;

  @override
  State<DdtPageShortcuts> createState() => _DdtPageShortcutsState();
}

class _DdtPageShortcutsState extends State<DdtPageShortcuts> {
  late final _ShortcutBinding _binding = _ShortcutBinding(
    onEscape: widget.onEscape,
    onCommandEnter: widget.onCommandEnter,
  );

  @override
  void initState() {
    super.initState();
    _pushShortcut(_binding);
  }

  @override
  void didUpdateWidget(covariant DdtPageShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    _binding.onEscape = widget.onEscape;
    _binding.onCommandEnter = widget.onCommandEnter;
  }

  @override
  void dispose() {
    _removeShortcut(_binding);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ddtDesktopWeb) return widget.child;
    final bindings = <ShortcutActivator, VoidCallback>{
      if (widget.onEscape != null)
        const SingleActivator(LogicalKeyboardKey.escape): widget.onEscape!,
      if (widget.onCommandEnter != null) ...{
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            widget.onCommandEnter!,
        const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
            widget.onCommandEnter!,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            widget.onCommandEnter!,
        const SingleActivator(LogicalKeyboardKey.numpadEnter, meta: true):
            widget.onCommandEnter!,
      },
    };
    if (bindings.isEmpty) return widget.child;
    return CallbackShortcuts(bindings: bindings, child: widget.child);
  }
}

/// Focused text fields that should submit on Enter.
void _pushShortcut(_ShortcutBinding binding) {
  DdtDesktopShortcutRegistry._stack.add(binding);
  DdtDesktopKeyRelay.ensureInstalled();
}

void _removeShortcut(_ShortcutBinding binding) {
  DdtDesktopShortcutRegistry._stack.remove(binding);
}

abstract final class DdtDesktopShortcutRegistry {
  static final List<_ShortcutBinding> _stack = [];
  static final Map<FocusNode, VoidCallback> _enter = {};

  static void bindEnter(FocusNode node, VoidCallback? submit) {
    if (submit == null) {
      _enter.remove(node);
      return;
    }
    _enter[node] = submit;
    DdtDesktopKeyRelay.ensureInstalled();
  }

  static void unbindEnter(FocusNode node) {
    _enter.remove(node);
  }

  static _ShortcutBinding? get _top {
    for (var i = _stack.length - 1; i >= 0; i--) {
      final binding = _stack[i];
      if (binding.onEscape != null || binding.onCommandEnter != null) {
        return binding;
      }
    }
    return null;
  }

  /// Returns true when the relay should cancel the browser's default action.
  static bool handleBrowserKey({
    required String key,
    required bool shift,
    required bool meta,
    required bool control,
    required bool alt,
    required bool composing,
    required bool repeat,
    required bool flutterHandled,
  }) {
    final focus = FocusManager.instance.primaryFocus;
    final effect = ddtDesktopKeyEffect(
      key: key,
      shift: shift,
      meta: meta,
      control: control,
      alt: alt,
      composing: composing,
      repeat: repeat,
      flutterHandled: flutterHandled,
      fieldEnterBound: focus != null && _enter.containsKey(focus),
      escapeBound: _top?.onEscape != null,
      commandEnterBound: _top?.onCommandEnter != null,
    );
    switch (effect) {
      case DdtDesktopKeyEffect.ignore:
        return false;
      case DdtDesktopKeyEffect.escape:
        _top?.onEscape?.call();
        return true;
      case DdtDesktopKeyEffect.fieldEnter:
        if (focus != null) _enter[focus]?.call();
        return true;
      case DdtDesktopKeyEffect.commandEnter:
        _top?.onCommandEnter?.call();
        return true;
    }
  }
}

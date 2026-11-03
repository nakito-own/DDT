import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Duration _kPromptDuration = Duration(milliseconds: 220);
const double _kPromptWidth = 420;
const double _kPromptHeight = 248;
const double _kPromptBlur = 3.5;
const double _kPromptBarrier = 0.58;

/// Asks for a single line of text. The host app can replace the canvas dialog
/// with its own field and window.
typedef NodelineTextPrompt = Future<String?> Function({
  required String title,
  required String initial,
  required String hint,
  required String confirmLabel,
  String cancelLabel,
  String? clearLabel,
  bool allowEmpty,
});

class NodelinePromptHost extends InheritedWidget {
  const NodelinePromptHost({
    super.key,
    required this.prompt,
    required super.child,
  });

  final NodelineTextPrompt prompt;

  static NodelineTextPrompt? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<NodelinePromptHost>()?.prompt;
  }

  @override
  bool updateShouldNotify(NodelinePromptHost oldWidget) =>
      prompt != oldWidget.prompt;
}
const Color _kPromptPrimary = Color(0xFF5279C7);
const Color _kPromptPrimaryHover = Color(0xFF4267B2);
const Color _kPromptDanger = Color(0xFFD65C5C);

/// Uses the host app's prompt when one is installed, otherwise the canvas dialog.
Future<String?> askNodelinePrompt(
  BuildContext context, {
  required String title,
  required String initial,
  required String hint,
  required String confirmLabel,
  String cancelLabel = 'Отмена',
  String? clearLabel,
  bool allowEmpty = false,
}) async {
  final host = NodelinePromptHost.maybeOf(context);
  if (host != null) {
    return host(
      title: title,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      clearLabel: clearLabel,
      allowEmpty: allowEmpty,
    );
  }

  final controller = TextEditingController(text: initial);
  try {
    final value = await showNodelinePromptDialog(
      context: context,
      title: title,
      controller: controller,
      hint: hint,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      clearLabel: clearLabel,
    );
    if (value == null) return null;
    final trimmed = value.trim();
    if (!allowEmpty && trimmed.isEmpty) return null;
    return trimmed;
  } finally {
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  }
}

/// Canvas fallback when the host app does not install [NodelinePromptHost].
///
/// The canvas package cannot use the app's dialog widgets, so this copy
/// follows the same size, blur, and entrance.
Future<String?> showNodelinePromptDialog({
  required BuildContext context,
  required String title,
  required TextEditingController controller,
  String hint = '',
  String confirmLabel = 'Сохранить',
  String cancelLabel = 'Отмена',
  String? clearLabel,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Закрыть',
    barrierColor: Colors.transparent,
    transitionDuration: _kPromptDuration,
    pageBuilder: (dialogContext, animation, _) {
      return _NodelinePromptRoute(
        animation: animation,
        title: title,
        controller: controller,
        hint: hint,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        clearLabel: clearLabel,
      );
    },
    transitionBuilder: (_, _, _, child) => child,
  );
}

class _NodelinePromptRoute extends StatefulWidget {
  const _NodelinePromptRoute({
    required this.animation,
    required this.title,
    required this.controller,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.clearLabel,
  });

  final Animation<double> animation;
  final String title;
  final TextEditingController controller;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;
  final String? clearLabel;

  @override
  State<_NodelinePromptRoute> createState() => _NodelinePromptRouteState();
}

class _NodelinePromptRouteState extends State<_NodelinePromptRoute> {
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  void _close([String? value]) => Navigator.of(context).pop(value);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom;
    final width = math.min(
      _kPromptWidth,
      math.max(280.0, media.size.width - 32),
    );
    final height = math.min(
      _kPromptHeight,
      math.max(180.0, media.size.height - bottom - 32),
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF10131A) : Colors.white;
    final border = dark ? const Color(0xFF262B38) : const Color(0xFFDCE3EE);
    final titleColor = dark ? const Color(0xFFF1F5F9) : const Color(0xFF182232);

    final card = FadeTransition(
      opacity: _curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(_curved),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 12),
                _PromptField(controller: widget.controller, hint: widget.hint),
                const Spacer(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.clearLabel != null) ...[
                      _PromptButton(
                        label: widget.clearLabel!,
                        kind: _PromptButtonKind.danger,
                        onPressed: () => _close(''),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _PromptButton(
                      label: widget.cancelLabel,
                      onPressed: () => _close(),
                    ),
                    const SizedBox(width: 8),
                    _PromptButton(
                      label: widget.confirmLabel,
                      kind: _PromptButtonKind.primary,
                      onPressed: () => _close(widget.controller.text),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => _close(),
        },
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _curved,
                builder: (context, _) {
                  final t = _curved.value.clamp(0.0, 1.0);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _close(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: _kPromptBlur * t,
                        sigmaY: _kPromptBlur * t,
                      ),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: _kPromptBarrier * t),
                      ),
                    ),
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottom),
                  child: Center(child: card),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptField extends StatefulWidget {
  const _PromptField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  State<_PromptField> createState() => _PromptFieldState();
}

class _PromptFieldState extends State<_PromptField> {
  late final FocusNode _focus = FocusNode()..addListener(() => setState(() {}));

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final focused = _focus.hasFocus;
    final fill = dark ? const Color(0xB812151E) : const Color(0xB8FFFFFF);
    final border = focused
        ? _kPromptPrimary
        : (dark ? const Color(0xFF363D4E) : const Color(0xFFC4CFE0));
    final hintColor = (dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
        .withValues(alpha: 0.72);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: _kPromptPrimary.withValues(alpha: dark ? 0.25 : 0.16),
                  spreadRadius: 2.5,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: true,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: dark ? const Color(0xFFF1F5F9) : const Color(0xFF182232),
        ),
        cursorColor: _kPromptPrimary,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ).copyWith(
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: 14, color: hintColor),
        ),
      ),
    );
  }
}

enum _PromptButtonKind { neutral, primary, danger }

class _PromptButton extends StatefulWidget {
  const _PromptButton({
    required this.label,
    required this.onPressed,
    this.kind = _PromptButtonKind.neutral,
  });

  final String label;
  final VoidCallback onPressed;
  final _PromptButtonKind kind;

  @override
  State<_PromptButton> createState() => _PromptButtonState();
}

class _PromptButtonState extends State<_PromptButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color fill;
    final Color foreground;
    final Color side;
    switch (widget.kind) {
      case _PromptButtonKind.primary:
        fill = _hovered ? _kPromptPrimaryHover : _kPromptPrimary;
        foreground = Colors.white;
        side = Colors.white.withValues(alpha: 0.16);
      case _PromptButtonKind.danger:
        fill = _hovered ? const Color(0xFFC44E4E) : _kPromptDanger;
        foreground = Colors.white;
        side = Colors.white.withValues(alpha: 0.14);
      case _PromptButtonKind.neutral:
        final hoverFill = dark
            ? const Color(0xFF0C0E14)
            : const Color(0xFFF6F8FC);
        fill = _hovered ? hoverFill : hoverFill.withValues(alpha: 0);
        foreground = dark ? const Color(0xFFF1F5F9) : const Color(0xFF182232);
        side = dark ? const Color(0xFF363D4E) : const Color(0xFFC4CFE0);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: side),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

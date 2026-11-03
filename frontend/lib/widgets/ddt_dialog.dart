import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_app_input.dart';

/// Fixed footprint of the standard confirm / prompt window.
const double _kDialogWidth = 420;
const double _kDialogHeight = 248;
const double _kDialogWideWidth = 460;
const double _kDialogFormHeight = 360;
const double _kDialogTallHeight = 560;

const Duration _kDialogDuration = Duration(milliseconds: 220);
const Curve _kDialogCurve = Curves.easeOutCubic;
const double _kDialogBlurSigma = 3.5;
const double _kDialogBarrierOpacity = 0.58;

enum DdtDialogActionKind { neutral, primary, danger }

class DdtDialogAction {
  const DdtDialogAction({
    required this.label,
    required this.onPressed,
    this.kind = DdtDialogActionKind.neutral,
  });

  final String label;
  final VoidCallback? onPressed;
  final DdtDialogActionKind kind;
}

/// Centered modal with a fixed size, a dimmed blurred page behind it,
/// and a short scale-and-fade entrance.
Future<T?> showDdtDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  double width = _kDialogWidth,
  double height = _kDialogHeight,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Закрыть',
    barrierColor: Colors.transparent,
    transitionDuration: _kDialogDuration,
    pageBuilder: (dialogContext, animation, _) {
      return _DdtDialogRoute(
        animation: animation,
        width: width,
        height: height,
        barrierDismissible: barrierDismissible,
        child: Builder(builder: builder),
      );
    },
    transitionBuilder: (_, _, _, child) => child,
  );
}

/// Confirm or delete prompt. Returns `true` only when the confirm action is used.
Future<bool?> showDdtConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Отмена',
  String confirmLabel = 'Удалить',
  bool destructive = true,
}) {
  return showDdtDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return DdtDialog(
        title: title,
        message: message,
        actions: [
          DdtDialogAction(
            label: cancelLabel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          DdtDialogAction(
            label: confirmLabel,
            kind: destructive
                ? DdtDialogActionKind.danger
                : DdtDialogActionKind.primary,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );
}

/// Single-line prompt. An empty value stays open unless [allowEmpty] is set.
Future<String?> showDdtTextPrompt(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String hint = 'Название',
  String initial = '',
  String cancelLabel = 'Отмена',
  String? clearLabel,
  bool allowEmpty = false,
}) {
  return showDdtDialog<String>(
    context: context,
    builder: (dialogContext) {
      return _DdtTextPrompt(
        title: title,
        hint: hint,
        initial: initial,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        clearLabel: clearLabel,
        allowEmpty: allowEmpty,
      );
    },
  );
}

/// Dims and blurs whatever is already on screen under a modal route.
class DdtModalBarrier extends StatefulWidget {
  const DdtModalBarrier({
    super.key,
    required this.animation,
    this.onDismiss,
  });

  final Animation<double> animation;
  final VoidCallback? onDismiss;

  @override
  State<DdtModalBarrier> createState() => _DdtModalBarrierState();
}

class _DdtModalBarrierState extends State<DdtModalBarrier> {
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: widget.animation,
    curve: _kDialogCurve,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, _) {
        final t = _curved.value.clamp(0.0, 1.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _kDialogBlurSigma * t,
              sigmaY: _kDialogBlurSigma * t,
            ),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: _kDialogBarrierOpacity * t),
            ),
          ),
        );
      },
    );
  }
}

/// Scale and fade used by modal content as the route animation runs.
class DdtModalEntrance extends StatefulWidget {
  const DdtModalEntrance({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  State<DdtModalEntrance> createState() => _DdtModalEntranceState();
}

class _DdtModalEntranceState extends State<DdtModalEntrance> {
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: widget.animation,
    curve: _kDialogCurve,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.96,
    end: 1,
  ).animate(_curved);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.03),
    end: Offset.zero,
  ).animate(_curved);

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

class DdtDialog extends StatelessWidget {
  const DdtDialog({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.body,
    this.expandBody = false,
  });

  static const double width = _kDialogWidth;
  static const double height = _kDialogHeight;
  static const double wideWidth = _kDialogWideWidth;
  static const double formHeight = _kDialogFormHeight;
  static const double tallHeight = _kDialogTallHeight;

  final String title;
  final String? message;
  final Widget? body;
  final bool expandBody;
  final List<DdtDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      namesRoute: true,
      scopesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DdtTheme.style(
                fontSize: DdtTypography.panelTitleSize,
                fontWeight: FontWeight.w600,
                color: DdtTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _middle(context)),
            const SizedBox(height: 16),
            _DdtDialogActions(actions: actions),
          ],
        ),
      ),
    );
  }

  Widget _middle(BuildContext context) {
    final message = this.message;
    final body = this.body;
    if (expandBody && body != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) ...[
            Text(
              message,
              style: DdtTheme.style(
                fontSize: DdtTypography.bodySize,
                color: DdtTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Expanded(child: body),
        ],
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null)
              Text(
                message,
                style: DdtTheme.style(
                  fontSize: DdtTypography.bodySize,
                  height: 1.4,
                  color: DdtTheme.textSecondary(context),
                ),
              ),
            if (body != null) ...[
              if (message != null) const SizedBox(height: 14),
              body,
            ],
          ],
        ),
      ),
    );
  }
}

class _DdtDialogRoute extends StatelessWidget {
  const _DdtDialogRoute({
    required this.animation,
    required this.width,
    required this.height,
    required this.barrierDismissible,
    required this.child,
  });

  final Animation<double> animation;
  final double width;
  final double height;
  final bool barrierDismissible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom;
    final cardWidth = math.min(width, math.max(280.0, media.size.width - 32));
    final cardHeight = math.min(
      height,
      math.max(180.0, media.size.height - bottom - 32),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final radius = BorderRadius.circular(DdtTheme.borderRadius);
    final card = DdtModalEntrance(
      animation: animation,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: isDark ? DdtTheme.darkSurface : DdtTheme.lightSurface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: DdtTheme.borderSubtle(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );

    final barrier = DdtModalBarrier(
      animation: animation,
      onDismiss: barrierDismissible
          ? () => Navigator.of(context).maybePop()
          : null,
    );

    final scene = Stack(
      fit: StackFit.expand,
      children: [
        kIsWeb ? PointerInterceptor(child: barrier) : barrier,
        SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Center(child: card),
          ),
        ),
      ],
    );

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (barrierDismissible) Navigator.of(context).maybePop();
          },
        },
        child: Material(type: MaterialType.transparency, child: scene),
      ),
    );
  }
}

class _DdtTextPrompt extends StatefulWidget {
  const _DdtTextPrompt({
    required this.title,
    required this.hint,
    required this.initial,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.clearLabel,
    required this.allowEmpty,
  });

  final String title;
  final String hint;
  final String initial;
  final String confirmLabel;
  final String cancelLabel;
  final String? clearLabel;
  final bool allowEmpty;

  @override
  State<_DdtTextPrompt> createState() => _DdtTextPromptState();
}

class _DdtTextPromptState extends State<_DdtTextPrompt> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty && !widget.allowEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return DdtDialog(
      title: widget.title,
      body: DdtAppInput(
        controller: _controller,
        hint: widget.hint,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        if (widget.clearLabel != null)
          DdtDialogAction(
            label: widget.clearLabel!,
            kind: DdtDialogActionKind.danger,
            onPressed: () => Navigator.of(context).pop(''),
          ),
        DdtDialogAction(
          label: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DdtDialogAction(
          label: widget.confirmLabel,
          kind: DdtDialogActionKind.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _DdtDialogActions extends StatelessWidget {
  const _DdtDialogActions({required this.actions});

  final List<DdtDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final compact = DdtTheme.isCompactLayout(context);
    final buttons = [
      for (final action in actions)
        _DdtDialogButton(action: action, expand: compact),
    ];

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            buttons[i],
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          buttons[i],
        ],
      ],
    );
  }
}

class _DdtDialogButton extends StatefulWidget {
  const _DdtDialogButton({required this.action, required this.expand});

  final DdtDialogAction action;
  final bool expand;

  @override
  State<_DdtDialogButton> createState() => _DdtDialogButtonState();
}

class _DdtDialogButtonState extends State<_DdtDialogButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final enabled = action.onPressed != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kind = action.kind;

    final Color fill;
    final Color foreground;
    final BorderSide side;
    switch (kind) {
      case DdtDialogActionKind.primary:
        fill = !enabled
            ? DdtTheme.primaryColor.withValues(alpha: 0.45)
            : _pressed
            ? const Color(0xFF3730A3)
            : _hovered
            ? DdtTheme.primaryHoverColor
            : DdtTheme.primaryColor;
        foreground = Colors.white;
        side = BorderSide(
          color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.18),
        );
      case DdtDialogActionKind.danger:
        fill = !enabled
            ? DdtTheme.dangerColor.withValues(alpha: 0.45)
            : _pressed
            ? const Color(0xFFB54747)
            : _hovered
            ? const Color(0xFFC44E4E)
            : DdtTheme.dangerColor;
        foreground = Colors.white;
        side = BorderSide(color: Colors.white.withValues(alpha: 0.14));
      case DdtDialogActionKind.neutral:
        final hoverFill = DdtTheme.surfaceSubtle(context);
        // Transparent black lerps through gray and the button flashes.
        fill = _hovered || _pressed
            ? hoverFill
            : hoverFill.withValues(alpha: 0);
        foreground = enabled
            ? DdtTheme.textPrimary(context)
            : DdtTheme.textMuted(context);
        side = BorderSide(color: DdtTheme.borderStrong(context));
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: action.onPressed,
        child: AnimatedContainer(
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          width: widget.expand ? double.infinity : null,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: DdtTheme.inputControlBorderRadius,
            border: Border.fromBorderSide(side),
          ),
          child: Text(
            action.label,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodySize,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

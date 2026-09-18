import 'dart:async';
import 'dart:ui';
import '../theme/ddt_icons.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';

const Duration _kSidePanelDuration = Duration(milliseconds: 340);
const Curve _kSidePanelCurve = Curves.easeInOutCubic;
const double _kSidePanelBlurSigma = 4;
const double _kSidePanelScrollFadeHeight = 40;
/// Scroll content starts this far through the fade (0 = opaque edge, 1 = fully transparent edge).
const double _kSidePanelFadeContentAnchor = 0.68;

OverlayEntry? _activeSidePanelOverlayEntry;

/// Shows a dialog above an open side panel, keeping the panel blur intact.
Future<T?> showDdtSidePanelDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final anchorEntry = _activeSidePanelOverlayEntry;
  final completer = Completer<T?>();
  final theme = Theme.of(context);

  late OverlayEntry dialogEntry;
  var dialogClosed = false;
  dialogEntry = OverlayEntry(
    builder: (overlayContext) => Theme(
      data: theme,
      child: _DdtSidePanelStackedDialog<T>(
        barrierDismissible: barrierDismissible,
        builder: builder,
        onClosed: (result) {
          if (dialogClosed) return;
          dialogClosed = true;
          dialogEntry.remove();
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        },
      ),
    ),
  );

  if (anchorEntry != null) {
    overlay.insert(dialogEntry, above: anchorEntry);
  } else {
    overlay.insert(dialogEntry);
  }

  return completer.future;
}

Future<T?> showDdtSidePanel<T>(
  BuildContext context, {
  required Widget child,
  double? maxWidth,
}) {
  final overlayState = Overlay.of(context, rootOverlay: true);
  final completer = Completer<T?>();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => _DdtSidePanelOverlay<T>(
      maxWidth: maxWidth,
      onDismissed: (result) {
        entry.remove();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      },
      child: child,
    ),
  );

  overlayState.insert(entry);
  _activeSidePanelOverlayEntry = entry;
  return completer.future.whenComplete(() {
    if (_activeSidePanelOverlayEntry == entry) {
      _activeSidePanelOverlayEntry = null;
    }
  });
}

class _DdtSidePanelOverlay<T> extends StatefulWidget {
  const _DdtSidePanelOverlay({
    required this.child,
    required this.onDismissed,
    this.maxWidth,
  });

  final Widget child;
  final ValueChanged<T?> onDismissed;
  final double? maxWidth;

  @override
  State<_DdtSidePanelOverlay<T>> createState() => _DdtSidePanelOverlayState<T>();
}

class _DdtSidePanelOverlayState<T> extends State<_DdtSidePanelOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kSidePanelDuration,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: _kSidePanelCurve,
    reverseCurve: _kSidePanelCurve,
  );
  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(_animation);

  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss([T? result]) async {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;

    await _controller.reverse();
    if (mounted) {
      widget.onDismissed(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = DdtTheme.sidePanelWidth(context, maxWidth: widget.maxWidth);
    final height = DdtTheme.sidePanelHeight(context);

    final barrier = AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value;
        final scrim = Container(
          color: Colors.black.withValues(alpha: 0.12 * progress),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(_dismiss()),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _kSidePanelBlurSigma * progress,
              sigmaY: _kSidePanelBlurSigma * progress,
            ),
            child: scrim,
          ),
        );
      },
    );

    final panel = SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: DdtTheme.sidePanelInsets(context),
          child: SizedBox(
            width: width,
            height: height,
            child: Material(
              type: MaterialType.transparency,
              child: Navigator(
                onGenerateRoute: (_) => _DdtSidePanelPageRoute<T>(
                  builder: (_) => widget.child,
                  onClose: _dismiss,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        kIsWeb ? PointerInterceptor(child: barrier) : barrier,
        panel,
      ],
    );
  }
}

class _DdtSidePanelPageRoute<T> extends MaterialPageRoute<T> {
  _DdtSidePanelPageRoute({
    required super.builder,
    required this.onClose,
  });

  final Future<void> Function(T? result) onClose;

  @override
  bool didPop(T? result) {
    unawaited(onClose(result));
    super.didPop(result);
    return false;
  }
}

class _DdtSidePanelStackedDialog<T> extends StatelessWidget {
  const _DdtSidePanelStackedDialog({
    required this.builder,
    required this.onClosed,
    this.barrierDismissible = true,
  });

  final WidgetBuilder builder;
  final ValueChanged<T?> onClosed;
  final bool barrierDismissible;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: kIsWeb
                ? PointerInterceptor(
                    child: ModalBarrier(
                      dismissible: barrierDismissible,
                      onDismiss: () => onClosed(null),
                      color: Colors.black54,
                    ),
                  )
                : ModalBarrier(
                    dismissible: barrierDismissible,
                    onDismiss: () => onClosed(null),
                    color: Colors.black54,
                  ),
          ),
          Navigator(
            initialRoute: '/',
            observers: [_DdtSidePanelDialogObserver<T>(onClosed)],
            onGenerateRoute: (settings) {
              return PageRouteBuilder<T>(
                settings: settings,
                opaque: false,
                barrierColor: Colors.transparent,
                pageBuilder: (dialogContext, _, __) {
                  return Center(child: builder(dialogContext));
                },
                transitionsBuilder: (_, __, ___, child) => child,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DdtSidePanelDialogObserver<T> extends NavigatorObserver {
  _DdtSidePanelDialogObserver(this.onClosed);

  final ValueChanged<T?> onClosed;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onClosed(route.currentResult as T?);
  }
}

class DdtSidePanelShell extends StatelessWidget {
  const DdtSidePanelShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.footer,
    this.onClose,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? footer;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = DdtTheme.sidePanelSurfaceColor(context);
    final headerExtent = _SidePanelHeaderChrome.scrollTopInset(context);
    final footerExtent = footer == null
        ? 0.0
        : _SidePanelFooterChrome.scrollBottomInset(context);

    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: DdtTheme.sidePanelTheme(context),
        child: DdtTheme.sidePanelGlass(
          context: context,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: _SidePanelInsetScrollChild(
                    scrollPadding: EdgeInsets.only(
                      top: headerExtent,
                      bottom: footerExtent,
                      left: DdtTheme.spacing.w,
                      right: DdtTheme.spacing.w,
                    ),
                    child: child,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _SidePanelHeaderChrome(
                  surfaceColor: surfaceColor,
                  title: title,
                  actions: actions,
                  onClose: onClose,
                ),
              ),
              if (footer != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _SidePanelFooterChrome(
                    surfaceColor: surfaceColor,
                    footer: footer!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidePanelScrollFade extends StatelessWidget {
  const _SidePanelScrollFade({
    required this.surfaceColor,
    required this.atTop,
  });

  final Color surfaceColor;
  final bool atTop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: _kSidePanelScrollFadeHeight.h,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.42, 1],
              colors: atTop
                  ? [
                      surfaceColor,
                      surfaceColor.withValues(alpha: 0.72),
                      surfaceColor.withValues(alpha: 0),
                    ]
                  : [
                      surfaceColor.withValues(alpha: 0),
                      surfaceColor.withValues(alpha: 0.72),
                      surfaceColor,
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidePanelHeaderChrome extends StatelessWidget {
  const _SidePanelHeaderChrome({
    required this.surfaceColor,
    required this.title,
    this.actions,
    this.onClose,
  });

  final Color surfaceColor;
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onClose;

  static double _titleBarHeight(BuildContext context) {
    return 14.h + DdtTypography.panelTitleSize.sp + 14.h;
  }

  static double scrollTopInset(BuildContext context) {
    final fade = _kSidePanelScrollFadeHeight.h;
    return _titleBarHeight(context) + fade * _kSidePanelFadeContentAnchor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: surfaceColor,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DdtTheme.spacing.w,
              14.h,
              4.w,
              14.h,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.panelTitleSize,
                      fontWeight: FontWeight.w700,
                      color: DdtTheme.sidePanelTextPrimary(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions != null) ...actions!,
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                  icon: DdtIcon(
                    DdtIcons.close,
                    size: 20.sp,
                    color: DdtTheme.sidePanelTextPrimary(context),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        _SidePanelScrollFade(surfaceColor: surfaceColor, atTop: true),
      ],
    );
  }
}

class _SidePanelFooterChrome extends StatelessWidget {
  const _SidePanelFooterChrome({
    required this.surfaceColor,
    required this.footer,
  });

  final Color surfaceColor;
  final Widget footer;

  static double _footerSolidHeight(BuildContext context) {
    return DdtTheme.spacing.w * 2 + 52.h;
  }

  static double scrollBottomInset(BuildContext context) {
    final fade = _kSidePanelScrollFadeHeight.h;
    return _footerSolidHeight(context) + fade * _kSidePanelFadeContentAnchor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SidePanelScrollFade(surfaceColor: surfaceColor, atTop: false),
        ColoredBox(
          color: surfaceColor,
          child: Padding(
            padding: EdgeInsets.all(DdtTheme.spacing.w),
            child: footer,
          ),
        ),
      ],
    );
  }
}

/// Applies [scrollPadding] to the panel [child] scroll view so content can
/// move under the header/footer fade overlays (outer padding would prevent that).
class _SidePanelInsetScrollChild extends StatelessWidget {
  const _SidePanelInsetScrollChild({
    required this.scrollPadding,
    required this.child,
  });

  final EdgeInsets scrollPadding;
  final Widget child;

  EdgeInsetsGeometry _mergedPadding(
    BuildContext context,
    EdgeInsetsGeometry? existing,
  ) {
    final direction = Directionality.of(context);
    final base = existing?.resolve(direction) ?? EdgeInsets.zero;
    return base.add(scrollPadding);
  }

  Widget _patch(BuildContext context, Widget widget) {
    if (widget is SingleChildScrollView) {
      return SingleChildScrollView(
        key: widget.key,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        padding: _mergedPadding(context, widget.padding),
        primary: widget.primary,
        physics: widget.physics,
        controller: widget.controller,
        clipBehavior: widget.clipBehavior,
        restorationId: widget.restorationId,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        child: widget.child,
      );
    }

    if (widget is ListView) {
      return ListView.custom(
        key: widget.key,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        controller: widget.controller,
        primary: widget.primary,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        padding: _mergedPadding(context, widget.padding),
        itemExtent: widget.itemExtent,
        prototypeItem: widget.prototypeItem,
        clipBehavior: widget.clipBehavior,
        childrenDelegate: widget.childrenDelegate,
      );
    }

    if (widget is Form) {
      return Form(
        key: widget.key,
        onChanged: widget.onChanged,
        onPopInvokedWithResult: widget.onPopInvokedWithResult,
        autovalidateMode: widget.autovalidateMode,
        child: _patch(context, widget.child),
      );
    }

    return Padding(padding: scrollPadding, child: widget);
  }

  @override
  Widget build(BuildContext context) {
    return _patch(context, child);
  }
}

import 'dart:async';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../theme/ddt_theme.dart';

/// Single action inside [DdtContextMenu].
class DdtContextMenuItem {
  const DdtContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool enabled;
}

enum DdtContextMenuPlacement {
  /// Opens below the anchor, centered horizontally.
  belowCenter,

  /// Opens below the anchor, left-aligned.
  belowStart,

  /// Opens below the anchor, right-aligned.
  belowEnd,

  /// Opens above the anchor, left-aligned.
  aboveStart,

  /// Opens above the anchor, right-aligned.
  aboveEnd,

  /// Opens to the right of the anchor, top-aligned.
  endTop,
}

/// Shows a glass-styled panel next to [anchorContext] or [anchorKey].
///
/// [childBuilder] receives a [dismiss] callback that animates the panel out
/// before removing the overlay entry.
Future<void> showDdtContextPanel({
  required BuildContext context,
  required Widget Function(Future<void> Function() dismiss) childBuilder,
  BuildContext? anchorContext,
  GlobalKey? anchorKey,
  DdtContextMenuPlacement placement = DdtContextMenuPlacement.belowCenter,
  Offset offset = Offset.zero,
}) {
  assert(
    anchorContext != null || anchorKey != null,
    'Either anchorContext or anchorKey must be provided.',
  );

  final anchor = anchorContext ?? anchorKey?.currentContext;
  if (anchor == null) return Future.value();

  final anchorRect = ddtContextMenuAnchorRect(
    context: context,
    anchorContext: anchor,
  );
  if (anchorRect == null) return Future.value();

  final overlayState = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => _DdtContextMenuOverlay(
      anchorRect: anchorRect,
      placement: placement,
      offset: offset,
      onDismiss: () => entry.remove(),
      childBuilder: childBuilder,
    ),
  );

  overlayState.insert(entry);
  return Future.value();
}

/// Shows a glass-styled context menu next to [anchorContext] or [anchorKey].
Future<void> showDdtContextMenu({
  required BuildContext context,
  required List<DdtContextMenuItem> items,
  BuildContext? anchorContext,
  GlobalKey? anchorKey,
  DdtContextMenuPlacement placement = DdtContextMenuPlacement.belowCenter,
  Offset offset = Offset.zero,
}) {
  return showDdtContextPanel(
    context: context,
    anchorContext: anchorContext,
    anchorKey: anchorKey,
    placement: placement,
    offset: offset,
    childBuilder: (dismiss) => DdtContextMenu(
      items: items,
      onItemSelected: () => unawaited(dismiss()),
    ),
  );
}

/// Anchor button bounds in the root overlay coordinate space.
Rect? ddtContextMenuAnchorRect({
  required BuildContext context,
  required BuildContext anchorContext,
}) {
  final anchorBox = anchorContext.findRenderObject() as RenderBox?;
  if (anchorBox == null || !anchorBox.hasSize) return null;

  final overlayBox = Overlay.of(context, rootOverlay: true)
      .context
      .findRenderObject() as RenderBox?;
  if (overlayBox == null || !overlayBox.hasSize) return null;

  final globalTopLeft = anchorBox.localToGlobal(Offset.zero);
  final globalBottomRight = anchorBox.localToGlobal(
    anchorBox.size.bottomRight(Offset.zero),
  );

  return Rect.fromPoints(
    overlayBox.globalToLocal(globalTopLeft),
    overlayBox.globalToLocal(globalBottomRight),
  );
}

/// Wraps [child] and opens [items] on tap, positioning the menu next to [child].
class DdtContextMenuTrigger extends StatelessWidget {
  const DdtContextMenuTrigger({
    super.key,
    required this.child,
    required this.items,
    this.placement = DdtContextMenuPlacement.belowCenter,
    this.offset = Offset.zero,
  });

  final Widget child;
  final List<DdtContextMenuItem> items;
  final DdtContextMenuPlacement placement;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchorContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showDdtContextMenu(
            context: context,
            anchorContext: anchorContext,
            items: items,
            placement: placement,
            offset: offset,
          ),
          child: child,
        );
      },
    );
  }
}

class DdtContextMenu extends StatelessWidget {
  const DdtContextMenu({
    super.key,
    required this.items,
    this.onItemSelected,
  });

  final List<DdtContextMenuItem> items;
  final VoidCallback? onItemSelected;

  static const double itemBorderRadius = 10;
  static const double menuMinWidth = 180;

  @override
  Widget build(BuildContext context) {
    return DdtTheme.contextMenuGlass(
      context: context,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: menuMinWidth.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: 2.h),
              _DdtContextMenuItemTile(
                item: items[i],
                onSelected: onItemSelected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DdtContextMenuOverlay extends StatefulWidget {
  const _DdtContextMenuOverlay({
    required this.anchorRect,
    required this.placement,
    required this.offset,
    required this.onDismiss,
    required this.childBuilder,
  });

  final Rect anchorRect;
  final DdtContextMenuPlacement placement;
  final Offset offset;
  final VoidCallback onDismiss;
  final Widget Function(Future<void> Function() dismiss) childBuilder;

  @override
  State<_DdtContextMenuOverlay> createState() => _DdtContextMenuOverlayState();
}

class _DdtContextMenuOverlayState extends State<_DdtContextMenuOverlay>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 220);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _animationDuration,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: DdtTheme.selectionAnimationCurve,
    reverseCurve: DdtTheme.selectionAnimationCurve,
  );
  late final Animation<double> _fadeAnimation = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(_animation);
  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 0.94,
    end: 1,
  ).animate(_animation);
  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: const Offset(0, -0.12),
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

  Future<void> _dismiss() async {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;

    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(_dismiss());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.paddingOf(context);

    final barrier = FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_dismiss()),
        child: const SizedBox.expand(),
      ),
    );

    final menu = FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: _scaleAlignment(widget.placement),
            child: Material(
            type: MaterialType.transparency,
            child: IntrinsicWidth(
              child: widget.childBuilder(_dismiss),
            ),
          ),
        ),
      ),
    );

    return IgnorePointer(
      ignoring: _isDismissing,
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            kIsWeb ? PointerInterceptor(child: barrier) : barrier,
            CustomSingleChildLayout(
              delegate: _DdtContextMenuLayoutDelegate(
                anchorRect: widget.anchorRect,
                placement: widget.placement,
                padding: viewPadding,
                offset: widget.offset,
              ),
              child: kIsWeb ? PointerInterceptor(child: menu) : menu,
            ),
          ],
        ),
      ),
    );
  }

  Alignment _scaleAlignment(DdtContextMenuPlacement placement) {
    return switch (placement) {
      DdtContextMenuPlacement.belowCenter => Alignment.topCenter,
      DdtContextMenuPlacement.belowStart => Alignment.topLeft,
      DdtContextMenuPlacement.belowEnd => Alignment.topRight,
      DdtContextMenuPlacement.aboveStart => Alignment.bottomLeft,
      DdtContextMenuPlacement.aboveEnd => Alignment.bottomRight,
      DdtContextMenuPlacement.endTop => Alignment.centerLeft,
    };
  }
}

class _DdtContextMenuLayoutDelegate extends SingleChildLayoutDelegate {
  _DdtContextMenuLayoutDelegate({
    required this.anchorRect,
    required this.placement,
    required this.padding,
    required this.offset,
  });

  final Rect anchorRect;
  final DdtContextMenuPlacement placement;
  final EdgeInsets padding;
  final Offset offset;

  static const _screenPadding = 8.0;
  static const _gap = 2.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest).deflate(
      padding + const EdgeInsets.all(_screenPadding),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var left = anchorRect.left + offset.dx;
    var top = anchorRect.top + offset.dy;

    switch (placement) {
      case DdtContextMenuPlacement.belowCenter:
        left = anchorRect.center.dx - childSize.width / 2;
        top = anchorRect.bottom + _gap;
      case DdtContextMenuPlacement.belowStart:
        top = anchorRect.bottom + _gap;
      case DdtContextMenuPlacement.belowEnd:
        left = anchorRect.right - childSize.width;
        top = anchorRect.bottom + _gap;
      case DdtContextMenuPlacement.aboveStart:
        top = anchorRect.top - childSize.height - _gap;
      case DdtContextMenuPlacement.aboveEnd:
        left = anchorRect.right - childSize.width;
        top = anchorRect.top - childSize.height - _gap;
      case DdtContextMenuPlacement.endTop:
        left = anchorRect.right + _gap;
        top = anchorRect.top;
    }

    left = left.clamp(
      _screenPadding + padding.left,
      size.width - childSize.width - _screenPadding - padding.right,
    );
    top = top.clamp(
      _screenPadding + padding.top,
      size.height - childSize.height - _screenPadding - padding.bottom,
    );

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _DdtContextMenuLayoutDelegate oldDelegate) {
    return anchorRect != oldDelegate.anchorRect ||
        placement != oldDelegate.placement ||
        padding != oldDelegate.padding ||
        offset != oldDelegate.offset;
  }
}

class _DdtContextMenuItemTile extends StatefulWidget {
  const _DdtContextMenuItemTile({
    required this.item,
    this.onSelected,
  });

  final DdtContextMenuItem item;
  final VoidCallback? onSelected;

  @override
  State<_DdtContextMenuItemTile> createState() =>
      _DdtContextMenuItemTileState();
}

class _DdtContextMenuItemTileState extends State<_DdtContextMenuItemTile> {
  bool _hovered = false;

  Color _backgroundColor(BuildContext context) {
    if (!widget.item.enabled || !_hovered) {
      return Colors.transparent;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08);
  }

  Color _foregroundColor(BuildContext context) {
    if (!widget.item.enabled) {
      return DdtTheme.taskCardTextSecondary(context).withValues(alpha: 0.45);
    }
    if (widget.item.isDestructive) {
      return AppColors.error;
    }
    return DdtTheme.taskCardTextPrimary(context);
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _foregroundColor(context);
    final iconColor = widget.item.isDestructive
        ? AppColors.error
        : DdtTheme.taskCardIconMuted(context);

    return MouseRegion(
      cursor: widget.item.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: widget.item.enabled
          ? (_) => setState(() => _hovered = true)
          : null,
      onExit: widget.item.enabled
          ? (_) => setState(() => _hovered = false)
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.item.enabled
            ? () {
                widget.onSelected?.call();
                widget.item.onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: _backgroundColor(context),
            borderRadius:
                BorderRadius.circular(DdtContextMenu.itemBorderRadius.r),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: 18.sp,
                color: widget.item.enabled ? iconColor : iconColor.withValues(
                  alpha: 0.45,
                ),
              ),
              SizedBox(width: 10.w),
              Flexible(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DdtTheme.style(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: foregroundColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

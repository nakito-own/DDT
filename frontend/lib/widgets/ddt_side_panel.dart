import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_theme.dart';

const Duration _kSidePanelDuration = Duration(milliseconds: 340);
const Curve _kSidePanelCurve = Curves.easeInOutCubic;

Future<T?> showDdtSidePanel<T>(
  BuildContext context, {
  required Widget child,
  double? maxWidth,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: _kSidePanelDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      final width = DdtTheme.sidePanelWidth(context, maxWidth: maxWidth);
      final height = DdtTheme.sidePanelHeight(context);

      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: DdtTheme.sidePanelInsets(context),
          child: SizedBox(
            width: width,
            height: height,
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, panel) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: _kSidePanelCurve,
        reverseCurve: _kSidePanelCurve,
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: curved,
            builder: (context, _) {
              final progress = curved.value;

              return GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 4 * progress,
                    sigmaY: 4 * progress,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.12 * progress),
                  ),
                ),
              );
            },
          ),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: panel,
          ),
        ],
      );
    },
  );
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
    final borderColor = DdtTheme.sidePanelDivider(context);

    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: DdtTheme.sidePanelTheme(context),
        child: DdtTheme.sidePanelGlass(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
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
                          fontSize: 18.sp,
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
                      icon: Icon(
                        CupertinoIcons.xmark,
                        size: 20.sp,
                        color: DdtTheme.sidePanelTextPrimary(context),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: borderColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: DdtTheme.spacing.w),
                  child: child,
                ),
              ),
              if (footer != null) ...[
                Divider(height: 1, thickness: 1, color: borderColor),
                Padding(
                  padding: EdgeInsets.all(DdtTheme.spacing.w),
                  child: footer!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

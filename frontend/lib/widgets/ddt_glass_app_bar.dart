import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/notifications/notifications_bloc.dart';
import '../models/app_notification.dart';
import '../models/user_profile.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import 'ddt_adaptive.dart';
import 'ddt_context_menu.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';

class DdtGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DdtGlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.center,
    this.leading,
    this.secondaryRow = false,
    this.compact = false,
    this.overlay = false,
  });

  final String title;
  final Widget? actions;

  /// Horizontally centered in the bar, above the title row.
  final Widget? center;

  /// Shown only on the compact shell, before the title.
  final Widget? leading;

  /// Phone layout: title and actions stay in one compact row even when
  /// [leading] is absent.
  final bool compact;

  /// Compact phone header without the glass bar. Sits on the top fade.
  final bool overlay;

  /// Moves [actions] and [center] onto a second, horizontally scrolling row.
  final bool secondaryRow;

  static const double barHeight = 56;

  /// Extra row under the title on the compact shell.
  static const double secondaryRowHeight = 48;

  /// Shared compact controls for section actions and trailing app bar icons.
  static const double actionIconLogicalSize = 16;
  static const double actionButtonLogicalSize = 32;

  static double actionIconSizeOf(BuildContext context) =>
      DdtTheme.shellSizeOf(context, actionIconLogicalSize);

  static BoxConstraints actionIconButtonConstraints(BuildContext context) =>
      BoxConstraints(
        minWidth: DdtTheme.shellSizeOf(context, actionButtonLogicalSize),
        minHeight: DdtTheme.shellSizeOf(context, actionButtonLogicalSize),
      );

  static EdgeInsets actionIconButtonPadding(BuildContext context) =>
      EdgeInsets.all(DdtTheme.shellSizeOf(context, 4));

  @override
  Size get preferredSize => Size.fromHeight(DdtTheme.shellSize(barHeight));

  @override
  Widget build(BuildContext context) {
    if (compact || secondaryRow || leading != null) {
      return _buildCompactBar(context);
    }

    final foregroundColor = DdtTheme.textPrimary(context);
    final height = DdtTheme.shellSizeOf(context, barHeight);
    final horizontalPadding = DdtTheme.shellSizeOf(context, 16);

    return DdtTheme.shellAppBarGlass(
      context: context,
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              SizedBox(width: horizontalPadding),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DdtTheme.style(
                  fontSize: DdtTypography.panelTitleSize,
                  fontWeight: FontWeight.w600,
                  color: foregroundColor,
                ),
              ),
              if (actions != null) ...[
                SizedBox(width: DdtTheme.shellSizeOf(context, 14)),
                Container(
                  width: 1,
                  height: DdtTheme.shellSizeOf(context, 18),
                  color: DdtTheme.borderSubtle(context),
                ),
                SizedBox(width: DdtTheme.shellSizeOf(context, 14)),
                actions!,
              ],
              const Spacer(),
              const _NotificationBellButton(),
              SizedBox(width: DdtTheme.shellSizeOf(context, 6)),
              const _UserEmailIsland(),
              SizedBox(width: DdtTheme.shellSizeOf(context, 10)),
            ],
          ),
          ?center,
        ],
      ),
    );
  }

  Widget _buildCompactBar(BuildContext context) {
    final foregroundColor = DdtTheme.textPrimary(context);
    final height = DdtTheme.shellSizeOf(context, barHeight);
    final secondary = secondaryRow
        ? DdtTheme.shellSizeOf(context, secondaryRowHeight)
        : 0.0;
    final sheets = DdtSectionSheetScope.maybeOf(context);
    final reading = DdtCompactBarScope.maybeOf(context)?.hasOverride ?? false;
    final showSheet = !reading && (sheets?.hasSheet ?? false);
    final leadingWidget = leading;
    final titleRow = Row(
      children: [
        if (leadingWidget != null)
          leadingWidget
        else
          SizedBox(width: DdtTheme.shellSizeOf(context, 16)),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: DdtTypography.panelTitleSize,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
          ),
        ),
        if (showSheet)
          IconButton(
            tooltip: sheets!.title,
            visualDensity: VisualDensity.compact,
            padding: actionIconButtonPadding(context),
            constraints: actionIconButtonConstraints(context),
            onPressed: () => sheets.open(context),
            icon: DdtIcon(
              sheets.icon,
              color: foregroundColor,
              size: actionIconSizeOf(context),
            ),
          ),
        const _NotificationBellButton(),
        SizedBox(width: DdtTheme.shellSizeOf(context, 4)),
        const _UserEmailIsland(),
        SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
      ],
    );
    final actionsRow = secondaryRow
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(
              left: DdtTheme.shellSizeOf(context, 8),
              right: DdtTheme.shellSizeOf(context, 8),
              bottom: DdtTheme.shellSizeOf(context, 6),
            ),
            child: Row(
              children: [
                ?center,
                if (center != null && actions != null)
                  SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
                ?actions,
              ],
            ),
          )
        : null;

    if (overlay) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: height, child: titleRow),
          if (actionsRow != null) SizedBox(height: secondary, child: actionsRow),
        ],
      );
    }

    return DdtTheme.shellAppBarGlass(
      context: context,
      height: height + secondary,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: barHeight.round(), child: titleRow),
          if (actionsRow != null)
            Expanded(flex: secondary.round(), child: actionsRow),
        ],
      ),
    );
  }
}

class _NotificationBellButton extends StatefulWidget {
  const _NotificationBellButton();

  @override
  State<_NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<_NotificationBellButton> {
  bool _hovered = false;

  void _openPanel(BuildContext anchorContext) {
    if (anchorContext.read<AuthBloc>().state is! AuthAuthenticated) {
      return;
    }

    showDdtContextPanel(
      context: anchorContext,
      anchorContext: anchorContext,
      placement: DdtContextMenuPlacement.belowEnd,
      offset: Offset(0, 4.h),
      childBuilder: (dismiss) => _NotificationsPanel(onDismiss: dismiss),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = _hovered
        ? DdtTheme.textPrimary(context)
        : DdtTheme.textSecondary(context);
    final bgColor = _hovered
        ? (isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFF1F5F9))
        : Colors.transparent;

    return BlocBuilder<NotificationsBloc, NotificationsState>(
      buildWhen: (previous, current) =>
          previous.unreadCount != current.unreadCount,
      builder: (context, state) {
        final unread = state.unreadCount;
        return Builder(
          builder: (anchorContext) {
            return MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: DdtTheme.inputControlBorderRadius,
                ),
                child: IconButton(
                  tooltip: 'Уведомления',
                  visualDensity: VisualDensity.compact,
                  padding: DdtGlassAppBar.actionIconButtonPadding(context),
                  constraints: DdtGlassAppBar.actionIconButtonConstraints(
                    context,
                  ),
                  onPressed: () => _openPanel(anchorContext),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    backgroundColor: DdtTheme.primaryColor,
                    textColor: Colors.white,
                    label: Text('$unread'),
                    child: DdtIcon(
                      DdtIcons.bell,
                      color: foregroundColor,
                      size: DdtGlassAppBar.actionIconSizeOf(context),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel({required this.onDismiss});

  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        final items = state.items;

        return DdtTheme.contextMenuGlass(
          context: context,
          padding: EdgeInsets.all(14.w),
          child: SizedBox(
            width: 360.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Уведомления',
                        style: DdtTheme.style(
                          fontSize: DdtTypography.bodyLargeSize,
                          fontWeight: FontWeight.w600,
                          color: DdtTheme.taskCardTextPrimary(context),
                        ),
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: () => context.read<NotificationsBloc>().add(
                          const NotificationsMarkAllReadRequested(),
                        ),
                        child: const Text('Прочитать все'),
                      ),
                  ],
                ),
                SizedBox(height: 6.h),
                Divider(height: 1, color: DdtTheme.borderSubtle(context)),
                SizedBox(height: 8.h),
                if (items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 28.h),
                    child: Text(
                      state.connected
                          ? 'Новых уведомлений пока нет'
                          : 'Подключение к серверу уведомлений...',
                      textAlign: TextAlign.center,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSize,
                        color: DdtTheme.taskCardTextSecondary(context),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 360.h),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 6.h),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _NotificationTile(
                          item: item,
                          onTap: () => context.read<NotificationsBloc>().add(
                            NotificationsMarkReadRequested(item.id),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  FaIconData get _icon {
    switch (item.category) {
      case AppNotificationCategory.newMail:
      case AppNotificationCategory.mailUpdated:
        return DdtIcons.mail;
      case AppNotificationCategory.calendarUpdated:
        return DdtIcons.calendar;
      case AppNotificationCategory.system:
        return DdtIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = DdtTheme.taskCardTextSecondary(context);
    final primary = DdtTheme.taskCardTextPrimary(context);
    final tileRadius = BorderRadius.circular(8.r);

    return Material(
      color: item.read
          ? Colors.transparent
          : DdtTheme.primaryColor.withValues(alpha: isDark ? 0.14 : 0.07),
      borderRadius: tileRadius,
      child: InkWell(
        borderRadius: tileRadius,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            borderRadius: tileRadius,
            border: Border.all(
              color: item.read
                  ? DdtTheme.borderSubtle(context)
                  : DdtTheme.primaryColor.withValues(
                      alpha: isDark ? 0.30 : 0.18,
                    ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: DdtTheme.primaryColor.withValues(
                    alpha: isDark ? 0.20 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                alignment: Alignment.center,
                child: DdtIcon(
                  _icon,
                  size: 13.sp,
                  color: isDark ? DdtTheme.accentColor : DdtTheme.primaryColor,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSize,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      item.body,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSmallSize,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserEmailIsland extends StatefulWidget {
  const _UserEmailIsland();

  @override
  State<_UserEmailIsland> createState() => _UserEmailIslandState();
}

class _UserEmailIslandState extends State<_UserEmailIsland> {
  bool _hovered = false;

  void _openProfilePanel(BuildContext anchorContext) {
    if (anchorContext.read<AuthBloc>().state is! AuthAuthenticated) return;

    showDdtContextPanel(
      context: context,
      anchorContext: anchorContext,
      placement: DdtContextMenuPlacement.belowEnd,
      offset: Offset(0, 4.h),
      childBuilder: (dismiss) => _UserProfileContextPanel(onDismiss: dismiss),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = DdtTheme.taskCardTextPrimary(context);
    final mutedColor = DdtTheme.taskCardTextSecondary(context);

    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) {
        final prevEmail = prev is AuthAuthenticated ? prev.user.email : null;
        final currEmail = curr is AuthAuthenticated ? curr.user.email : null;
        return (prev is AuthAuthenticated) != (curr is AuthAuthenticated) ||
            prevEmail != currEmail;
      },
      builder: (context, authState) {
        final email = authState is AuthAuthenticated
            ? authState.user.email
            : null;
        final isAuthenticated = authState is AuthAuthenticated;
        final bgColor = _hovered && isAuthenticated
            ? (isDark ? DdtTheme.darkWidget : const Color(0xFFF1F5F9))
            : (isDark ? DdtTheme.darkSurface : const Color(0xFFF8FAFC));
        final borderColor = _hovered && isAuthenticated
            ? DdtTheme.borderStrong(context)
            : DdtTheme.borderSubtle(context);

        return Builder(
          builder: (anchorContext) {
            return MouseRegion(
              cursor: isAuthenticated
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              onEnter: isAuthenticated
                  ? (_) => setState(() => _hovered = true)
                  : null,
              onExit: isAuthenticated
                  ? (_) => setState(() => _hovered = false)
                  : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isAuthenticated
                    ? () => _openProfilePanel(anchorContext)
                    : null,
                child: AnimatedContainer(
                  duration: DdtTheme.selectionAnimationDuration,
                  curve: DdtTheme.selectionAnimationCurve,
                  padding: EdgeInsets.symmetric(
                    horizontal: DdtTheme.shellSizeOf(context, 10),
                    vertical: DdtTheme.shellSizeOf(context, 5),
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: DdtTheme.inputControlBorderRadius,
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: DdtTheme.shellSizeOf(context, 20),
                        height: DdtTheme.shellSizeOf(context, 20),
                        decoration: BoxDecoration(
                          color: email != null
                              ? DdtTheme.primaryColor.withValues(
                                  alpha: isDark ? 0.22 : 0.12,
                                )
                              : DdtTheme.borderSubtle(context),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: DdtIcon(
                          DdtIcons.user,
                          size: DdtTheme.shellSizeOf(context, 10),
                          color: email != null
                              ? (isDark
                                    ? DdtTheme.accentColor
                                    : DdtTheme.primaryColor)
                              : mutedColor,
                        ),
                      ),
                      if (!DdtAdaptive.isCompact(context)) ...[
                        SizedBox(width: DdtTheme.shellSizeOf(context, 7)),
                        ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: DdtTheme.shellSizeOf(context, 220),
                        ),
                        child: Text(
                          email ?? 'Не авторизован',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DdtTheme.style(
                            fontSize: DdtTypography.labelSmallSize,
                            fontWeight: FontWeight.w500,
                            color: email != null ? textColor : mutedColor,
                          ),
                        ),
                      ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UserProfileContextPanel extends StatelessWidget {
  const _UserProfileContextPanel({required this.onDismiss});

  final Future<void> Function() onDismiss;

  static const double _menuMinWidth = 260;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final profile = authState is AuthAuthenticated ? authState.user : null;
        final connected = authState is AuthAuthenticated
            ? authState.connected
            : false;
        final isLoading = authState is AuthLoading;

        return DdtTheme.contextMenuGlass(
          context: context,
          padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: _menuMinWidth.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (profile == null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _ProfilePanelHeader(profile: profile),
                  SizedBox(height: 12.h),
                  Divider(height: 1, color: DdtTheme.borderSubtle(context)),
                  SizedBox(height: 10.h),
                  _ProfilePanelField(label: 'Email', value: profile.email),
                  if (profile.jobTitle != null)
                    _ProfilePanelField(
                      label: 'Должность',
                      value: profile.jobTitle!,
                    ),
                  if (profile.department != null)
                    _ProfilePanelField(
                      label: 'Отдел',
                      value: profile.department!,
                    ),
                  if (profile.phone != null)
                    _ProfilePanelField(label: 'Телефон', value: profile.phone!),
                  if (profile.officeLocation != null)
                    _ProfilePanelField(
                      label: 'Офис',
                      value: profile.officeLocation!,
                    ),
                  _ProfilePanelField(
                    label: 'Exchange',
                    value: connected ? 'Подключён' : 'Нет связи',
                  ),
                ],
                SizedBox(height: 6.h),
                Divider(height: 1, color: DdtTheme.borderSubtle(context)),
                SizedBox(height: 6.h),
                _ProfileLogoutButton(
                  isLoading: isLoading,
                  onPressed: isLoading
                      ? null
                      : () async {
                          await onDismiss();
                          if (!context.mounted) return;
                          context.read<AuthBloc>().add(
                            const AuthLogoutRequested(),
                          );
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfilePanelHeader extends StatelessWidget {
  const _ProfilePanelHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: DdtTheme.primaryColor.withValues(
              alpha: isDark ? 0.22 : 0.10,
            ),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: DdtTheme.primaryColor.withValues(
                alpha: isDark ? 0.35 : 0.20,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: DdtIcon(
            DdtIcons.user,
            size: 16.sp,
            color: isDark ? DdtTheme.accentColor : DdtTheme.primaryColor,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            profile.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodySize,
              fontWeight: FontWeight.w600,
              color: DdtTheme.taskCardTextPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePanelField extends StatelessWidget {
  const _ProfilePanelField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DdtTheme.style(
              fontSize: DdtTypography.captionSize,
              color: DdtTheme.textMuted(context),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              fontWeight: FontWeight.w500,
              color: DdtTheme.taskCardTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLogoutButton extends StatefulWidget {
  const _ProfileLogoutButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  State<_ProfileLogoutButton> createState() => _ProfileLogoutButtonState();
}

class _ProfileLogoutButtonState extends State<_ProfileLogoutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: enabled && _hovered
                ? DdtTheme.dangerColor.withValues(alpha: isDark ? 0.18 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              DdtContextMenu.itemBorderRadius.r,
            ),
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 18.sp,
                    height: 18.sp,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DdtTheme.dangerColor.withValues(alpha: 0.7),
                    ),
                  )
                : Text(
                    'Выйти',
                    style: DdtTheme.style(
                      fontSize: DdtTypography.labelSize,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? DdtTheme.dangerColor
                          : DdtTheme.dangerColor.withValues(alpha: 0.45),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

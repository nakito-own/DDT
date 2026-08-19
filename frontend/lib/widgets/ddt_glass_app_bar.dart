import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/notifications/notifications_bloc.dart';
import '../models/app_notification.dart';
import '../models/user_profile.dart';
import '../theme/ddt_theme.dart';
import 'ddt_context_menu.dart';

class DdtGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DdtGlassAppBar({super.key, required this.title, this.actions});

  final String title;
  final Widget? actions;

  static const double barHeight = 56;

  @override
  Size get preferredSize => Size.fromHeight(DdtTheme.shellSize(barHeight));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : AppColors.primary;
    final height = DdtTheme.shellSizeOf(context, barHeight);
    final horizontalPadding = DdtTheme.shellSizeOf(context, 16);

    return RepaintBoundary(
      child: DdtTheme.glass(
        context: context,
        height: height,
        width: double.infinity,
        child: Row(
          children: [
            SizedBox(width: horizontalPadding),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DdtTheme.style(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
            if (actions != null) ...[
              SizedBox(width: DdtTheme.shellSizeOf(context, 16)),
              actions!,
            ],
            const Spacer(),
            const _NotificationBellButton(),
            SizedBox(width: DdtTheme.shellSizeOf(context, 4)),
            const _UserEmailIsland(),
            SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
          ],
        ),
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton();

  void _openPanel(BuildContext anchorContext) {
    if (anchorContext.read<AuthBloc>().state is! AuthAuthenticated) {
      return;
    }

    showDdtContextPanel(
      context: anchorContext,
      anchorContext: anchorContext,
      placement: DdtContextMenuPlacement.belowEnd,
      offset: Offset(0, 2.h),
      childBuilder: (dismiss) => _NotificationsPanel(onDismiss: dismiss),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : AppColors.primary;

    return BlocBuilder<NotificationsBloc, NotificationsState>(
      buildWhen: (previous, current) =>
          previous.unreadCount != current.unreadCount,
      builder: (context, state) {
        final unread = state.unreadCount;
        return Builder(
          builder: (anchorContext) {
            return IconButton(
              tooltip: 'Уведомления',
              onPressed: () => _openPanel(anchorContext),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: Icon(
                  CupertinoIcons.bell,
                  color: foregroundColor,
                  size: DdtTheme.shellSizeOf(context, 24),
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
          padding: EdgeInsets.all(16.w),
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
                          fontSize: 15.sp,
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
                if (items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Text(
                      state.connected
                          ? 'Новых уведомлений пока нет'
                          : 'Подключение к серверу уведомлений...',
                      textAlign: TextAlign.center,
                      style: DdtTheme.style(
                        fontSize: 13.sp,
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
                          SizedBox(height: 8.h),
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

  IconData get _icon {
    switch (item.category) {
      case AppNotificationCategory.newMail:
      case AppNotificationCategory.mailUpdated:
        return CupertinoIcons.mail_solid;
      case AppNotificationCategory.calendarUpdated:
        return CupertinoIcons.calendar;
      case AppNotificationCategory.system:
        return CupertinoIcons.bell_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = DdtTheme.taskCardTextSecondary(context);
    final primary = DdtTheme.taskCardTextPrimary(context);

    return Material(
      color: item.read
          ? Colors.transparent
          : AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, size: 18.sp, color: AppColors.primary),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: DdtTheme.style(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      item.body,
                      style: DdtTheme.style(fontSize: 12.sp, color: muted),
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
  static const double _cornerRadius = 999;

  bool _hovered = false;

  void _openProfilePanel(BuildContext anchorContext) {
    if (anchorContext.read<AuthBloc>().state is! AuthAuthenticated) return;

    showDdtContextPanel(
      context: context,
      anchorContext: anchorContext,
      placement: DdtContextMenuPlacement.belowEnd,
      offset: Offset(0, 2.h),
      childBuilder: (dismiss) => _UserProfileContextPanel(onDismiss: dismiss),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: AnimatedOpacity(
                  duration: DdtTheme.selectionAnimationDuration,
                  opacity: _hovered && isAuthenticated ? 0.88 : 1,
                  child: DdtTheme.taskCardGlass(
                    context: context,
                    cornerRadius: _cornerRadius.r,
                    padding: EdgeInsets.symmetric(
                      horizontal: DdtTheme.shellSizeOf(context, 14),
                      vertical: DdtTheme.shellSizeOf(context, 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.person_crop_circle,
                          size: DdtTheme.shellSizeOf(context, 18),
                          color: email != null ? AppColors.primary : mutedColor,
                        ),
                        SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: DdtTheme.shellSizeOf(context, 220),
                          ),
                          child: Text(
                            email ?? 'Не авторизован',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DdtTheme.style(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: email != null ? textColor : mutedColor,
                            ),
                          ),
                        ),
                      ],
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
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 8.h),
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
                SizedBox(height: 8.h),
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
    return Row(
      children: [
        Icon(
          CupertinoIcons.person_crop_circle_fill,
          size: 36.sp,
          color: AppColors.primary,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            profile.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: 15.sp,
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
      padding: EdgeInsets.only(bottom: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DdtTheme.style(
              fontSize: 11.sp,
              color: DdtTheme.taskCardTextSecondary(context),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: 13.sp,
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
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: enabled && _hovered
                ? AppColors.error.withValues(alpha: isDark ? 0.18 : 0.1)
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
                      color: AppColors.error.withValues(alpha: 0.7),
                    ),
                  )
                : Text(
                    'Выйти',
                    style: DdtTheme.style(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? AppColors.error
                          : AppColors.error.withValues(alpha: 0.45),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

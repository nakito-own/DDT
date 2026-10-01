import 'dart:math' as math;

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/notifications/notifications_bloc.dart';
import '../blocs/theme/theme_bloc.dart';
import '../models/user_profile.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../theme/ddt_icons.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_switch.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _systemTheme = false;
  bool _notificationsMaster = false;
  bool _emailNotifications = true;
  bool _calendarNotifications = true;
  bool _spaceNotifications = true;
  bool _automationNotifications = false;

  static const _sectionGap = 12.0;
  static const _topSectionExtraInset = 20.0;
  static const _maxContentWidth = 1200.0;

  @override
  Widget build(BuildContext context) {
    final scrollPadding = DdtShellMetrics.scrollPadding(context);
    return DdtScrollEdgeFade(
      child: SingleChildScrollView(
        padding: scrollPadding.copyWith(
          top: scrollPadding.top + _topSectionExtraInset.h,
          bottom:
              DdtTheme.shellSizeOf(context, DdtTheme.spacing) +
              DdtScrollEdgeFade.listBottomPadding(context),
        ),
        child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : _maxContentWidth;
          final contentWidth = math.min(viewportWidth, _maxContentWidth);

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            _SettingsSection(
              title: 'Профиль пользователя',
              child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                if (authState is! AuthAuthenticated) {
                  return Text(
                    'Войдите через Exchange, чтобы увидеть профиль',
                    style: DdtTheme.style(fontSize: DdtTypography.bodySize),
                  );
                }

                final profile = authState.user;
                final isLoggingOut = authState is AuthLoading;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileHeader(
                      profile: profile,
                      isLoggingOut: isLoggingOut,
                      onLogout: isLoggingOut
                          ? null
                          : () => context.read<AuthBloc>().add(
                              const AuthLogoutRequested(),
                            ),
                    ),
                    SizedBox(height: 16.h),
                    _ProfileDetailsTable(
                      profile: profile,
                      exchangeConnected: authState.connected,
                    ),
                  ],
                );
              },
              ),
            ),
            SizedBox(height: _sectionGap.h),
            _SettingsSection(
              title: 'Внешний вид',
            child: BlocBuilder<ThemeBloc, ThemeState>(
              buildWhen: (previous, current) => previous.mode != current.mode,
              builder: (context, themeState) {
                return Column(
                  children: [
                    _SettingsSwitchTile(
                      label: 'Тёмный режим',
                      value: themeState.isDarkMode,
                      onChanged: _systemTheme
                          ? null
                          : (value) {
                              if (value != themeState.isDarkMode) {
                                context.read<ThemeBloc>().add(
                                  const ThemeToggleRequested(),
                                );
                              }
                            },
                      enabled: !_systemTheme,
                    ),
                    SizedBox(height: 8.h),
                    _SettingsSwitchTile(
                      label: 'Тема системы',
                      value: _systemTheme,
                      onChanged: (value) =>
                          setState(() => _systemTheme = value),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: _sectionGap.h),
          _SettingsSection(
            title: 'Уведомления',
            child: _NotificationsSection(
              notificationsMaster: _notificationsMaster,
              onNotificationsMasterChanged: (v) =>
                  setState(() => _notificationsMaster = v),
              emailNotifications: _emailNotifications,
              calendarNotifications: _calendarNotifications,
              spaceNotifications: _spaceNotifications,
              automationNotifications: _automationNotifications,
              onEmailChanged: (v) => setState(() => _emailNotifications = v),
              onCalendarChanged: (v) =>
                  setState(() => _calendarNotifications = v),
              onSpaceChanged: (v) => setState(() => _spaceNotifications = v),
              onAutomationChanged: (v) =>
                  setState(() => _automationNotifications = v),
            ),
          ),
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({
    required this.notificationsMaster,
    required this.onNotificationsMasterChanged,
    required this.emailNotifications,
    required this.calendarNotifications,
    required this.spaceNotifications,
    required this.automationNotifications,
    required this.onEmailChanged,
    required this.onCalendarChanged,
    required this.onSpaceChanged,
    required this.onAutomationChanged,
  });

  final bool notificationsMaster;
  final ValueChanged<bool> onNotificationsMasterChanged;
  final bool emailNotifications;
  final bool calendarNotifications;
  final bool spaceNotifications;
  final bool automationNotifications;
  final ValueChanged<bool> onEmailChanged;
  final ValueChanged<bool> onCalendarChanged;
  final ValueChanged<bool> onSpaceChanged;
  final ValueChanged<bool> onAutomationChanged;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return BlocBuilder<NotificationsBloc, NotificationsState>(
        buildWhen: (previous, current) =>
            previous.browserPermission != current.browserPermission,
        builder: (context, state) {
          final permission = state.browserPermission ?? 'default';
          final isGranted = permission == 'granted';
          final isDenied = permission == 'denied';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsSwitchTile(
                label: 'Допуск уведомлений',
                subtitle: isDenied
                    ? 'Разрешите уведомления в настройках браузера'
                    : null,
                value: isGranted,
                onChanged: isDenied
                    ? null
                    : (value) {
                        if (value && !isGranted) {
                          context.read<NotificationsBloc>().add(
                            const NotificationsBrowserPermissionRequested(),
                          );
                        }
                      },
                enabled: !isDenied,
              ),
              SizedBox(height: 12.h),
              _NotificationSubSwitches(
                masterEnabled: isGranted,
                emailNotifications: emailNotifications,
                calendarNotifications: calendarNotifications,
                spaceNotifications: spaceNotifications,
                automationNotifications: automationNotifications,
                onEmailChanged: onEmailChanged,
                onCalendarChanged: onCalendarChanged,
                onSpaceChanged: onSpaceChanged,
                onAutomationChanged: onAutomationChanged,
              ),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsSwitchTile(
          label: 'Допуск уведомлений',
          value: notificationsMaster,
          onChanged: onNotificationsMasterChanged,
        ),
        SizedBox(height: 12.h),
        _NotificationSubSwitches(
          masterEnabled: notificationsMaster,
          emailNotifications: emailNotifications,
          calendarNotifications: calendarNotifications,
          spaceNotifications: spaceNotifications,
          automationNotifications: automationNotifications,
          onEmailChanged: onEmailChanged,
          onCalendarChanged: onCalendarChanged,
          onSpaceChanged: onSpaceChanged,
          onAutomationChanged: onAutomationChanged,
        ),
      ],
    );
  }
}

class _NotificationSubSwitches extends StatelessWidget {
  const _NotificationSubSwitches({
    required this.masterEnabled,
    required this.emailNotifications,
    required this.calendarNotifications,
    required this.spaceNotifications,
    required this.automationNotifications,
    required this.onEmailChanged,
    required this.onCalendarChanged,
    required this.onSpaceChanged,
    required this.onAutomationChanged,
  });

  final bool masterEnabled;
  final bool emailNotifications;
  final bool calendarNotifications;
  final bool spaceNotifications;
  final bool automationNotifications;
  final ValueChanged<bool> onEmailChanged;
  final ValueChanged<bool> onCalendarChanged;
  final ValueChanged<bool> onSpaceChanged;
  final ValueChanged<bool> onAutomationChanged;

  @override
  Widget build(BuildContext context) {
    final dividerColor = DdtTheme.shellSurfaceBorderColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, thickness: 1, color: dividerColor),
        SizedBox(height: 12.h),
        _SettingsSwitchTile(
          label: 'Допуск уведомлений почты',
          value: emailNotifications,
          onChanged: masterEnabled ? onEmailChanged : null,
          enabled: masterEnabled,
        ),
        SizedBox(height: 8.h),
        _SettingsSwitchTile(
          label: 'Допуск уведомлений календаря',
          value: calendarNotifications,
          onChanged: masterEnabled ? onCalendarChanged : null,
          enabled: masterEnabled,
        ),
        SizedBox(height: 8.h),
        _SettingsSwitchTile(
          label: 'Допуск уведомлений пространства',
          value: spaceNotifications,
          onChanged: masterEnabled ? onSpaceChanged : null,
          enabled: masterEnabled,
        ),
        SizedBox(height: 8.h),
        _SettingsSwitchTile(
          label: 'Допуск уведомлений автоматизации',
          value: automationNotifications,
          onChanged: masterEnabled ? onAutomationChanged : null,
          enabled: masterEnabled,
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DdtTheme.style(
            fontSize: DdtTypography.panelTitleSize,
            fontWeight: FontWeight.w700,
            color: DdtTheme.taskCardTextPrimary(context),
          ),
        ),
        SizedBox(height: 12.h),
        DdtTheme.glass(
          context: context,
          padding: EdgeInsets.all(16.w),
          child: child,
        ),
      ],
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = Color.alphaBlend(
      AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.06),
      DdtTheme.shellSurfaceColor(context),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(DdtTheme.inputControlRadius.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    fontWeight: FontWeight.w500,
                    color: enabled
                        ? DdtTheme.taskCardTextPrimary(context)
                        : DdtTheme.taskCardTextSecondary(context),
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    subtitle!,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.labelSmallSize,
                      color: DdtTheme.taskCardTextSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          DdtSwitch(
            value: value,
            onChanged: onChanged,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final UserProfile profile;
  final bool isLoggingOut;
  final VoidCallback? onLogout;

  static const double _avatarSize = 52;

  @override
  Widget build(BuildContext context) {
    final nickname = profile.username?.trim();
    final department = profile.department?.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: _avatarSize.w,
          height: _avatarSize.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.1),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: isDark ? 0.38 : 0.28),
            ),
          ),
          child: Center(
            child: DdtIcon(
              DdtIcons.user,
              size: 22.sp,
              color: AppColors.primary,
            ),
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DdtTheme.style(
                  fontSize: DdtTypography.bodyLargeSize,
                  fontWeight: FontWeight.w600,
                  color: DdtTheme.taskCardTextPrimary(context),
                ),
              ),
              if (nickname != null && nickname.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  nickname.startsWith('@') ? nickname : '@$nickname',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSize,
                    color: DdtTheme.taskCardTextSecondary(context),
                  ),
                ),
              ],
              if (department != null && department.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  department,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSize,
                    color: AppColors.primary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 8.w),
        _ProfileLogoutIconButton(
          isLoading: isLoggingOut,
          onPressed: onLogout,
        ),
      ],
    );
  }
}

class _ProfileDetailsTable extends StatelessWidget {
  const _ProfileDetailsTable({
    required this.profile,
    required this.exchangeConnected,
  });

  final UserProfile profile;
  final bool exchangeConnected;

  @override
  Widget build(BuildContext context) {
    final rows = <_ProfileTableRowData>[
      _ProfileTableRowData(label: 'Email', value: profile.email),
      if (profile.jobTitle != null && profile.jobTitle!.trim().isNotEmpty)
        _ProfileTableRowData(label: 'Должность', value: profile.jobTitle!),
      if (profile.phone != null && profile.phone!.trim().isNotEmpty)
        _ProfileTableRowData(label: 'Телефон', value: profile.phone!),
      if (profile.officeLocation != null &&
          profile.officeLocation!.trim().isNotEmpty)
        _ProfileTableRowData(label: 'Офис', value: profile.officeLocation!),
      _ProfileTableRowData(
        label: 'Exchange',
        value: exchangeConnected ? 'Подключён' : 'Нет связи',
      ),
    ];

    final borderColor = DdtTheme.shellSurfaceBorderColor(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(DdtTheme.inputControlRadius.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DdtTheme.inputControlRadius.r),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: borderColor),
              _ProfileTableRow(data: rows[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileTableRowData {
  const _ProfileTableRowData({required this.label, required this.value});

  final String label;
  final String value;
}

class _ProfileTableRow extends StatelessWidget {
  const _ProfileTableRow({required this.data});

  final _ProfileTableRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(
              data.label,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSmallSize,
                color: DdtTheme.taskCardTextSecondary(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              data.value,
              style: DdtTheme.style(
                fontSize: DdtTypography.bodySize,
                fontWeight: FontWeight.w500,
                color: DdtTheme.taskCardTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLogoutIconButton extends StatefulWidget {
  const _ProfileLogoutIconButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  State<_ProfileLogoutIconButton> createState() =>
      _ProfileLogoutIconButtonState();
}

class _ProfileLogoutIconButtonState extends State<_ProfileLogoutIconButton> {
  bool _hovered = false;

  static const double _size = 34;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: 'Выйти',
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            width: _size.w,
            height: _size.w,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.error.withValues(
                      alpha: _hovered ? (isDark ? 0.22 : 0.14) : 0.08,
                    )
                  : AppColors.error.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.error.withValues(
                  alpha: enabled ? (_hovered ? 0.55 : 0.35) : 0.2,
                ),
              ),
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 14.sp,
                      height: 14.sp,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error.withValues(alpha: 0.85),
                      ),
                    )
                  : DdtIcon(
                      DdtIcons.signOut,
                      size: 15.sp,
                      color: AppColors.error.withValues(
                        alpha: enabled ? 0.92 : 0.45,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

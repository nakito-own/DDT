import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/notifications/notifications_bloc.dart';
import '../blocs/theme/theme_bloc.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _sectionGap = 12.0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsSection(
            title: 'Внешний вид',
            child: BlocBuilder<ThemeBloc, ThemeState>(
              buildWhen: (previous, current) =>
                  previous.isDarkMode != current.isDarkMode,
              builder: (context, themeState) {
                final isDark = themeState.isDarkMode;
                return _SettingsRow(
                  label: 'Тема оформления',
                  value: isDark ? 'Тёмная' : 'Светлая',
                  trailing: IconButton(
                    tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
                    icon: Icon(
                      isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                    onPressed: () => context.read<ThemeBloc>().add(
                      const ThemeToggleRequested(),
                    ),
                  ),
                );
              },
            ),
          ),
          if (kIsWeb) ...[
            SizedBox(height: _sectionGap.h),
            _SettingsSection(
              title: 'Уведомления',
              child: BlocBuilder<NotificationsBloc, NotificationsState>(
                buildWhen: (previous, current) =>
                    previous.browserPermission != current.browserPermission,
                builder: (context, state) {
                  final permission = state.browserPermission ?? 'default';
                  final isGranted = permission == 'granted';
                  final isDenied = permission == 'denied';

                  return _SettingsRow(
                    label: 'Push в браузере',
                    value: _browserPermissionLabel(permission),
                    subtitle: isDenied
                        ? 'Разрешите уведомления в настройках браузера'
                        : null,
                    trailing: isGranted
                        ? Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            color: AppColors.primary.withValues(alpha: 0.85),
                            size: 22.sp,
                          )
                        : TextButton(
                            onPressed: isDenied
                                ? null
                                : () => context.read<NotificationsBloc>().add(
                                    const NotificationsBrowserPermissionRequested(),
                                  ),
                            child: Text(isDenied ? 'Запрещено' : 'Разрешить'),
                          ),
                  );
                },
              ),
            ),
          ],
          SizedBox(height: _sectionGap.h),
          _SettingsSection(
            title: 'Профиль',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileRow(label: 'Имя', value: profile.label),
                    _ProfileRow(label: 'Email', value: profile.email),
                    if (profile.jobTitle != null)
                      _ProfileRow(label: 'Должность', value: profile.jobTitle!),
                    if (profile.department != null)
                      _ProfileRow(label: 'Отдел', value: profile.department!),
                    if (profile.phone != null)
                      _ProfileRow(label: 'Телефон', value: profile.phone!),
                    if (profile.officeLocation != null)
                      _ProfileRow(
                        label: 'Офис',
                        value: profile.officeLocation!,
                      ),
                    _ProfileRow(
                      label: 'Exchange',
                      value: authState.connected ? 'Подключён' : 'Нет связи',
                    ),
                    SizedBox(height: 16.h),
                    Button(
                      text: isLoggingOut ? 'Выход...' : 'Выйти',
                      onPressed: isLoggingOut
                          ? null
                          : () => context.read<AuthBloc>().add(
                              const AuthLogoutRequested(),
                            ),
                      type: ButtonType.outlined,
                      borderRadius: DdtTheme.radius,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _browserPermissionLabel(String permission) {
    return switch (permission) {
      'granted' => 'Разрешены',
      'denied' => 'Запрещены',
      _ => 'Не запрошены',
    };
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              fontWeight: FontWeight.w600,
              color: DdtTheme.taskCardTextPrimary(context),
            ),
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.value,
    required this.trailing,
    this.subtitle,
  });

  final String label;
  final String value;
  final Widget trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSmallSize,
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: DdtTheme.style(
                  fontSize: DdtTypography.bodySize,
                  fontWeight: FontWeight.w600,
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
        trailing,
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodySize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

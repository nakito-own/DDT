import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/theme/theme_bloc.dart';
import '../theme/ddt_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520.w),
        child: DdtTheme.glass(
          context: context,
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Настройки',
                style: DdtTheme.style(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 20.h),
              BlocBuilder<ThemeBloc, ThemeState>(
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
                      onPressed: () =>
                          context.read<ThemeBloc>().add(const ThemeToggleRequested()),
                    ),
                  );
                },
              ),
              SizedBox(height: 24.h),
              Text(
                'Профиль',
                style: DdtTheme.style(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 16.h),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  if (authState is! AuthAuthenticated) {
                    return Text(
                      'Войдите через Exchange, чтобы увидеть профиль',
                      style: DdtTheme.style(fontSize: 14.sp),
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
                        _ProfileRow(
                          label: 'Должность',
                          value: profile.jobTitle!,
                        ),
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
                        value:
                            authState.connected ? 'Подключён' : 'Нет связи',
                      ),
                      SizedBox(height: 16.h),
                      Button(
                        text: isLoggingOut ? 'Выход...' : 'Выйти',
                        onPressed: isLoggingOut
                            ? null
                            : () => context
                                .read<AuthBloc>()
                                .add(const AuthLogoutRequested()),
                        type: ButtonType.outlined,
                        borderRadius: DdtTheme.radius,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.value,
    required this.trailing,
  });

  final String label;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: DdtTheme.style(
                  fontSize: 12.sp,
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: DdtTheme.style(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              fontSize: 12.sp,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: DdtTheme.style(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

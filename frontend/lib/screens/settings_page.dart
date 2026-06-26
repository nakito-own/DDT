import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/ews_auth_controller.dart';
import '../theme/ddt_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<EwsAuthController>();

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
                'Профиль',
                style: DdtTheme.style(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 20.h),
              Obx(() {
                if (!auth.isAuthenticated) {
                  return Text(
                    'Войдите через Exchange, чтобы увидеть профиль',
                    style: DdtTheme.style(fontSize: 14.sp),
                  );
                }

                final profile = auth.user.value;
                if (profile == null) {
                  return const Center(child: CircularProgressIndicator());
                }

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
                      value: auth.connected.value ? 'Подключён' : 'Нет связи',
                    ),
                    SizedBox(height: 16.h),
                    Button(
                      text: auth.isLoading.value
                          ? 'Выход...'
                          : 'Выйти',
                      onPressed: auth.isLoading.value ? null : auth.logout,
                      type: ButtonType.outlined,
                      borderRadius: DdtTheme.radius,
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
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

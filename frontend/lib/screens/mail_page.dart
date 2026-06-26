import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/mail_controller.dart';
import '../models/mail_message.dart';
import '../theme/ddt_theme.dart';
import '../widgets/ddt_tappable.dart';
import '../widgets/compose_mail_panel.dart';
import '../widgets/ddt_glass_fab.dart';
import '../widgets/mail_body_view.dart';

class MailPage extends StatelessWidget {
  const MailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MailController());

    return Stack(
      children: [
        Obx(() {
          if (controller.isLoading.value && controller.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value != null &&
              controller.messages.isEmpty) {
            return _ErrorState(
              message: controller.errorMessage.value!,
              onRetry: controller.loadInbox,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadInbox,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: _MailList(controller: controller),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  flex: 7,
                  child: _MailDetail(controller: controller),
                ),
              ],
            ),
          );
        }),
        Positioned(
          right: 24.w,
          bottom: 24.h,
          child: DdtGlassFab(
            onPressed: () => showComposeMailPanel(context),
            icon: Icons.edit_outlined,
            label: 'Написать',
          ),
        ),
      ],
    );
  }
}

class _MailList extends StatelessWidget {
  const _MailList({required this.controller});

  final MailController controller;

  @override
  Widget build(BuildContext context) {
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final folders = controller.folders.value;
            final subtitle = folders == null
                ? 'Загрузка...'
                : 'Входящие: ${folders.inbox} · Отправленные: ${folders.sent}';
            return Text(
              subtitle,
              style: DdtTheme.style(
                fontSize: 13.sp,
                color: DdtTheme.taskCardTextSecondary(context),
              ),
            );
          }),
          SizedBox(height: 12.h),
          Expanded(
            child: Obx(() {
              final messages = controller.messages;
              final selectedId = controller.selectedMessageId.value;

              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'Входящие пусты',
                    style: DdtTheme.style(fontSize: 14.sp),
                  ),
                );
              }

              return ListView.separated(
                cacheExtent: 480,
                itemCount: messages.length,
                separatorBuilder: (_, __) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return MailListItem(
                    key: ValueKey(message.id),
                    message: message,
                    selected: message.id == selectedId,
                    onTap: () => controller.selectMessage(message),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _MailDetail extends StatelessWidget {
  const _MailDetail({required this.controller});

  final MailController controller;

  @override
  Widget build(BuildContext context) {
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(20.w),
      child: Obx(() {
        final messageId = controller.selectedMessageId.value;
        if (messageId == null) {
          return Center(
            child: Text(
              'Выберите письмо',
              style: DdtTheme.style(fontSize: 15.sp),
            ),
          );
        }

        final message = controller.selectedMessage.value;
        if (message == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MailDetailHeader(message: message),
            SizedBox(height: 20.h),
            Expanded(
              child: Obx(() {
                final body = message.body ?? '';
                final bodyType = message.bodyType;

                if (controller.isLoadingDetail.value && body.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final bodyView = MailBodyView(
                  key: ValueKey(messageId),
                  messageId: messageId,
                  body: body,
                  bodyType: bodyType,
                  fallback: message.preview,
                );

                if (bodyType == 'html') {
                  return bodyView;
                }

                return SingleChildScrollView(child: bodyView);
              }),
            ),
          ],
        );
      }),
    );
  }
}

class _MailDetailHeader extends StatelessWidget {
  const _MailDetailHeader({required this.message});

  final MailMessage message;

  static final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.subject,
          style: DdtTheme.style(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: DdtTheme.taskCardTextPrimary(context),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          'От: ${message.sender ?? '—'}',
          style: DdtTheme.style(fontSize: 14.sp),
        ),
        if (message.datetimeReceived != null)
          Text(
            _dateFormat.format(message.datetimeReceived!.toLocal()),
            style: DdtTheme.style(
              fontSize: 13.sp,
              color: DdtTheme.taskCardTextSecondary(context),
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: DdtTheme.style(fontSize: 14.sp)),
          SizedBox(height: 12.h),
          Button(
            text: 'Повторить',
            onPressed: onRetry,
            borderRadius: DdtTheme.radius,
          ),
        ],
      ),
    );
  }
}

class MailListItem extends StatelessWidget {
  const MailListItem({
    super.key,
    required this.message,
    required this.selected,
    required this.onTap,
  });

  final MailMessage message;
  final bool selected;
  final VoidCallback onTap;

  static final _dateFormat = DateFormat('dd.MM HH:mm');

  @override
  Widget build(BuildContext context) {
    final isUnread = !message.isRead;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final borderRadius = DdtTheme.radius;

    final Color backgroundColor;
    final Color borderColor;
    final double borderWidth;

    if (selected) {
      backgroundColor = AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.14);
      borderColor = AppColors.primary;
      borderWidth = 2;
    } else if (isUnread) {
      backgroundColor = AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.06);
      borderColor = AppColors.primary.withValues(alpha: 0.55);
      borderWidth = 1.5;
    } else {
      backgroundColor = Colors.transparent;
      borderColor =
          DdtTheme.glassBorderColor(brightness).withValues(alpha: 0.12);
      borderWidth = 1;
    }

    return RepaintBoundary(
      child: DdtTappable(
        onTap: onTap,
        borderRadius: borderRadius,
        backgroundColor: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        child: Stack(
          children: [
            if (isUnread && !selected)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4.w,
                  color: AppColors.primary,
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isUnread && !selected ? 16.w : 12.w,
                12.h,
                12.w,
                12.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isUnread && !selected)
                        Padding(
                          padding: EdgeInsets.only(top: 5.h, right: 8.w),
                          child: Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          message.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DdtTheme.style(
                            fontSize: 14.sp,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? AppColors.primary
                                : DdtTheme.taskCardTextPrimary(context),
                          ),
                        ),
                      ),
                      if (message.datetimeReceived != null)
                        Text(
                          _dateFormat.format(
                            message.datetimeReceived!.toLocal(),
                          ),
                          style: DdtTheme.style(
                            fontSize: 12.sp,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: DdtTheme.taskCardTextSecondary(
                              context,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    message.sender ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DdtTheme.style(
                      fontSize: 12.sp,
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: DdtTheme.taskCardTextSecondary(context),
                    ),
                  ),
                  if (message.preview.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      message.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: 12.sp,
                        color: isUnread
                            ? DdtTheme.taskCardTextPrimary(context)
                                .withValues(alpha: 0.85)
                            : DdtTheme.taskCardTextSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

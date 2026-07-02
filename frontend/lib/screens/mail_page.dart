import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../blocs/mail/mail_bloc.dart';
import '../models/mail_message.dart';
import '../theme/ddt_theme.dart';
import '../widgets/compose_mail_panel.dart';
import '../widgets/ddt_glass_fab.dart';
import '../widgets/ddt_tappable.dart';
import '../widgets/mail_body_view.dart';

class MailPage extends StatefulWidget {
  const MailPage({super.key});

  @override
  State<MailPage> createState() => _MailPageState();
}

class _MailPageState extends State<MailPage> {
  @override
  void initState() {
    super.initState();
    // MailBloc уже создан в main.dart; запрашиваем загрузку входящих.
    context.read<MailBloc>().add(const MailInboxLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
          children: [
            BlocBuilder<MailBloc, MailState>(
              buildWhen: (previous, current) =>
                  previous.isLoading != current.isLoading ||
                  previous.errorMessage != current.errorMessage ||
                  previous.messages.isEmpty != current.messages.isEmpty,
              builder: (context, state) {
                if (state.isLoading && state.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.errorMessage != null && state.messages.isEmpty) {
                  return _ErrorState(
                    message: state.errorMessage!,
                    onRetry: () => context
                        .read<MailBloc>()
                        .add(const MailInboxLoadRequested()),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => context
                      .read<MailBloc>()
                      .add(const MailInboxRefreshRequested()),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: const _MailList()),
                      SizedBox(width: 16.w),
                      Expanded(flex: 7, child: const _MailDetail()),
                    ],
                  ),
                );
              },
            ),
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
  const _MailList();

  @override
  Widget build(BuildContext context) {
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocBuilder<MailBloc, MailState>(
            buildWhen: (previous, current) =>
                previous.folders != current.folders,
            builder: (context, state) {
              final folders = state.folders;
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
            },
          ),
          SizedBox(height: 12.h),
          Expanded(
            child: BlocBuilder<MailBloc, MailState>(
              buildWhen: (previous, current) =>
                  previous.messages != current.messages ||
                  previous.selectedMessage?.id !=
                      current.selectedMessage?.id,
              builder: (context, state) {
                final messages = state.messages;
                final selectedId = state.selectedMessage?.id;

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
                      onTap: () => context
                          .read<MailBloc>()
                          .add(MailMessageSelected(message)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MailDetail extends StatelessWidget {
  const _MailDetail();

  @override
  Widget build(BuildContext context) {
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(20.w),
      child: BlocBuilder<MailBloc, MailState>(
        buildWhen: (previous, current) =>
            previous.selectedMessage != current.selectedMessage ||
            previous.isLoadingDetail != current.isLoadingDetail,
        builder: (context, state) {
          final message = state.selectedMessage;
          if (message == null) {
            return Center(
              child: Text(
                'Выберите письмо',
                style: DdtTheme.style(fontSize: 15.sp),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MailDetailHeader(message: message),
              SizedBox(height: 20.h),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final body = message.body ?? '';
                    final bodyType = message.bodyType;

                    if (state.isLoadingDetail && body.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final bodyView = MailBodyView(
                      key: ValueKey(message.id),
                      messageId: message.id,
                      body: body,
                      bodyType: bodyType,
                      fallback: message.preview,
                    );

                    if (bodyType == 'html') {
                      return bodyView;
                    }

                    return SingleChildScrollView(child: bodyView);
                  },
                ),
              ),
            ],
          );
        },
      ),
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
  final VoidCallback onRetry;

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
      backgroundColor =
          AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.14);
      borderColor = AppColors.primary;
      borderWidth = 2;
    } else if (isUnread) {
      backgroundColor =
          AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.06);
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
                          _dateFormat
                              .format(message.datetimeReceived!.toLocal()),
                          style: DdtTheme.style(
                            fontSize: 12.sp,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: DdtTheme.taskCardTextSecondary(context),
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
                      fontWeight:
                          isUnread ? FontWeight.w600 : FontWeight.w400,
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

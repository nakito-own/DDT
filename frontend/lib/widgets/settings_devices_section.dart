import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../models/app_session_device.dart';
import '../services/ews_api.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/ddt_toast.dart';
import 'ddt_icon.dart';

class SettingsDevicesSection extends StatefulWidget {
  const SettingsDevicesSection({super.key, this.api});

  final EwsApi? api;

  @override
  State<SettingsDevicesSection> createState() => _SettingsDevicesSectionState();
}

class _SettingsDevicesSectionState extends State<SettingsDevicesSection> {
  static final _loggedInFormat = DateFormat('dd.MM.yyyy HH:mm');

  late final EwsApi _api = widget.api ?? ewsApi;
  List<AppSessionDevice> _sessions = const [];
  bool _loading = true;
  String? _error;
  int? _revokingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _api.loadSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _revoke(AppSessionDevice session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить сессию?'),
        content: Text(
          'Устройство «${session.deviceName ?? 'Неизвестно'}» выйдет из аккаунта.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _revokingId = session.id);
    try {
      await _api.revokeSession(session.id);
      if (!mounted) return;
      setState(() {
        _sessions = [
          for (final item in _sessions)
            if (item.id != session.id) item,
        ];
        _revokingId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _revokingId = null);
      DdtToast.show(
        message: error.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null && _sessions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error!,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodySize,
              color: DdtTheme.taskCardTextSecondary(context),
            ),
          ),
          SizedBox(height: 8.h),
          TextButton(onPressed: _load, child: const Text('Повторить')),
        ],
      );
    }

    if (_sessions.isEmpty) {
      return Text(
        'Нет активных сессий',
        style: DdtTheme.style(
          fontSize: DdtTypography.bodySize,
          color: DdtTheme.taskCardTextSecondary(context),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _sessions.length; i++) ...[
          if (i > 0) SizedBox(height: 8.h),
          _DeviceTile(
            session: _sessions[i],
            loggedInLabel: _loggedInFormat.format(
              _sessions[i].loggedInAt.toLocal(),
            ),
            revoking: _revokingId == _sessions[i].id,
            onRevoke: _sessions[i].isCurrent || _revokingId != null
                ? null
                : () => _revoke(_sessions[i]),
          ),
        ],
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.session,
    required this.loggedInLabel,
    required this.revoking,
    required this.onRevoke,
  });

  final AppSessionDevice session;
  final String loggedInLabel;
  final bool revoking;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final name = session.deviceName ?? 'Неизвестно';
    final os = session.osName ?? 'Неизвестно';
    final country = session.ipCountry ?? 'Неизвестно';
    final icon = _isMobile(name, os) ? DdtIcons.mobile : DdtIcons.laptop;

    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 8.w, 12.h),
      decoration: BoxDecoration(
        color: DdtTheme.inputFillColor(context),
        borderRadius: DdtTheme.inputControlBorderRadius,
        border: Border.all(color: DdtTheme.borderSubtle(context), width: 1),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DdtIcon(
                icon,
                size: 32.sp,
                color: DdtTheme.taskCardTextSecondary(context),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: session.isCurrent ? 8.w : 28.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: DdtTheme.style(
                          fontSize: DdtTypography.bodySize,
                          fontWeight: FontWeight.w600,
                          color: DdtTheme.taskCardTextPrimary(context),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$os · $country',
                        style: DdtTheme.style(
                          fontSize: DdtTypography.labelSmallSize,
                          color: DdtTheme.taskCardTextSecondary(context),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Вход $loggedInLabel',
                        style: DdtTheme.style(
                          fontSize: DdtTypography.labelSmallSize,
                          color: DdtTheme.taskCardTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (session.isCurrent)
                Text(
                  'Это устройство',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSmallSize,
                    fontWeight: FontWeight.w600,
                    color: DdtTheme.primaryColor,
                  ),
                ),
            ],
          ),
          if (!session.isCurrent)
            Positioned(
              top: 0,
              right: 0,
              child: revoking
                  ? SizedBox(
                      width: 28.w,
                      height: 28.w,
                      child: Center(
                        child: SizedBox(
                          width: 14.sp,
                          height: 14.sp,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DdtTheme.dangerColor,
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Завершить сессию',
                      onPressed: onRevoke,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: 28.w,
                        height: 28.w,
                      ),
                      icon: DdtIcon(
                        DdtIcons.trash,
                        size: 15.sp,
                        color: DdtTheme.dangerColor,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  bool _isMobile(String name, String os) {
    final label = '$name $os'.toLowerCase();
    return label.contains('iphone') ||
        label.contains('ipad') ||
        label.contains('ios') ||
        label.contains('android');
  }
}

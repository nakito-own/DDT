import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/tasks_api.dart';

import '../models/queue_settings.dart';
import '../models/user_profile.dart';
import '../services/directory_users.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_app_input.dart';
import '../widgets/ddt_filter_dropdown.dart';
import '../widgets/ddt_switch.dart';

class TaskQueueRulesLoader extends StatefulWidget {
  const TaskQueueRulesLoader({
    super.key,
    required this.spaceKey,
    required this.fieldValues,
    required this.componentIds,
    required this.notifications,
    required this.onFieldValues,
    required this.onComponentIds,
    required this.onNotifications,
    this.onQueue,
    this.showNotifications = true,
  });

  final String? spaceKey;
  final List<TaskFieldValue> fieldValues;
  final List<int> componentIds;
  final TaskNotifications notifications;
  final ValueChanged<List<TaskFieldValue>> onFieldValues;
  final ValueChanged<List<int>> onComponentIds;
  final ValueChanged<TaskNotifications> onNotifications;
  final ValueChanged<QueueSettings>? onQueue;
  final bool showNotifications;

  @override
  State<TaskQueueRulesLoader> createState() => _TaskQueueRulesLoaderState();
}

class _TaskQueueRulesLoaderState extends State<TaskQueueRulesLoader> {
  QueueSettings? _queue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TaskQueueRulesLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceKey != widget.spaceKey) _load();
  }

  Future<void> _load() async {
    try {
      final queue = await TasksApi(spaceKey: widget.spaceKey).fetchQueueSettings();
      if (!mounted) return;
      setState(() => _queue = queue);
      widget.onQueue?.call(queue);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    if (queue == null) return const SizedBox.shrink();
    return TaskQueueRulesEditor(
      queue: queue,
      fieldValues: widget.fieldValues,
      componentIds: widget.componentIds,
      notifications: widget.notifications,
      showNotifications: widget.showNotifications,
      onFieldValues: widget.onFieldValues,
      onComponentIds: widget.onComponentIds,
      onNotifications: widget.onNotifications,
    );
  }
}

class TaskQueueRulesEditor extends StatelessWidget {
  const TaskQueueRulesEditor({
    super.key,
    required this.queue,
    required this.fieldValues,
    required this.componentIds,
    required this.notifications,
    this.showNotifications = true,
    required this.onFieldValues,
    required this.onComponentIds,
    required this.onNotifications,
  });

  final QueueSettings queue;
  final List<TaskFieldValue> fieldValues;
  final List<int> componentIds;
  final TaskNotifications notifications;
  final bool showNotifications;
  final ValueChanged<List<TaskFieldValue>> onFieldValues;
  final ValueChanged<List<int>> onComponentIds;
  final ValueChanged<TaskNotifications> onNotifications;

  TaskFieldValue _valueFor(QueueField field) {
    for (final value in fieldValues) {
      if (value.fieldId == field.id) return value;
    }
    return field.toValue();
  }

  void _setValue(QueueField field, Object? value) {
    final next = [
      for (final item in fieldValues)
        if (item.fieldId != field.id) item,
      TaskFieldValue(
        fieldId: field.id ?? 0,
        name: field.name,
        fieldType: field.fieldType,
        listMultiple: field.listMultiple,
        options: field.options,
        value: value,
      ),
    ];
    onFieldValues(next);
  }

  @override
  Widget build(BuildContext context) {
    if (queue.fields.isEmpty && queue.components.isEmpty) {
      return showNotifications ? _notifications(context) : const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (queue.fields.isNotEmpty) ...[
          Text(
            'Поля',
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              fontWeight: FontWeight.w600,
              color: DdtTheme.sidePanelTextMuted(context),
            ),
          ),
          SizedBox(height: 8.h),
          for (final field in queue.fields)
            if (field.id != null)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _FieldInput(
                  field: field,
                  value: _valueFor(field).value,
                  onChanged: (value) => _setValue(field, value),
                ),
              ),
        ],
        if (queue.components.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Text(
            'Компоненты',
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              fontWeight: FontWeight.w600,
              color: DdtTheme.sidePanelTextMuted(context),
            ),
          ),
          SizedBox(height: 8.h),
          DdtSearchableFilterDropdown(
            summary: _componentSummary(),
            active: componentIds.isNotEmpty,
            multi: true,
            options: [
              for (final component in queue.components)
                if (component.id != null)
                  DdtFilterOption(
                    key: '${component.id}',
                    label: component.name,
                  ),
            ],
            selected: {for (final id in componentIds) '$id'},
            onSelected: (key) {
              final id = int.tryParse(key);
              if (id == null) return;
              final next = [...componentIds];
              if (next.contains(id)) {
                next.remove(id);
              } else {
                next.add(id);
              }
              onComponentIds(next);
            },
          ),
        ],
        if (showNotifications) ...[
          SizedBox(height: 12.h),
          _notifications(context),
        ],
      ],
    );
  }

  String _componentSummary() {
    final names = [
      for (final component in queue.components)
        if (component.id != null && componentIds.contains(component.id))
          component.name,
    ];
    if (names.isEmpty) return 'Не выбраны';
    return names.join(', ');
  }

  Widget _notifications(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Уведомления',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
        ),
        _Flag(
          label: 'Назначение',
          value: notifications.notifyAssigned,
          onChanged: (value) => onNotifications(
            notifications.copyWith(notifyAssigned: value),
          ),
        ),
        _Flag(
          label: 'Изменение',
          value: notifications.notifyUpdated,
          onChanged: (value) => onNotifications(
            notifications.copyWith(notifyUpdated: value),
          ),
        ),
        _Flag(
          label: 'Комментарий',
          value: notifications.notifyComment,
          onChanged: (value) => onNotifications(
            notifications.copyWith(notifyComment: value),
          ),
        ),
        _Flag(
          label: 'Удаление',
          value: notifications.notifyDeleted,
          onChanged: (value) => onNotifications(
            notifications.copyWith(notifyDeleted: value),
          ),
        ),
        DdtAppInput(
          initialValue: notifications.deadlineReminderHours?.toString() ?? '',
          label: 'Напоминание, часов до дедлайна',
          onChanged: (value) {
            final hours = int.tryParse(value.trim());
            onNotifications(
              notifications.copyWith(
                deadlineReminderHours: hours,
                clearReminder: value.trim().isEmpty,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DdtSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final QueueField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (field.fieldType) {
      case 'checkbox':
        return _Flag(
          label: field.name,
          value: value == true,
          onChanged: onChanged,
        );
      case 'list':
        final raw = value;
        final selected = raw is List
            ? raw.map((item) => item.toString()).toSet()
            : <String>{
                if (raw != null && '$raw'.isNotEmpty) raw.toString(),
              };
        final summary = selected.isEmpty ? 'Не выбрано' : selected.join(', ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.name,
              style: DdtTheme.style(color: DdtTheme.textSecondary(context)),
            ),
            SizedBox(height: 6.h),
            DdtSearchableFilterDropdown(
              summary: summary,
              active: selected.isNotEmpty,
              multi: field.listMultiple,
              options: [
                for (final option in field.options)
                  DdtFilterOption(key: option, label: option),
              ],
              selected: selected,
              onSelected: (key) {
                if (field.listMultiple) {
                  final next = {...selected};
                  if (!next.add(key)) next.remove(key);
                  onChanged(next.toList());
                } else {
                  onChanged(selected.contains(key) ? null : key);
                }
              },
            ),
          ],
        );
      case 'user':
        return FutureBuilder<List<UserProfile>>(
          future: loadDirectoryUsers(),
          builder: (context, snapshot) {
            final users = snapshot.data ?? const <UserProfile>[];
            final current = int.tryParse('${value ?? ''}');
            UserProfile? selectedUser;
            for (final user in users) {
              if (user.id == current) selectedUser = user;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.name,
                  style: DdtTheme.style(color: DdtTheme.textSecondary(context)),
                ),
                SizedBox(height: 6.h),
                DdtSearchableFilterDropdown(
                  summary: selectedUser?.label ?? 'Не выбран',
                  active: selectedUser != null,
                  multi: false,
                  options: [
                    for (final user in users)
                      DdtFilterOption(key: '${user.id}', label: user.label),
                  ],
                  selected: {if (current != null) '$current'},
                  onSelected: (key) => onChanged(int.tryParse(key)),
                ),
              ],
            );
          },
        );
      default:
        return DdtAppInput(
          label: field.name,
          initialValue: value?.toString() ?? '',
          onChanged: (text) {
            if (field.fieldType == 'number') {
              onChanged(num.tryParse(text.replaceAll(',', '.')));
              return;
            }
            onChanged(text);
          },
        );
    }
  }

}

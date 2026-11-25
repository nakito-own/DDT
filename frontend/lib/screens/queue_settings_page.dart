import 'dart:math' as math;

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/queue_settings.dart';
import '../models/task_priority.dart';
import '../models/task_status.dart';
import '../models/task_type.dart';
import '../router/route_paths.dart';
import '../services/tasks_api.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/ddt_toast.dart';
import '../theme/ddt_icons.dart';
import '../widgets/ddt_app_input.dart';
import '../widgets/ddt_checkbox.dart';
import '../widgets/ddt_filter_dropdown.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_switch.dart';

class QueueSettingsPage extends StatefulWidget {
  const QueueSettingsPage({super.key});

  @override
  State<QueueSettingsPage> createState() => _QueueSettingsPageState();
}

class _QueueSettingsPageState extends State<QueueSettingsPage> {
  QueueSettings? _settings;
  String? _error;
  var _loading = true;
  var _saving = false;

  final _deadlineController = TextEditingController();
  final _reminderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deadlineController.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  TasksApi get _api =>
      TasksApi(spaceKey: context.read<TasksBloc>().spaceKey);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _api.fetchQueueSettings();
      if (!mounted) return;
      _deadlineController.text = settings.defaultDeadlineDays?.toString() ?? '';
      _reminderController.text =
          settings.deadlineReminderHours?.toString() ?? '';
      setState(() {
        _settings = settings;
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

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null || _saving) return;
    final deadlineText = _deadlineController.text.trim();
    final reminderText = _reminderController.text.trim();
    final deadline = deadlineText.isEmpty ? null : int.tryParse(deadlineText);
    final reminder = reminderText.isEmpty ? null : int.tryParse(reminderText);
    if (deadlineText.isNotEmpty && deadline == null) {
      DdtToast.show(message: 'Дедлайн по умолчанию — число дней', type: ToastType.warning);
      return;
    }
    if (reminderText.isNotEmpty && (reminder == null || reminder < 1)) {
      DdtToast.show(
        message: 'Напоминание задаётся в часах, от 1',
        type: ToastType.warning,
      );
      return;
    }
    final defaultType = settings.types.cast<TaskType?>().firstWhere(
      (type) => type!.id == settings.defaultTypeId || type.name == settings.defaultTypeName,
      orElse: () => settings.types.isEmpty ? null : settings.types.first,
    );
    if (defaultType == null) {
      DdtToast.show(message: 'Добавьте тип задачи', type: ToastType.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.saveQueueSettings(
        settings.copyWith(
          defaultTypeName: defaultType.name,
          defaultTypeId: defaultType.id == 0 ? null : defaultType.id,
          defaultDeadlineDays: deadline,
          clearDeadline: deadline == null,
          deadlineReminderHours: reminder,
          clearReminder: reminder == null,
          defaultComponentIds: [
            for (final item in settings.components)
              if (item.isDefault && item.id != null) item.id!,
          ],
        ),
      );
      if (!mounted) return;
      context.read<TasksBloc>().add(const TasksBoardLoadRequested());
      DdtToast.show(message: 'Настройки очереди сохранены', type: ToastType.success);
      _close();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      DdtToast.show(
        message: error.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }

  void _update(QueueSettings next) => setState(() => _settings = next);

  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final spaceKey = context.read<TasksBloc>().spaceKey;
    context.go(
      spaceKey == null || spaceKey.isEmpty
          ? RoutePaths.tasksList
          : RoutePaths.spaceListFor(spaceKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = DdtShellMetrics.scrollPadding(context);
    final showSave = !_loading && _error == null && _settings != null;
    return Stack(
      children: [
        DdtScrollEdgeFade(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: padding.copyWith(
                    top: padding.top + 20.h,
                    bottom: padding.bottom + (showSave ? 84.h : 0),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: _settings == null
                          ? const SizedBox.shrink()
                          : _editor(context, _settings!),
                    ),
                  ),
                ),
        ),
        if (showSave)
          Positioned(
            right: 24.w,
            bottom: DdtShellMetrics.contentBottomPadding(context) + 16.h,
            child: _FloatingSaveButton(saving: _saving, onPressed: _save),
          ),
      ],
    );
  }

  Widget _editor(BuildContext context, QueueSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Настройки очереди',
          style: DdtTheme.style(
            fontSize: DdtTypography.sectionTitleSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'Правила подставляются в новые задачи. Уведомления можно изменить на самой задаче.',
          style: DdtTheme.style(color: DdtTheme.textSecondary(context)),
        ),
        SizedBox(height: 18.h),
        _Section(
          title: 'Статусы',
          child: Column(
            children: [
              for (final status in settings.statuses)
                _StatusRow(
                  status: status,
                  isDefault: status.value == settings.defaultStatusKey,
                  onDefault: () => _update(
                    settings.copyWith(defaultStatusKey: status.value),
                  ),
                  onChanged: (next) => _update(
                    settings.copyWith(
                      statuses: [
                        for (final item in settings.statuses)
                          item == status ? next : item,
                      ],
                    ),
                  ),
                  onDelete: status.value == 'todo' ||
                          status.value == 'in_progress' ||
                          status.value == 'done'
                      ? null
                      : () => _update(
                          settings.copyWith(
                            statuses: [
                              for (final item in settings.statuses)
                                if (item != status) item,
                            ],
                            defaultStatusKey:
                                settings.defaultStatusKey == status.value
                                ? TaskStatus.todo.value
                                : settings.defaultStatusKey,
                          ),
                        ),
                ),
              _AddButton(
                label: 'Добавить статус',
                onPressed: () => _update(
                    settings.copyWith(
                      statuses: [
                        ...settings.statuses,
                        TaskStatus(
                          'status_${settings.statuses.length + 1}',
                          'Новый статус',
                          'open',
                        ),
                      ],
                    ),
                  ),
              ),
            ],
          ),
        ),
        _Section(
          title: 'Типы задач',
          child: Column(
            children: [
              for (final type in settings.types)
                _NamedRow(
                  name: type.name,
                  isDefault: type.id == settings.defaultTypeId,
                  onDefault: () => _update(
                    settings.copyWith(
                      defaultTypeId: type.id,
                      defaultTypeName: type.name,
                    ),
                  ),
                  onName: (name) => _update(
                    settings.copyWith(
                      types: [
                        for (final item in settings.types)
                          if (item.id == type.id && item.name == type.name)
                            TaskType(id: item.id, name: name)
                          else
                            item,
                      ],
                      defaultTypeName: settings.defaultTypeId == type.id
                          ? name
                          : settings.defaultTypeName,
                    ),
                  ),
                  onDelete: () => _update(
                    settings.copyWith(
                      types: [
                        for (final item in settings.types)
                          if (!(item.id == type.id && item.name == type.name))
                            item,
                      ],
                    ),
                  ),
                ),
              _AddButton(
                label: 'Добавить тип',
                onPressed: () {
                    final nextId = settings.types.fold<int>(
                      0,
                      (minId, type) => math.min(minId, type.id),
                    );
                    _update(
                      settings.copyWith(
                        types: [
                          ...settings.types,
                          TaskType(id: nextId - 1, name: 'Новый тип'),
                        ],
                      ),
                    );
                  },
              ),
            ],
          ),
        ),
        _Section(
          title: 'Поля задач',
          child: Column(
            children: [
              for (var index = 0; index < settings.fields.length; index++)
                _FieldEditor(
                  field: settings.fields[index],
                  onChanged: (field) {
                    final fields = [...settings.fields];
                    fields[index] = field;
                    _update(settings.copyWith(fields: fields));
                  },
                  onDelete: () {
                    final fields = [...settings.fields]..removeAt(index);
                    _update(settings.copyWith(fields: fields));
                  },
                ),
              _AddButton(
                label: 'Добавить поле',
                onPressed: () => _update(
                  settings.copyWith(
                    fields: [
                      ...settings.fields,
                      const QueueField(name: 'Новое поле', fieldType: 'text'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _Section(
          title: 'Приоритет по умолчанию',
          child: DdtSearchableFilterDropdown(
            summary: TaskPriority.fromValue(settings.defaultPriority)?.label ??
                'Не указан',
            active: settings.defaultPriority != null,
            multi: false,
            height: DdtTheme.inputControlHeight,
            options: [
              const DdtFilterOption(key: '', label: 'Не указан'),
              for (final item in TaskPriority.values)
                DdtFilterOption(key: item.value, label: item.label),
            ],
            selected: {settings.defaultPriority ?? ''},
            onSelected: (key) => _update(
              settings.copyWith(
                defaultPriority: key.isEmpty ? null : key,
                clearPriority: key.isEmpty,
              ),
            ),
          ),
        ),
        _Section(
          title: 'Дедлайн по умолчанию',
          child: DdtAppInput(
            controller: _deadlineController,
            label: 'Дней от создания',
            hint: 'Пусто — без дедлайна',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        _Section(
          title: 'Уведомления по умолчанию',
          child: Column(
            children: [
              _Toggle(
                label: 'Назначение',
                value: settings.notifyAssigned,
                onChanged: (value) =>
                    _update(settings.copyWith(notifyAssigned: value)),
              ),
              _Toggle(
                label: 'Изменение',
                value: settings.notifyUpdated,
                onChanged: (value) =>
                    _update(settings.copyWith(notifyUpdated: value)),
              ),
              _Toggle(
                label: 'Комментарий',
                value: settings.notifyComment,
                onChanged: (value) =>
                    _update(settings.copyWith(notifyComment: value)),
              ),
              _Toggle(
                label: 'Удаление',
                value: settings.notifyDeleted,
                onChanged: (value) =>
                    _update(settings.copyWith(notifyDeleted: value)),
              ),
              SizedBox(height: 8.h),
              DdtAppInput(
                controller: _reminderController,
                label: 'Напоминание о дедлайне, часов',
                hint: 'Пусто — не напоминать',
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        _Section(
          title: 'Компоненты',
          child: Column(
            children: [
              for (var index = 0; index < settings.components.length; index++)
                _NamedRow(
                  name: settings.components[index].name,
                  isDefault: settings.components[index].isDefault,
                  defaultLabel: 'По умолчанию',
                  exclusive: false,
                  onDefault: () {
                    final components = [...settings.components];
                    final current = components[index];
                    components[index] = QueueComponent(
                      id: current.id,
                      name: current.name,
                      isDefault: !current.isDefault,
                    );
                    _update(settings.copyWith(components: components));
                  },
                  onName: (name) {
                    final components = [...settings.components];
                    final current = components[index];
                    components[index] = QueueComponent(
                      id: current.id,
                      name: name,
                      isDefault: current.isDefault,
                    );
                    _update(settings.copyWith(components: components));
                  },
                  onDelete: () {
                    final components = [...settings.components]..removeAt(index);
                    _update(settings.copyWith(components: components));
                  },
                ),
              _AddButton(
                label: 'Добавить компонент',
                onPressed: () => _update(
                  settings.copyWith(
                    components: [
                      ...settings.components,
                      const QueueComponent(name: 'Новый компонент'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
      ],
    );
  }
}

class _FloatingSaveButton extends StatelessWidget {
  const _FloatingSaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _FilledButton(
      label: saving ? 'Сохранение…' : 'Сохранить',
      onPressed: saving ? null : onPressed,
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _FilledButton(
        label: label,
        icon: DdtIcons.add,
        onPressed: onPressed,
      ),
    );
  }
}

class _FilledButton extends StatefulWidget {
  const _FilledButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final FaIconData? icon;

  @override
  State<_FilledButton> createState() => _FilledButtonState();
}

class _FilledButtonState extends State<_FilledButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = !enabled
        ? DdtTheme.primaryColor.withValues(alpha: 0.45)
        : _pressed
        ? const Color(0xFF3730A3)
        : _hovered
        ? (isDark ? const Color(0xFF5B52F0) : DdtTheme.primaryHoverColor)
        : DdtTheme.primaryColor;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: DdtTheme.inputControlBorderRadius,
            boxShadow: [
              BoxShadow(
                color: DdtTheme.primaryColor.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                DdtIcon(widget.icon!, size: 13.sp, color: Colors.white),
                SizedBox(width: 7.w),
              ],
              Text(
                widget.label,
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSmallSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: DdtTheme.surfaceSubtle(context),
        borderRadius: DdtTheme.radius,
        border: Border.all(color: DdtTheme.borderSubtle(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
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
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DdtSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.isDefault,
    required this.onDefault,
    required this.onChanged,
    required this.onDelete,
  });

  final TaskStatus status;
  final bool isDefault;
  final VoidCallback onDefault;
  final ValueChanged<TaskStatus> onChanged;
  final VoidCallback? onDelete;

  static const _categories = {
    'open': 'Открыт',
    'active': 'В работе',
    'closed': 'Закрыт',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          DdtCheckbox(
            value: isDefault,
            padding: EdgeInsets.zero,
            onChanged: (value) {
              if (value) onDefault();
            },
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: DdtAppInput(
              initialValue: status.label,
              onChanged: (value) => onChanged(
                TaskStatus(status.value, value, status.category, status.id),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 150.w,
            child: DdtSearchableFilterDropdown(
              summary: _categories[status.category] ?? status.category,
              active: true,
              multi: false,
              options: [
                for (final entry in _categories.entries)
                  DdtFilterOption(key: entry.key, label: entry.value),
              ],
              selected: {status.category},
              onSelected: (value) => onChanged(
                TaskStatus(status.value, status.label, value, status.id),
              ),
            ),
          ),
          _DeleteButton(onPressed: onDelete),
        ],
      ),
    );
  }
}

class _NamedRow extends StatelessWidget {
  const _NamedRow({
    required this.name,
    required this.isDefault,
    required this.onDefault,
    required this.onName,
    required this.onDelete,
    this.defaultLabel = 'По умолчанию',
    this.exclusive = true,
  });

  final String name;
  final bool isDefault;
  final String defaultLabel;
  final VoidCallback onDefault;
  final ValueChanged<String> onName;
  final VoidCallback onDelete;
  final bool exclusive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Tooltip(
            message: defaultLabel,
            child: DdtCheckbox(
              value: isDefault,
              padding: EdgeInsets.zero,
              onChanged: (value) {
                if (exclusive) {
                  if (value) onDefault();
                } else {
                  onDefault();
                }
              },
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: DdtAppInput(
              initialValue: name,
              onChanged: onName,
            ),
          ),
          _DeleteButton(onPressed: onDelete),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) return const SizedBox(width: 8);
    return IconButton(
      tooltip: 'Удалить',
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: DdtIcon(
        DdtIcons.trash,
        size: 14,
        color: DdtTheme.textMuted(context),
      ),
    );
  }
}

class _FieldEditor extends StatelessWidget {
  const _FieldEditor({
    required this.field,
    required this.onChanged,
    required this.onDelete,
  });

  final QueueField field;
  final ValueChanged<QueueField> onChanged;
  final VoidCallback onDelete;

  static const _fieldTypeLabels = {
    'text': 'Текст',
    'number': 'Число',
    'date': 'Дата',
    'list': 'Список',
    'user': 'Пользователь',
    'checkbox': 'Флажок',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DdtAppInput(
                  initialValue: field.name,
                  label: 'Название',
                  onChanged: (value) => onChanged(
                    QueueField(
                      id: field.id,
                      name: value,
                      fieldType: field.fieldType,
                      listMultiple: field.listMultiple,
                      options: field.options,
                      defaultValue: field.defaultValue,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              SizedBox(
                width: 160.w,
                child: DdtSearchableFilterDropdown(
                  summary: _fieldTypeLabels[field.fieldType] ?? field.fieldType,
                  active: true,
                  multi: false,
                  height: DdtTheme.inputControlHeight,
                  options: [
                    for (final entry in _fieldTypeLabels.entries)
                      DdtFilterOption(key: entry.key, label: entry.value),
                  ],
                  selected: {field.fieldType},
                  onSelected: (value) => onChanged(
                    QueueField(
                      id: field.id,
                      name: field.name,
                      fieldType: value,
                      listMultiple: field.listMultiple,
                      options: field.options,
                      defaultValue: null,
                    ),
                  ),
                ),
              ),
              _DeleteButton(onPressed: onDelete),
            ],
          ),
          if (field.fieldType == 'list') ...[
            SizedBox(height: 8.h),
            DdtAppInput(
              key: ValueKey('options-${field.fieldType}'),
              initialValue: field.options.join(', '),
              label: 'Варианты через запятую',
              onChanged: (value) => onChanged(
                QueueField(
                  id: field.id,
                  name: field.name,
                  fieldType: field.fieldType,
                  listMultiple: field.listMultiple,
                  options: [
                    for (final item in value.split(','))
                      if (item.trim().isNotEmpty) item.trim(),
                  ],
                  defaultValue: field.defaultValue,
                ),
              ),
            ),
            _Toggle(
              label: 'Несколько значений',
              value: field.listMultiple,
              onChanged: (value) => onChanged(
                QueueField(
                  id: field.id,
                  name: field.name,
                  fieldType: field.fieldType,
                  listMultiple: value,
                  options: field.options,
                  defaultValue: field.defaultValue,
                ),
              ),
            ),
          ],
          SizedBox(height: 8.h),
          DdtAppInput(
            key: ValueKey('default-${field.fieldType}'),
            initialValue: field.defaultValue?.toString() ?? '',
            label: 'Значение по умолчанию',
            onChanged: (value) => onChanged(
              QueueField(
                id: field.id,
                name: field.name,
                fieldType: field.fieldType,
                listMultiple: field.listMultiple,
                options: field.options,
                defaultValue: _parseDefault(field.fieldType, value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Object? _parseDefault(String type, String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    switch (type) {
      case 'number':
        return num.tryParse(text.replaceAll(',', '.'));
      case 'checkbox':
        return text == '1' || text.toLowerCase() == 'true' || text == 'да';
      case 'user':
        return int.tryParse(text);
      case 'list':
        if (field.listMultiple) {
          return [
            for (final item in text.split(','))
              if (item.trim().isNotEmpty) item.trim(),
          ];
        }
        return text;
      default:
        return text;
    }
  }
}

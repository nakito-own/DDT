import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../router/route_paths.dart';
import '../services/boards_store.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/task_formatters.dart';
import '../widgets/ddt_adaptive.dart';
import '../widgets/ddt_app_input.dart';
import '../widgets/ddt_filter_dropdown.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_panel_primary_button.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/ddt_section_sidebar.dart';
import '../widgets/ddt_shell_metrics.dart';

enum _BoardDateFilter {
  any('Все даты'),
  today('Сегодня'),
  week('Последние 7 дней'),
  month('Последние 30 дней');

  const _BoardDateFilter(this.label);

  final String label;
}

enum _BoardSort {
  createdDesc('Сначала новые'),
  createdAsc('Сначала старые'),
  title('По названию'),
  updatedDesc('По изменению');

  const _BoardSort(this.label);

  final String label;
}

void _showBoardMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class BoardsPage extends StatefulWidget {
  const BoardsPage({super.key});

  @override
  State<BoardsPage> createState() => _BoardsPageState();
}

class _BoardsPageState extends State<BoardsPage> {
  final _store = BoardsStore.instance;
  final _searchController = TextEditingController();
  List<DiagramBoard> _boards = const [];
  bool _loading = true;
  String? _error;
  String _author = '';
  _BoardDateFilter _date = _BoardDateFilter.any;
  _BoardSort _sort = _BoardSort.createdDesc;

  bool _routeVisible = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    if (visible && !_routeVisible) _reload();
    _routeVisible = visible;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final boards = await _store.list();
      if (!mounted) return;
      setState(() {
        _boards = boards;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is BoardsApiException
            ? error.message
            : 'Не удалось загрузить доски';
      });
    }
  }

  Future<void> _create() async {
    final title = await showBoardTitleDialog(
      context,
      title: 'Новая доска',
      confirmLabel: 'Создать',
    );
    if (title == null || !mounted) return;
    final DiagramBoard board;
    try {
      board = await _store.create(title: title);
    } on BoardsApiException catch (error) {
      if (!mounted) return;
      _showBoardMessage(context, error.message);
      return;
    }
    if (!mounted) return;
    context.push(RoutePaths.boardFor(board.id));
  }

  Future<void> _rename(DiagramBoard board) async {
    final title = await showBoardTitleDialog(
      context,
      title: 'Переименовать',
      confirmLabel: 'Сохранить',
      initial: board.title,
    );
    if (title == null) return;
    try {
      await _store.rename(board.id, title);
    } on BoardsApiException catch (error) {
      if (!mounted) return;
      _showBoardMessage(context, error.message);
      return;
    }
    await _reload();
  }

  Future<void> _delete(DiagramBoard board) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _dialogFill(context),
        title: Text(
          'Удалить доску?',
          style: DdtTheme.style(
            fontSize: DdtTypography.panelTitleSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.textPrimary(context),
          ),
        ),
        content: Text(
          '«${board.title}» исчезнет из общего списка.',
          style: DdtTheme.style(
            fontSize: DdtTypography.bodySize,
            color: DdtTheme.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Удалить',
              style: TextStyle(color: DdtTheme.dangerColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _store.delete(board.id);
    } on BoardsApiException catch (error) {
      if (!mounted) return;
      _showBoardMessage(context, error.message);
      return;
    }
    await _reload();
  }

  List<DiagramBoard> get _visible {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final boards = _boards.where((board) {
      if (query.isNotEmpty && !board.title.toLowerCase().contains(query)) {
        return false;
      }
      if (_author.isNotEmpty && board.authorLabel != _author) return false;
      return _matchesCreated(board.createdAt.toLocal(), now);
    }).toList();

    boards.sort((a, b) {
      return switch (_sort) {
        _BoardSort.createdDesc => b.createdAt.compareTo(a.createdAt),
        _BoardSort.createdAsc => a.createdAt.compareTo(b.createdAt),
        _BoardSort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        _BoardSort.updatedDesc => b.updatedAt.compareTo(a.updatedAt),
      };
    });
    return boards;
  }

  bool _matchesCreated(DateTime created, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    return switch (_date) {
      _BoardDateFilter.any => true,
      _BoardDateFilter.today => !created.isBefore(startOfToday),
      _BoardDateFilter.week =>
        !created.isBefore(startOfToday.subtract(const Duration(days: 6))),
      _BoardDateFilter.month =>
        !created.isBefore(startOfToday.subtract(const Duration(days: 29))),
    };
  }

  @override
  Widget build(BuildContext context) {
    final boards = _visible;
    final authors = {
      for (final board in _boards) board.authorLabel,
    }.toList()..sort();

    return DdtAdaptiveSectionColumns(
      sheetTitle: 'Фильтры',
      sidebar: _BoardsFiltersPanel(
        searchController: _searchController,
        onSearchChanged: () => setState(() {}),
        onCreatePressed: _create,
        authors: authors,
        author: _author,
        onAuthor: (value) => setState(() => _author = value),
        date: _date,
        onDate: (value) => setState(() => _date = value),
        sort: _sort,
        onSort: (value) => setState(() => _sort = value),
        found: boards.length,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : boards.isEmpty
          ? Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: DdtShellMetrics.fixedTopPadding(context),
                child: Text(
                  _error ??
                      (_boards.isEmpty
                          ? 'Пока нет досок'
                          : 'Нет досок по выбранным фильтрам'),
                  style: DdtTheme.style(fontSize: DdtTypography.bodySize),
                ),
              ),
            )
          : DdtScrollEdgeFade(
              child: ListView.separated(
                padding: DdtShellMetrics.scrollPadding(context),
                clipBehavior: Clip.none,
                itemCount: boards.length,
                separatorBuilder: (context, index) => SizedBox(height: 10.h),
                itemBuilder: (context, index) {
                  final board = boards[index];
                  return _BoardCard(
                    board: board,
                    onOpen: () => context.push(RoutePaths.boardFor(board.id)),
                    onRename: () => _rename(board),
                    onDelete: () => _delete(board),
                  );
                },
              ),
            ),
    );
  }
}

class _BoardsFiltersPanel extends StatelessWidget {
  const _BoardsFiltersPanel({
    required this.searchController,
    required this.onSearchChanged,
    required this.onCreatePressed,
    required this.authors,
    required this.author,
    required this.onAuthor,
    required this.date,
    required this.onDate,
    required this.sort,
    required this.onSort,
    required this.found,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onCreatePressed;
  final List<String> authors;
  final String author;
  final ValueChanged<String> onAuthor;
  final _BoardDateFilter date;
  final ValueChanged<_BoardDateFilter> onDate;
  final _BoardSort sort;
  final ValueChanged<_BoardSort> onSort;
  final int found;

  @override
  Widget build(BuildContext context) {
    final authorOptions = [
      const DdtFilterOption(key: '', label: 'Все авторы'),
      for (final name in authors) DdtFilterOption(key: name, label: name),
    ];
    final dateOptions = [
      for (final option in _BoardDateFilter.values)
        DdtFilterOption(key: option.name, label: option.label),
    ];
    final sortOptions = [
      for (final option in _BoardSort.values)
        DdtFilterOption(key: option.name, label: option.label),
    ];

    return DdtSectionSidebarScroll(
      child: ListView(
        clipBehavior: Clip.none,
        padding: DdtSectionSidebar.scrollContentPadding(),
        children: [
          DdtSectionSidebarField(
            gapAbove: false,
            child: DdtPanelPrimaryButton(
              label: 'Создать',
              icon: DdtIcons.add,
              onPressed: onCreatePressed,
            ),
          ),
          SizedBox(height: DdtSectionSidebar.afterPrimaryButtonGap),
          const DdtSectionSidebarTitle(),
          SizedBox(height: DdtSectionSidebar.afterTitleGap),
          DdtSectionSidebarField(
            label: 'Поиск',
            gapAbove: false,
            child: DdtAppInput(
              hint: 'Поиск по названию',
              controller: searchController,
              type: InputType.search,
              variant: DdtInputVariant.compact,
              prefixIcon: DdtIcons.search,
              borderRadius: DdtTheme.inputControlBorderRadius,
              onChanged: (_) => onSearchChanged(),
            ),
          ),
          DdtSectionSidebarField(
            label: 'Автор',
            child: DdtSearchableFilterDropdown(
              summary: author.isEmpty ? 'Все авторы' : author,
              active: author.isNotEmpty,
              options: authorOptions,
              selected: {author},
              multi: false,
              onSelected: onAuthor,
            ),
          ),
          DdtSectionSidebarField(
            label: 'Дата создания',
            child: DdtSearchableFilterDropdown(
              summary: date.label,
              active: date != _BoardDateFilter.any,
              options: dateOptions,
              selected: {date.name},
              multi: false,
              onSelected: (key) {
                for (final option in _BoardDateFilter.values) {
                  if (option.name == key) onDate(option);
                }
              },
            ),
          ),
          DdtSectionSidebarField(
            label: 'Сортировка',
            child: DdtSearchableFilterDropdown(
              summary: sort.label,
              active: sort != _BoardSort.createdDesc,
              options: sortOptions,
              selected: {sort.name},
              multi: false,
              onSelected: (key) {
                for (final option in _BoardSort.values) {
                  if (option.name == key) onSort(option);
                }
              },
            ),
          ),
          SizedBox(height: DdtSectionSidebar.blockGap),
          Divider(
            height: 1,
            thickness: 1,
            color: DdtTheme.sidePanelDivider(context),
          ),
          SizedBox(height: DdtSectionSidebar.afterDividerGap),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: DdtTheme.inputFillColor(context),
              borderRadius: DdtTheme.inputControlBorderRadius,
              border: Border.all(color: DdtTheme.borderSubtle(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Найдено досок',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSmallSize,
                    fontWeight: FontWeight.w500,
                    color: DdtTheme.textMuted(context),
                  ),
                ),
                Text(
                  '$found',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSize,
                    fontWeight: FontWeight.w700,
                    color: DdtTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.board,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final DiagramBoard board;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final muted = DdtTheme.textMuted(context);

    return DdtTheme.taskCardGlass(
      context: context,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DdtIcon(DdtIcons.boards, size: 12.sp, color: muted),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  board.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Действия',
                color: _dialogFill(context),
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(
                      'Переименовать',
                      style: DdtTheme.style(
                        fontSize: DdtTypography.bodySize,
                        color: DdtTheme.textPrimary(context),
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Удалить',
                      style: DdtTheme.style(
                        fontSize: DdtTypography.bodySize,
                        color: DdtTheme.dangerColor,
                      ),
                    ),
                  ),
                ],
                child: DdtIcon(
                  DdtIcons.moreVertical,
                  size: 13.sp,
                  color: muted,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            '${board.authorLabel} · ${formatTaskDateTime(board.createdAt.toLocal())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

Color _dialogFill(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? DdtTheme.darkSurface : DdtTheme.lightSurface;
}

Future<String?> showBoardTitleDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _BoardTitleDialog(
      title: title,
      confirmLabel: confirmLabel,
      initial: initial,
    ),
  );
}

class _BoardTitleDialog extends StatefulWidget {
  const _BoardTitleDialog({
    required this.title,
    required this.confirmLabel,
    required this.initial,
  });

  final String title;
  final String confirmLabel;
  final String initial;

  @override
  State<_BoardTitleDialog> createState() => _BoardTitleDialogState();
}

class _BoardTitleDialogState extends State<_BoardTitleDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _dialogFill(context),
      title: Text(
        widget.title,
        style: DdtTheme.style(
          fontSize: DdtTypography.panelTitleSize,
          fontWeight: FontWeight.w600,
          color: DdtTheme.textPrimary(context),
        ),
      ),
      content: DdtAppInput(
        controller: _controller,
        hint: 'Название',
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

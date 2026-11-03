import 'dart:async';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../router/route_paths.dart';
import '../services/notes_api.dart';
import '../services/notes_controller.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/ddt_toast.dart';
import '../utils/task_formatters.dart';
import '../widgets/ddt_adaptive.dart';
import '../widgets/ddt_app_input.dart';
import '../widgets/ddt_filter_dropdown.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_markdown_description_input.dart';
import '../widgets/ddt_markdown_live_controller.dart';
import '../widgets/ddt_panel_primary_button.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/ddt_section_sidebar.dart';
import '../widgets/ddt_shell_metrics.dart';

/// Раздел заметок: фильтры живут в оболочке и не исчезают при открытии записи.
class NotesShellPage extends StatefulWidget {
  const NotesShellPage({super.key, required this.child});

  final Widget child;

  @override
  State<NotesShellPage> createState() => _NotesShellPageState();
}

class _NotesShellPageState extends State<NotesShellPage> {
  late final NotesController _notes = NotesController();
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    NotesCommands.attach(_notes);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_syncRoute);
      _router = router;
      router.routerDelegate.addListener(_syncRoute);
    }
    _syncRoute();
  }

  @override
  void dispose() {
    NotesCommands.detach(_notes);
    _router?.routerDelegate.removeListener(_syncRoute);
    _notes.dispose();
    super.dispose();
  }

  void _syncRoute() {
    if (!mounted || _router == null) return;
    _notes.setBrowsingFolder(_router!.state.uri.queryParameters['folder']);
  }

  @override
  Widget build(BuildContext context) {
    return NotesScope(
      controller: _notes,
      child: DdtAdaptiveSectionColumns(
        sheetTitle: 'Фильтры',
        sidebar: const _NotesFiltersPanel(),
        body: widget.child,
      ),
    );
  }
}

class NotesBrowserPage extends StatefulWidget {
  const NotesBrowserPage({super.key});

  @override
  State<NotesBrowserPage> createState() => _NotesBrowserPageState();
}

class _NotesBrowserPageState extends State<NotesBrowserPage> {
  final _expanded = <String>{};
  final _collapsed = <String>{};
  var _dragging = false;

  bool _isOpen(NotesController notes, String id) {
    if (_collapsed.contains(id)) return false;
    if (_expanded.contains(id)) return true;
    return notes.filtersActive && notes.foldersHoldingMatches().contains(id);
  }

  void _toggle(NotesController notes, String id) {
    setState(() {
      if (_isOpen(notes, id)) {
        _collapsed.add(id);
        _expanded.remove(id);
      } else {
        _collapsed.remove(id);
        _expanded.add(id);
      }
    });
  }

  void _dragStarted() {
    if (_dragging) return;
    setState(() => _dragging = true);
  }

  void _dragEnded() {
    if (!_dragging) return;
    setState(() => _dragging = false);
  }

  Future<void> _move(
    NotesController notes,
    NoteItem item,
    String? parentId,
  ) async {
    if (item.parentId == parentId) return;
    try {
      await notes.move(item.id, parentId);
      if (parentId != null && mounted) {
        setState(() {
          _collapsed.remove(parentId);
          _expanded.add(parentId);
        });
      }
    } on NotesApiException catch (error) {
      if (!mounted) return;
      _showNoteError(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = NotesScope.read(context);
    return ListenableBuilder(
      listenable: notes,
      builder: (context, _) {
        if (notes.loading && notes.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (notes.error != null && notes.items.isEmpty) {
          return _NotesStatus(message: notes.error!, onRetry: notes.retry);
        }

        final roots = notes.childrenOf(null);
        final top = DdtShellMetrics.maybeOf(context)?.contentInsetTop ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: top),
            if (_dragging)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _RootDropTarget(
                  notes: notes,
                  onAccept: (item) => _move(notes, item, null),
                ),
              ),
            Expanded(
              child: roots.isEmpty
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 28.h),
                        child: Text(
                          _emptyMessage(notes),
                          style: DdtTheme.style(
                            fontSize: DdtTypography.bodySize,
                          ),
                        ),
                      ),
                    )
                  : DdtScrollEdgeFade(
                      showTop: false,
                      child: ListView.separated(
                        padding: EdgeInsets.only(bottom: 12.h),
                        clipBehavior: Clip.none,
                        itemCount: roots.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          return _NoteBranch(
                            key: ValueKey(roots[index].id),
                            item: roots[index],
                            notes: notes,
                            depth: 0,
                            open: _isOpen(notes, roots[index].id),
                            isOpen: (id) => _isOpen(notes, id),
                            onToggle: (id) => _toggle(notes, id),
                            onDragStarted: _dragStarted,
                            onDragEnd: _dragEnded,
                            onMove: (item, parentId) =>
                                _move(notes, item, parentId),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.noteId});

  final String noteId;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _title = TextEditingController();
  final _body = DdtMarkdownLiveController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  NotesController? _notes;
  NoteItem? _detail;
  Timer? _timer;
  var _started = false;
  var _loading = true;
  var _hydrating = false;
  var _dirty = false;
  var _saving = false;
  String? _error;
  String _status = '';
  String _savedTitle = '';
  String _savedBody = '';

  @override
  void initState() {
    super.initState();
    _title.addListener(_scheduleSave);
    _body.addListener(_scheduleSave);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notes = NotesScope.read(context);
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _title.removeListener(_scheduleSave);
    _body.removeListener(_scheduleSave);
    final notes = _notes;
    final dirty = _dirty;
    final title = _draftTitle();
    final body = _body.text;
    final id = widget.noteId;
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    if (dirty && notes != null && title.isNotEmpty) {
      unawaited(notes.save(id, title: title, body: body));
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.noteId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Заметка не найдена';
      });
      return;
    }
    try {
      final detail = await _notes!.fetch(widget.noteId);
      if (!mounted) return;
      if (detail.isFolder) {
        context.go(RoutePaths.notesAt(folderId: detail.id));
        return;
      }
      _hydrating = true;
      _title.text = detail.title;
      _body.text = detail.body;
      _savedTitle = detail.title;
      _savedBody = detail.body;
      _detail = detail;
      _dirty = false;
      _hydrating = false;
      setState(() {
        _loading = false;
        _error = null;
        _status = '';
      });
    } on NotesApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось открыть заметку';
      });
    }
  }

  String _draftTitle() {
    final typed = _title.text.trim();
    if (typed.isNotEmpty) return typed;
    return _savedTitle.trim();
  }

  bool get _matchesSaved =>
      _title.text.trim() == _savedTitle && _body.text == _savedBody;

  void _scheduleSave() {
    if (_hydrating || _loading || _error != null) return;
    if (_matchesSaved) {
      _dirty = false;
      return;
    }
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_persist());
    });
    if (_status == 'Не сохранено' || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_dirty || _status == 'Не сохранено') return;
      setState(() => _status = 'Не сохранено');
    });
  }

  Future<void> _persist() async {
    final notes = _notes;
    if (notes == null || !_dirty || _saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      if (mounted) setState(() => _status = 'Введите название');
      return;
    }
    final body = _body.text;
    _saving = true;
    if (mounted) setState(() => _status = 'Сохранение…');
    try {
      await notes.save(widget.noteId, title: title, body: body);
      final stillSame = _title.text.trim() == title && _body.text == body;
      if (stillSame) {
        _savedTitle = title;
        _savedBody = body;
        _dirty = false;
      }
      if (!mounted) return;
      setState(() => _status = stillSame ? 'Сохранено' : 'Не сохранено');
      if (!stillSame) _scheduleSave();
    } on NotesApiException catch (error) {
      _dirty = true;
      if (!mounted) return;
      setState(() => _status = error.message);
    } catch (_) {
      _dirty = true;
      if (!mounted) return;
      setState(() => _status = 'Не удалось сохранить');
    } finally {
      _saving = false;
    }
  }

  Future<void> _back() async {
    _timer?.cancel();
    await _persist();
    if (!mounted) return;
    _closeEditor();
  }

  void _closeEditor() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RoutePaths.notes);
  }

  Future<void> _delete() async {
    _timer?.cancel();
    _dirty = false;
    final title = _detail?.title ?? _title.text.trim();
    final confirmed = await _confirmDelete(
      context,
      message: 'Заметка «$title» будет удалена.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await _notes!.delete(widget.noteId);
    } on NotesApiException catch (error) {
      if (!mounted) return;
      _showNoteError(context, error.message);
      return;
    }
    if (!mounted) return;
    _closeEditor();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _NotesStatus(message: _error!, onBack: _back);
    }

    final top = DdtShellMetrics.maybeOf(context)?.contentInsetTop ?? 0;
    final bottom = DdtShellMetrics.contentBottomPadding(context);
    final titleStyle = DdtTheme.style(
      fontSize: DdtTypography.entityTitleSize,
      fontWeight: FontWeight.w700,
      color: DdtTheme.textPrimary(context),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, top + 12.h, 12.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _NoteIconButton(
                    icon: DdtIcons.chevronLeft,
                    tooltip: 'К списку',
                    onPressed: _back,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'ЗАМЕТКА',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSize,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: DdtTheme.sidePanelTextMuted(
                          context,
                        ).withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  if (_status.isNotEmpty) ...[
                    Text(
                      _status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSmallSize,
                        color: _status == 'Сохранено'
                            ? DdtTheme.textMuted(context)
                            : DdtTheme.textSecondary(context),
                      ),
                    ),
                    SizedBox(width: 2.w),
                  ],
                  _NoteIconButton(
                    icon: DdtIcons.trash,
                    tooltip: 'Удалить',
                    onPressed: _delete,
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              _NoteTitleField(
                controller: _title,
                focusNode: _titleFocus,
                style: titleStyle,
                onSubmitted: (_) => _bodyFocus.requestFocus(),
              ),
            ],
          ),
        ),
        Expanded(
          child: DdtScrollEdgeFade(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, bottom),
              children: [
                DdtMarkdownDescriptionInput(
                  controller: _body,
                  focusNode: _bodyFocus,
                  label: null,
                  hint: 'Текст заметки',
                  minLines: 8,
                  plain: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotesFiltersPanel extends StatefulWidget {
  const _NotesFiltersPanel();

  @override
  State<_NotesFiltersPanel> createState() => _NotesFiltersPanelState();
}

class _NotesFiltersPanelState extends State<_NotesFiltersPanel> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = NotesScope.read(context);
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
              onPressed: () => _createNote(context, notes),
            ),
          ),
          SizedBox(height: DdtSectionSidebar.afterPrimaryButtonGap),
          const DdtSectionSidebarTitle(),
          SizedBox(height: DdtSectionSidebar.afterTitleGap),
          DdtSectionSidebarField(
            label: 'Поиск',
            gapAbove: false,
            child: DdtAppInput(
              hint: 'Название или начало текста',
              controller: _searchController,
              type: InputType.search,
              variant: DdtInputVariant.compact,
              prefixIcon: DdtIcons.search,
              borderRadius: DdtTheme.inputControlBorderRadius,
              onChanged: notes.setQuery,
            ),
          ),
          ListenableBuilder(
            listenable: notes,
            builder: (context, _) => _NotesFilterFields(notes: notes),
          ),
        ],
      ),
    );
  }
}

class _NotesFilterFields extends StatelessWidget {
  const _NotesFilterFields({required this.notes});

  final NotesController notes;

  @override
  Widget build(BuildContext context) {
    final authorOptions = [
      const DdtFilterOption(key: '', label: 'Все авторы'),
      for (final name in notes.authors) DdtFilterOption(key: name, label: name),
    ];
    final kindOptions = [
      for (final option in NoteKindFilter.values)
        DdtFilterOption(key: option.name, label: option.label),
    ];
    final dateOptions = [
      for (final option in NoteDateFilter.values)
        DdtFilterOption(key: option.name, label: option.label),
    ];
    final sortOptions = [
      for (final option in NoteSort.values)
        DdtFilterOption(key: option.name, label: option.label),
    ];
    final found = notes.matchCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DdtSectionSidebarField(
          label: 'Тип',
          child: DdtSearchableFilterDropdown(
            summary: notes.kind.label,
            active: notes.kind != NoteKindFilter.all,
            options: kindOptions,
            selected: {notes.kind.name},
            multi: false,
            onSelected: (key) {
              for (final option in NoteKindFilter.values) {
                if (option.name == key) notes.setKind(option);
              }
            },
          ),
        ),
        DdtSectionSidebarField(
          label: 'Автор',
          child: DdtSearchableFilterDropdown(
            summary: notes.author.isEmpty ? 'Все авторы' : notes.author,
            active: notes.author.isNotEmpty,
            options: authorOptions,
            selected: {notes.author},
            multi: false,
            onSelected: notes.setAuthor,
          ),
        ),
        DdtSectionSidebarField(
          label: 'Дата создания',
          child: DdtSearchableFilterDropdown(
            summary: notes.date.label,
            active: notes.date != NoteDateFilter.any,
            options: dateOptions,
            selected: {notes.date.name},
            multi: false,
            onSelected: (key) {
              for (final option in NoteDateFilter.values) {
                if (option.name == key) notes.setDate(option);
              }
            },
          ),
        ),
        DdtSectionSidebarField(
          label: 'Сортировка',
          child: DdtSearchableFilterDropdown(
            summary: notes.sort.label,
            active: notes.sort != NoteSort.createdDesc,
            options: sortOptions,
            selected: {notes.sort.name},
            multi: false,
            onSelected: (key) {
              for (final option in NoteSort.values) {
                if (option.name == key) notes.setSort(option);
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
                'Найдено',
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
    );
  }
}

class _RootDropTarget extends StatelessWidget {
  const _RootDropTarget({required this.notes, required this.onAccept});

  final NotesController notes;
  final ValueChanged<NoteItem> onAccept;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? DdtTheme.accentColor
        : DdtTheme.primaryColor;
    return DragTarget<NoteItem>(
      onWillAcceptWithDetails: (details) {
        final item = details.data;
        return item.parentId != null && notes.canPlace(item, null);
      },
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final hot = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 36.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hot
                ? accent.withValues(alpha: 0.14)
                : DdtTheme.inputFillColor(context),
            borderRadius: DdtTheme.inputControlBorderRadius,
            border: Border.all(
              color: hot ? accent : DdtTheme.borderSubtle(context),
            ),
          ),
          child: Text(
            'В корень',
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              fontWeight: FontWeight.w600,
              color: hot ? accent : DdtTheme.textSecondary(context),
            ),
          ),
        );
      },
    );
  }
}

class _NoteBranch extends StatelessWidget {
  const _NoteBranch({
    super.key,
    required this.item,
    required this.notes,
    required this.depth,
    required this.open,
    required this.isOpen,
    required this.onToggle,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onMove,
  });

  final NoteItem item;
  final NotesController notes;
  final int depth;
  final bool open;
  final bool Function(String id) isOpen;
  final ValueChanged<String> onToggle;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final void Function(NoteItem item, String? parentId) onMove;

  @override
  Widget build(BuildContext context) {
    final tile = item.isFolder
        ? _FolderTile(
            item: item,
            notes: notes,
            depth: depth,
            open: open,
            isOpen: isOpen,
            onToggle: onToggle,
            onDragStarted: onDragStarted,
            onDragEnd: onDragEnd,
            onMove: onMove,
          )
        : _NoteTile(
            item: item,
            onDragStarted: onDragStarted,
            onDragEnd: onDragEnd,
          );
    if (depth == 0) return tile;
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: tile,
    );
  }
}

class _FolderTile extends StatefulWidget {
  const _FolderTile({
    required this.item,
    required this.notes,
    required this.depth,
    required this.open,
    required this.isOpen,
    required this.onToggle,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onMove,
  });

  final NoteItem item;
  final NotesController notes;
  final int depth;
  final bool open;
  final bool Function(String id) isOpen;
  final ValueChanged<String> onToggle;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final void Function(NoteItem item, String? parentId) onMove;

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expand;
  late final CurvedAnimation _expandCurve;
  var _hover = false;

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(
      vsync: this,
      duration: DdtTheme.selectionAnimationDuration,
      reverseDuration: DdtTheme.selectionAnimationDuration,
    );
    _expandCurve = CurvedAnimation(
      parent: _expand,
      curve: DdtTheme.selectionAnimationCurve,
      reverseCurve: Curves.easeInCubic,
    );
    if (widget.open) _expand.value = 1;
    _expand.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(_FolderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open) {
      _expand.forward();
    } else {
      _expand.reverse();
    }
  }

  @override
  void dispose() {
    _expand.removeStatusListener(_onStatus);
    _expandCurve.dispose();
    _expand.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed ||
        status == AnimationStatus.completed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final notes = widget.notes;
    final showChildren =
        widget.open || _expand.status != AnimationStatus.dismissed;
    final settled = _expand.status == AnimationStatus.completed;
    final children = notes.childrenOf(item.id);
    final thread = _FolderChildren(
      notes: notes,
      children: children,
      depth: widget.depth,
      isOpen: widget.isOpen,
      onToggle: widget.onToggle,
      onDragStarted: widget.onDragStarted,
      onDragEnd: widget.onDragEnd,
      onMove: widget.onMove,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DragTarget<NoteItem>(
          onWillAcceptWithDetails: (details) {
            final incoming = details.data;
            if (incoming.id == item.id || incoming.parentId == item.id) {
              return false;
            }
            return notes.canPlace(incoming, item.id);
          },
          onAcceptWithDetails: (details) =>
              widget.onMove(details.data, item.id),
          builder: (context, candidate, rejected) {
            return _DragCard(
              item: item,
              onDragStarted: widget.onDragStarted,
              onDragEnd: widget.onDragEnd,
              highlighted: candidate.isNotEmpty,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: Stack(
                  children: [
                    _FolderCard(
                      item: item,
                      notes: notes,
                      expanded: widget.open,
                      onTap: () => widget.onToggle(item.id),
                    ),
                    if (_hover)
                      Positioned(
                        top: 4,
                        right: 6,
                        child: _FolderHoverActions(
                          onRename: () => _rename(context),
                          onDelete: () => _delete(context),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (showChildren)
          if (settled)
            thread
          else
            SizeTransition(
              sizeFactor: _expandCurve,
              alignment: Alignment.topCenter,
              child: thread,
            ),
      ],
    );
  }

  Future<void> _rename(BuildContext context) async {
    final title = await _askTitle(
      context,
      title: 'Переименовать',
      confirmLabel: 'Сохранить',
      initial: widget.item.title,
    );
    if (title == null || !context.mounted) return;
    try {
      await widget.notes.rename(widget.item.id, title);
    } on NotesApiException catch (error) {
      if (!context.mounted) return;
      _showNoteError(context, error.message);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final nested = widget.notes.descendantCount(widget.item.id);
    final message = nested == 0
        ? 'Папка «${widget.item.title}» будет удалена.'
        : 'Папка «${widget.item.title}» и всё внутри ($nested) будут удалены.';
    final confirmed = await _confirmDelete(context, message: message);
    if (confirmed != true || !context.mounted) return;
    try {
      await widget.notes.delete(widget.item.id);
    } on NotesApiException catch (error) {
      if (!context.mounted) return;
      _showNoteError(context, error.message);
    }
  }
}

class _FolderChildren extends StatelessWidget {
  const _FolderChildren({
    required this.notes,
    required this.children,
    required this.depth,
    required this.isOpen,
    required this.onToggle,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onMove,
  });

  final NotesController notes;
  final List<NoteItem> children;
  final int depth;
  final bool Function(String id) isOpen;
  final ValueChanged<String> onToggle;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final void Function(NoteItem item, String? parentId) onMove;

  @override
  Widget build(BuildContext context) {
    final lineColor = DdtTheme.glassBorderColor(
      Theme.of(context).brightness,
    ).withValues(alpha: 0.55);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (children.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h, bottom: 4.h),
            child: Text(
              'Пусто',
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSmallSize,
                color: DdtTheme.textMuted(context),
              ),
            ),
          ),
        for (final child in children)
          _NoteBranch(
            key: ValueKey(child.id),
            item: child,
            notes: notes,
            depth: depth + 1,
            open: isOpen(child.id),
            isOpen: isOpen,
            onToggle: onToggle,
            onDragStarted: onDragStarted,
            onDragEnd: onDragEnd,
            onMove: onMove,
          ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(top: 2.h, left: 6.w),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: lineColor,
              child: SizedBox(width: 2.w),
            ),
            SizedBox(width: 10.w),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.item,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  final NoteItem item;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return _DragCard(
      item: item,
      onDragStarted: onDragStarted,
      onDragEnd: onDragEnd,
      child: _NoteBody(
        item: item,
        onTap: () => context.push(RoutePaths.noteFor(item.id)),
      ),
    );
  }
}

class _DragCard extends StatelessWidget {
  const _DragCard({
    required this.item,
    required this.child,
    required this.onDragStarted,
    required this.onDragEnd,
    this.highlighted = false,
  });

  final NoteItem item;
  final Widget child;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? DdtTheme.accentColor
        : DdtTheme.primaryColor;
    return Draggable<NoteItem>(
      data: item,
      rootOverlay: true,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd(),
      feedback: _NoteDragFeedback(item: item),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: DdtTheme.radius,
          border: Border.all(
            color: highlighted ? accent : Colors.transparent,
            width: highlighted ? 1.5 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _NoteDragFeedback extends StatelessWidget {
  const _NoteDragFeedback({required this.item});

  final NoteItem item;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? DdtTheme.accentColor
        : DdtTheme.primaryColor;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 280.w),
        child: DdtTheme.taskCardGlass(
          context: context,
          isDragging: true,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.isFolder) ...[
                DdtIcon(DdtIcons.folder, size: 12.sp, color: accent),
                SizedBox(width: 8.w),
              ],
              Flexible(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    fontWeight: FontWeight.w600,
                    color: DdtTheme.taskCardTextPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.item,
    required this.notes,
    required this.expanded,
    required this.onTap,
  });

  final NoteItem item;
  final NotesController notes;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final muted = DdtTheme.textMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;

    return DdtTheme.taskCardGlass(
      context: context,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOutCubic,
                child: DdtIcon(
                  DdtIcons.chevronRight,
                  size: 11.sp,
                  color: muted,
                ),
              ),
              SizedBox(width: 8.w),
              DdtIcon(
                expanded ? DdtIcons.folderOpen : DdtIcons.folder,
                size: 12.sp,
                color: accent,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            '${item.authorLabel} · ${formatTaskDateTime(item.updatedAt.toLocal())} · ${_insideLabel(notes.childCount(item.id))}',
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

class _NoteBody extends StatelessWidget {
  const _NoteBody({required this.item, required this.onTap});

  final NoteItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final muted = DdtTheme.textMuted(context);
    return DdtTheme.taskCardGlass(
      context: context,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodySize,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            _noteSnippet(item.preview),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              color: DdtTheme.textSecondary(context),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '${item.authorLabel} · ${formatTaskDateTime(item.updatedAt.toLocal())}',
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

class _FolderHoverActions extends StatelessWidget {
  const _FolderHoverActions({required this.onRename, required this.onDelete});

  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = DdtTheme.textSecondary(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? DdtTheme.darkPickerSurface.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: DdtTheme.inputControlBorderRadius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : DdtTheme.borderStrong(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HoverIcon(
            tooltip: 'Переименовать',
            icon: DdtIcons.edit,
            onPressed: onRename,
            color: muted,
          ),
          _HoverIcon(
            tooltip: 'Удалить',
            icon: DdtIcons.trash,
            onPressed: onDelete,
            color: muted,
          ),
        ],
      ),
    );
  }
}

class _HoverIcon extends StatelessWidget {
  const _HoverIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  final String tooltip;
  final FaIconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: DdtTheme.radius,
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: DdtIcon(icon, size: 13.sp, color: color),
        ),
      ),
    );
  }
}

class _NotesStatus extends StatelessWidget {
  const _NotesStatus({required this.message, this.onRetry, this.onBack});

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: DdtShellMetrics.fixedTopPadding(
          context,
        ).add(EdgeInsets.only(top: 28.h)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: DdtTheme.style(fontSize: DdtTypography.bodySize),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Повторить')),
            if (onBack != null)
              TextButton(onPressed: onBack, child: const Text('К списку')),
          ],
        ),
      ),
    );
  }
}

class _NoteIconButton extends StatelessWidget {
  const _NoteIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(6.w),
            child: DdtIcon(
              icon,
              size: 14.sp,
              color: DdtTheme.sidePanelTextSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteTitleField extends StatelessWidget {
  const _NoteTitleField({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: style,
      cursorColor: accent,
      cursorWidth: 1.4,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        isCollapsed: true,
        isDense: true,
        filled: false,
        hintText: 'Название',
        hintStyle: style.copyWith(
          color: DdtTheme.textMuted(context).withValues(alpha: 0.45),
        ),
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
      ),
    );
  }
}

String _emptyMessage(NotesController notes) {
  if (notes.items.isEmpty) return 'Пока нет заметок';
  if (notes.filtersActive) return 'Нет заметок по выбранным фильтрам';
  return 'Пока нет заметок';
}

String _insideLabel(int count) {
  if (count == 0) return 'Пусто';
  return 'Внутри: $count';
}

String _noteSnippet(String preview) {
  var text = preview.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
  text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
  text = text.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
  text = text.replaceAll(RegExp(r'[#>*_~`|]'), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return 'Пустая заметка';
  return text;
}

Future<void> createNotesFolder(BuildContext context) {
  final notes = NotesCommands.current;
  if (notes == null) return Future<void>.value();
  return _createFolder(context, notes);
}

Future<void> _createNote(BuildContext context, NotesController notes) async {
  try {
    final note = await notes.create(
      title: 'Новая заметка',
      kind: NoteKind.note,
    );
    if (!context.mounted) return;
    context.push(RoutePaths.noteFor(note.id));
  } on NotesApiException catch (error) {
    if (!context.mounted) return;
    _showNoteError(context, error.message);
  }
}

Future<void> _createFolder(BuildContext context, NotesController notes) async {
  final title = await _askTitle(
    context,
    title: 'Новая папка',
    confirmLabel: 'Создать',
  );
  if (title == null || !context.mounted) return;
  try {
    await notes.create(title: title, kind: NoteKind.folder);
  } on NotesApiException catch (error) {
    if (!context.mounted) return;
    _showNoteError(context, error.message);
  }
}

void _showNoteError(BuildContext context, String message) {
  DdtToast.show(message: message, type: ToastType.error);
}

Color _dialogFill(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? DdtTheme.darkSurface : DdtTheme.lightSurface;
}

Future<String?> _askTitle(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NoteTitleDialog(
      title: title,
      confirmLabel: confirmLabel,
      initial: initial,
    ),
  );
}

Future<bool?> _confirmDelete(BuildContext context, {required String message}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: _dialogFill(context),
      title: Text(
        'Удалить?',
        style: DdtTheme.style(
          fontSize: DdtTypography.panelTitleSize,
          fontWeight: FontWeight.w600,
          color: DdtTheme.textPrimary(context),
        ),
      ),
      content: Text(
        message,
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
          child: Text('Удалить', style: TextStyle(color: DdtTheme.dangerColor)),
        ),
      ],
    ),
  );
}

class _NoteTitleDialog extends StatefulWidget {
  const _NoteTitleDialog({
    required this.title,
    required this.confirmLabel,
    required this.initial,
  });

  final String title;
  final String confirmLabel;
  final String initial;

  @override
  State<_NoteTitleDialog> createState() => _NoteTitleDialogState();
}

class _NoteTitleDialogState extends State<_NoteTitleDialog> {
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
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

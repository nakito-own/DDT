import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:nodeline/nodeline.dart';
import 'package:nodeline/src/ui/canvas/crossing_counter.dart';
import 'package:nodeline/src/ui/canvas/paint_profiler.dart';

import '../router/route_paths.dart';
import '../services/local_boards_store.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';

class BoardEditorPage extends StatefulWidget {
  const BoardEditorPage({super.key, required this.boardId});

  final String boardId;

  @override
  State<BoardEditorPage> createState() => _BoardEditorPageState();
}

class _BoardEditorPageState extends State<BoardEditorPage> {
  final _store = LocalBoardsStore.instance;
  FlowDrawController? _controller;
  EditorTool _tool = EditorTool.arrow;
  DiagramBoard? _board;
  bool _loading = true;
  bool _missing = false;
  bool _skipNext = false;
  Map<String, dynamic>? _pending;
  Timer? _saveTimer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BoardEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardId != widget.boardId) {
      _flush();
      _load();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    final pending = _pending;
    _pending = null;
    if (pending != null) {
      unawaited(_store.saveProject(widget.boardId, pending));
    }
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    await _store.prepare();
    if (!mounted || generation != _generation) return;
    final board = _store.find(widget.boardId);
    setState(() {
      _board = board;
      _missing = board == null;
      _loading = false;
      _skipNext = board?.project != null;
      _pending = null;
    });
  }

  void _onCanvasState(CanvasState state) {
    if (_skipNext) {
      _skipNext = false;
      return;
    }
    _pending = _projectFrom(state);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _flush);
  }

  void _flush() {
    _saveTimer?.cancel();
    final pending = _pending;
    _pending = null;
    if (pending == null) return;
    unawaited(_store.saveProject(widget.boardId, pending));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_missing || _board == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Доска не найдена',
              style: DdtTheme.style(
                fontSize: DdtTypography.bodyLargeSize,
                color: DdtTheme.textPrimary(context),
              ),
            ),
            SizedBox(height: DdtTheme.shellSizeOf(context, 12)),
            TextButton(
              onPressed: () => context.go(RoutePaths.boards),
              child: const Text('К списку досок'),
            ),
          ],
        ),
      );
    }

    final board = _board!;
    final project = board.project;

    return Stack(
      children: [
        FlowDraw(
          key: ValueKey(board.id),
          onControllerCreated: (controller) {
            _controller = controller;
            if (project != null) controller.loadProject(project);
          },
          onCanvasStateChanged: _onCanvasState,
          onToolStateChanged: (state) {
            if (!mounted || _tool == state.activeTool) return;
            setState(() => _tool = state.activeTool);
          },
          child: Stack(
            children: [
              const FlowDrawCanvas(showHud: false),
              Positioned(
                top: DdtTheme.shellSizeOf(context, 8),
                left: DdtTheme.shellSizeOf(context, 8),
                right: DdtTheme.shellSizeOf(context, 8),
                height: DdtTheme.shellSizeOf(context, 36),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _BoardToolbar(
                      activeTool: _tool,
                      onTool: (tool) => _controller?.setTool(tool),
                      onUndo: () => _controller?.undo(),
                      onRedo: () => _controller?.redo(),
                      onZoomIn: () => _controller?.zoomIn(),
                      onZoomOut: () => _controller?.zoomOut(),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BoardBackButton(
                            title: board.title,
                            onPressed: () {
                              _flush();
                              context.go(RoutePaths.boards);
                            },
                          ),
                          SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
                          const PaintProfilerToggle(anchored: false),
                          SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
                          const CrossingCounter(anchored: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoardBackButton extends StatelessWidget {
  const _BoardBackButton({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final height = DdtTheme.shellSizeOf(context, 36);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DdtTheme.glass(
          context: context,
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: DdtTheme.shellSizeOf(context, 10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DdtIcon(
                DdtIcons.back,
                size: DdtTheme.shellSizeOf(context, 14),
                color: DdtTheme.textPrimary(context),
              ),
              SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: DdtTheme.shellSizeOf(context, 180),
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    fontWeight: FontWeight.w600,
                    color: DdtTheme.textPrimary(context),
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

class _BoardTool {
  const _BoardTool(this.tool, this.icon, this.label, {this.turns = 0});

  final EditorTool tool;
  final FaIconData icon;
  final String label;
  final double turns;
}

class _BoardToolbar extends StatelessWidget {
  const _BoardToolbar({
    required this.activeTool,
    required this.onTool,
    required this.onUndo,
    required this.onRedo,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final EditorTool activeTool;
  final ValueChanged<EditorTool> onTool;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  static const _tools = <_BoardTool>[
    _BoardTool(EditorTool.arrow, FontAwesomeIcons.arrowPointer, 'Выбор'),
    _BoardTool(EditorTool.square, FontAwesomeIcons.square, 'Прямоугольник'),
    _BoardTool(EditorTool.circle, FontAwesomeIcons.circle, 'Круг'),
    _BoardTool(EditorTool.diamond, FontAwesomeIcons.diamond, 'Ромб'),
    _BoardTool(
      EditorTool.parallelogram,
      FontAwesomeIcons.square,
      'Параллелограмм',
      turns: 0.12,
    ),
    _BoardTool(EditorTool.forkJoin, FontAwesomeIcons.gripLines, 'Развилка'),
    _BoardTool(EditorTool.arrowTopRight, FontAwesomeIcons.arrowRight, 'Стрелка'),
    _BoardTool(EditorTool.line, FontAwesomeIcons.slash, 'Линия'),
    _BoardTool(EditorTool.pencil, FontAwesomeIcons.pencil, 'Карандаш'),
    _BoardTool(EditorTool.text, FontAwesomeIcons.font, 'Текст'),
  ];

  @override
  Widget build(BuildContext context) {
    final gap = DdtTheme.shellSizeOf(context, 2);
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.symmetric(
        horizontal: DdtTheme.shellSizeOf(context, 6),
        vertical: DdtTheme.shellSizeOf(context, 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
            for (final tool in _tools) ...[
              _BoardToolButton(
                icon: tool.icon,
                tooltip: tool.label,
                turns: tool.turns,
                selected: activeTool == tool.tool,
                onPressed: () => onTool(tool.tool),
              ),
              SizedBox(width: gap),
            ],
            _toolbarDivider(context),
            _BoardToolButton(
              icon: FontAwesomeIcons.rotateLeft,
              tooltip: 'Отменить',
              onPressed: onUndo,
            ),
            SizedBox(width: gap),
            _BoardToolButton(
              icon: FontAwesomeIcons.rotateRight,
              tooltip: 'Повторить',
              onPressed: onRedo,
            ),
            _toolbarDivider(context),
            _BoardToolButton(
              icon: FontAwesomeIcons.magnifyingGlassMinus,
              tooltip: 'Уменьшить',
              onPressed: onZoomOut,
            ),
            SizedBox(width: gap),
            _BoardToolButton(
              icon: FontAwesomeIcons.magnifyingGlassPlus,
              tooltip: 'Увеличить',
              onPressed: onZoomIn,
            ),
        ],
      ),
    );
  }
}

Widget _toolbarDivider(BuildContext context) {
  return Container(
    width: 1,
    height: DdtTheme.shellSizeOf(context, 18),
    margin: EdgeInsets.symmetric(
      horizontal: DdtTheme.shellSizeOf(context, 6),
    ),
    color: DdtTheme.borderSubtle(context),
  );
}

class _BoardToolButton extends StatelessWidget {
  const _BoardToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.turns = 0,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;
  final double turns;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : DdtTheme.textPrimary(context);
    final size = DdtTheme.shellSizeOf(context, 28);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? DdtTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(
              DdtTheme.shellSizeOf(context, 8),
            ),
          ),
          child: Transform.rotate(
            angle: turns * 6.283185307179586,
            child: DdtIcon(
              icon,
              size: DdtTheme.shellSizeOf(context, 13),
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _projectFrom(CanvasState state) {
  return {
    'viewport': {
      'offset': [state.viewportOffset.dx, state.viewportOffset.dy],
      'zoom': state.viewportZoom,
    },
    'defaultFontFamily': state.defaultFontFamily,
    'defaultFontSize': state.defaultFontSize,
    'nodes': state.nodes.values.map((node) => node.toJson()).toList(),
    'drawingObjects': state.drawingObjects.values
        .map((object) => object.toJson())
        .toList(),
    'comments': state.comments.values.map((comment) => comment.toJson()).toList(),
  };
}

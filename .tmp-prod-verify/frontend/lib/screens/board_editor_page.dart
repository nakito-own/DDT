import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nodeline/nodeline.dart';
import 'package:nodeline/src/ui/canvas/crossing_counter.dart';
import 'package:nodeline/src/ui/canvas/paint_profiler.dart';

import '../router/route_paths.dart';
import '../services/boards_store.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/board_toolbar.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_shell_metrics.dart';

class BoardEditorPage extends StatefulWidget {
  const BoardEditorPage({super.key, required this.boardId});

  final String boardId;

  @override
  State<BoardEditorPage> createState() => _BoardEditorPageState();
}

class _BoardEditorPageState extends State<BoardEditorPage> {
  final _store = BoardsStore.instance;
  FlowDrawController? _controller;
  EditorTool _tool = EditorTool.arrow;
  DiagramBoard? _board;
  bool _loading = true;
  bool _missing = false;
  String? _error;
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
    try {
      final board = await _store.find(widget.boardId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _board = board;
        _missing = board == null;
        _error = null;
        _loading = false;
        _skipNext = board?.project != null;
        _pending = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _board = null;
        _missing = false;
        _loading = false;
        _error = error is BoardsApiException
            ? error.message
            : 'Не удалось открыть доску';
      });
    }
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
    final boardId = widget.boardId;
    unawaited(_persist(boardId, pending));
  }

  Future<void> _persist(String boardId, Map<String, dynamic> project) async {
    try {
      await _store.saveProject(boardId, project);
    } catch (error) {
      if (!mounted) return;
      final message = error is BoardsApiException
          ? error.message
          : 'Не удалось сохранить доску';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _close() {
    _flush();
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RoutePaths.boards);
  }

  @override
  Widget build(BuildContext context) {
    final top = DdtShellMetrics.maybeOf(context)?.topReserve ?? 0;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: _buildEditor(context),
    );
  }

  Widget _buildEditor(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _missing || _board == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'Доска не найдена',
              style: DdtTheme.style(
                fontSize: DdtTypography.bodyLargeSize,
                color: DdtTheme.textPrimary(context),
              ),
            ),
            SizedBox(height: DdtTheme.shellSizeOf(context, 12)),
            TextButton(
              onPressed: _close,
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
              Positioned.fill(
                child: BoardToolbar(
                  activeTool: _tool,
                  onTool: (tool) => _controller?.setTool(tool),
                  onUndo: () => _controller?.undo(),
                  onRedo: () => _controller?.redo(),
                  onZoomIn: () => _controller?.zoomIn(),
                  onZoomOut: () => _controller?.zoomOut(),
                  onResetZoom: () => _controller?.resetZoom(),
                  onCenter: () => _controller?.centerView(),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BoardBackButton(
                        title: board.title,
                        onPressed: _close,
                      ),
                      SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
                      const PaintProfilerToggle(anchored: false),
                      SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
                      const CrossingCounter(anchored: false),
                    ],
                  ),
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

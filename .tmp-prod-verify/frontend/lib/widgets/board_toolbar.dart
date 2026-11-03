import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nodeline/nodeline.dart';
import 'package:nodeline/src/core/utils/svg_exporter.dart';
import 'package:nodeline/src/core/utils/svg_open.dart';
import 'package:nodeline/src/ui/canvas/rich_text_editing_controller.dart';
import 'package:nodeline/src/ui/shared/active_text_editing.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_icon.dart';

/// Glass toolbar with every drawing control the board editor can run.
class BoardToolbar extends StatefulWidget {
  const BoardToolbar({
    super.key,
    required this.activeTool,
    required this.onTool,
    required this.onUndo,
    required this.onRedo,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onCenter,
    this.leading,
  });

  /// Back button and canvas badges, kept in the top band with the other groups.
  final Widget? leading;

  final EditorTool activeTool;
  final ValueChanged<EditorTool> onTool;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final VoidCallback onCenter;

  @override
  State<BoardToolbar> createState() => _BoardToolbarState();
}

class _BoardToolbarState extends State<BoardToolbar> {
  OverlayEntry? _menu;
  double _fitMargin = kDefaultFitMargin;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _closeMenu() {
    _menu?.remove();
    _menu = null;
  }

  void _openMenu(BuildContext anchor, Widget panel) {
    _closeMenu();
    final box = anchor.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(anchor);
    const panelWidth = 280.0;
    var left = origin.dx;
    if (left + panelWidth > screen.width - 12) {
      left = screen.width - panelWidth - 12;
    }
    if (left < 12) left = 12;
    final top = origin.dy + box.size.height + 6;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: panelWidth,
              child: DdtTheme.contextMenuGlass(
                context: overlayContext,
                padding: EdgeInsets.all(DdtTheme.shellSizeOf(overlayContext, 10)),
                child: panel,
              ),
            ),
          ],
        );
      },
    );
    _menu = entry;
    Overlay.of(anchor, rootOverlay: true).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ToolBloc, ToolState>(
      builder: (context, tool) {
        return BlocBuilder<CanvasBloc, CanvasState>(
          builder: (context, canvas) {
            return BlocBuilder<SelectionBloc, SelectionState>(
              builder: (context, selection) {
                return ValueListenableBuilder<RichTextEditingController?>(
                  valueListenable: activeTextEditing,
                  builder: (context, editor, _) {
                    if (editor == null) {
                      return _bar(context, tool, canvas, selection, null);
                    }
                    return AnimatedBuilder(
                      animation: editor,
                      builder: (context, _) =>
                          _bar(context, tool, canvas, selection, editor),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _bar(
    BuildContext context,
    ToolState tool,
    CanvasState canvas,
    SelectionState selection,
    RichTextEditingController? editor,
  ) {
    final gap = DdtTheme.shellSizeOf(context, 2);
    final font = _fontTarget(selection, canvas);
    final colorIds = _colorableIds(selection, canvas);
    final arrowIds = _arrowIds(selection, canvas);
    final hasSelection = selection.selectedNodeIds.isNotEmpty ||
        selection.selectedDrawingObjectIds.isNotEmpty;
    final anyDirected = arrowIds.any((id) {
      final object = canvas.drawingObjects[id];
      return object is ArrowObject && object.arrowHead != ArrowHeadType.none;
    });
    final rich = editor?.selectionStyle();

    final edge = DdtTheme.shellSizeOf(context, 8);
    final styleButtons = <Widget>[
      Builder(
        builder: (anchor) => _BoardBarButton(
          icon: FontAwesomeIcons.minus,
          tooltip: 'Стиль линии',
          onPressed: () => _openLineStyle(anchor, tool.lineStyle),
        ),
      ),
      Builder(
        builder: (anchor) => _BoardBarButton(
          icon: FontAwesomeIcons.font,
          tooltip: font.editingSelection
              ? 'Шрифт выделения'
              : 'Шрифт по умолчанию',
          onPressed: () => _openFont(anchor, canvas, font),
        ),
      ),
      _BoardBarButton(
        icon: FontAwesomeIcons.bold,
        tooltip: 'Жирный',
        selected: rich?.bold ?? false,
        enabled: editor != null,
        onPressed: editor == null
            ? null
            : () => editor.applyToSelection(
                  bold: Attr.set(!(rich?.bold ?? false)),
                ),
      ),
      _BoardBarButton(
        icon: FontAwesomeIcons.italic,
        tooltip: 'Курсив',
        selected: rich?.italic ?? false,
        enabled: editor != null,
        onPressed: editor == null
            ? null
            : () => editor.applyToSelection(
                  italic: Attr.set(!(rich?.italic ?? false)),
                ),
      ),
      Builder(
        builder: (anchor) => _BoardBarButton(
          icon: FontAwesomeIcons.fillDrip,
          tooltip: 'Цвет',
          enabled: colorIds.isNotEmpty,
          onPressed: colorIds.isEmpty
              ? null
              : () => _openColor(anchor, canvas, colorIds),
        ),
      ),
      _BoardBarButton(
        icon: anyDirected
            ? FontAwesomeIcons.arrowRight
            : FontAwesomeIcons.minus,
        tooltip: anyDirected ? 'Сделать линией' : 'Сделать стрелкой',
        enabled: arrowIds.isNotEmpty,
        onPressed: arrowIds.isEmpty
            ? null
            : () => context.read<CanvasBloc>().add(
                  ObjectsArrowHeadChanged(
                    arrowIds,
                    anyDirected ? ArrowHeadType.none : ArrowHeadType.triangle,
                  ),
                ),
      ),
    ];
    final layoutButtons = <Widget>[
      _BoardBarButton(
        icon: FontAwesomeIcons.wandMagicSparkles,
        tooltip: 'Выровнять',
        onPressed: () =>
            context.read<CanvasBloc>().add(const AutoLayoutRequested()),
      ),
      _BoardBarButton(
        icon: FontAwesomeIcons.bezierCurve,
        tooltip: 'Вдоль контура',
        onPressed: () =>
            context.read<CanvasBloc>().add(const LayoutAlongGuideRequested()),
      ),
      _BoardBarButton(
        icon: FontAwesomeIcons.rightLeft,
        tooltip: 'Поменять местами',
        onPressed: () => context.read<CanvasBloc>().add(const SwapRequested()),
      ),
      Builder(
        builder: (anchor) => _BoardBarButton(
          icon: FontAwesomeIcons.upRightAndDownLeftFromCenter,
          tooltip: 'Подогнать по содержимому',
          onPressed: () => _openFit(anchor),
        ),
      ),
      _BoardBarButton(
        icon: FontAwesomeIcons.borderAll,
        tooltip: canvas.showGrid ? 'Скрыть сетку' : 'Показать сетку',
        selected: canvas.showGrid,
        onPressed: () => context.read<CanvasBloc>().add(const GridToggled()),
      ),
    ];
    final editButtons = <Widget>[
      _BoardBarButton(
        icon: FontAwesomeIcons.rotateLeft,
        tooltip: 'Отменить',
        enabled: canvas.undoStack.isNotEmpty,
        onPressed: canvas.undoStack.isEmpty ? null : widget.onUndo,
      ),
      _BoardBarButton(
        icon: FontAwesomeIcons.rotateRight,
        tooltip: 'Повторить',
        enabled: canvas.redoStack.isNotEmpty,
        onPressed: canvas.redoStack.isEmpty ? null : widget.onRedo,
      ),
      _BoardBarButton(
        icon: DdtIcons.trash,
        tooltip: 'Удалить',
        enabled: hasSelection,
        onPressed: hasSelection
            ? () {
                context.read<CanvasBloc>().add(ObjectsRemoved(
                      nodeIds: selection.selectedNodeIds,
                      drawingObjectIds: selection.selectedDrawingObjectIds,
                    ));
                context.read<SelectionBloc>().add(SelectionCleared());
              }
            : null,
      ),
    ];
    final viewButtons = <Widget>[
      _BoardBarButton(
        icon: FontAwesomeIcons.magnifyingGlassMinus,
        tooltip: 'Уменьшить',
        onPressed: widget.onZoomOut,
      ),
      _BoardBarButton(
        icon: FontAwesomeIcons.magnifyingGlassPlus,
        tooltip: 'Увеличить',
        onPressed: widget.onZoomIn,
      ),
      _BoardBarButton(
        icon: FontAwesomeIcons.arrowsToDot,
        tooltip: 'Масштаб 100%',
        onPressed: widget.onResetZoom,
      ),
      _BoardBarButton(
        icon: FontAwesomeIcons.crosshairs,
        tooltip: 'По центру',
        onPressed: widget.onCenter,
      ),
    ];
    final exchangeButtons = <Widget>[
      _BoardBarButton(
        icon: FontAwesomeIcons.code,
        tooltip: 'Mermaid',
        onPressed: () => _openMermaid(context),
      ),
      _BoardBarButton(
        icon: DdtIcons.fileImage,
        tooltip: 'Экспорт SVG',
        onPressed: () => _exportSvg(context),
      ),
    ];

    return Stack(
      children: [
        Positioned(
          top: edge,
          left: edge,
          right: edge,
          child: Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: DdtTheme.shellSizeOf(context, 8),
            runSpacing: DdtTheme.shellSizeOf(context, 8),
            children: [
              if (widget.leading != null) widget.leading!,
              _cluster(context, styleButtons, gap),
              _cluster(context, layoutButtons, gap),
              _cluster(context, editButtons, gap),
              _cluster(context, viewButtons, gap),
              _cluster(context, exchangeButtons, gap),
            ],
          ),
        ),
        Positioned(
          left: edge,
          top: edge + DdtTheme.shellSizeOf(context, 96),
          bottom: edge,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _cluster(
              context,
              [
                for (final item in _tools)
                  _BoardBarButton(
                    icon: item.icon,
                    tooltip: item.label,
                    turns: item.turns,
                    selected: widget.activeTool == item.tool,
                    onPressed: () => widget.onTool(item.tool),
                  ),
              ],
              gap,
              axis: Axis.vertical,
            ),
          ),
        ),
      ],
    );
  }

  void _openLineStyle(BuildContext anchor, LineStyle current) {
    _openMenu(
      anchor,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final style in LineStyle.values)
            _MenuRow(
              label: _lineStyleLabel(style),
              selected: style == current,
              leading: CustomPaint(
                size: const Size(36, 14),
                painter: _LinePreviewPainter(
                  style,
                  DdtTheme.textPrimary(anchor),
                ),
              ),
              onTap: () {
                _applyLineStyle(style);
                _closeMenu();
              },
            ),
        ],
      ),
    );
  }

  void _applyLineStyle(LineStyle style) {
    final canvas = context.read<CanvasBloc>();
    final selected =
        context.read<SelectionBloc>().state.selectedDrawingObjectIds;
    context.read<ToolBloc>().add(LineStyleSelected(style));
    final ids = selected.isNotEmpty
        ? selected
        : canvas.state.drawingObjects.keys.toSet();
    if (ids.isEmpty) return;
    canvas.add(ObjectsLineStyleChanged(ids, style));
  }

  void _openFont(BuildContext anchor, CanvasState canvas, _FontTarget font) {
    _openMenu(
      anchor,
      _FontPanel(
        target: font,
        onChanged: (family, size) {
          final canvasBloc = context.read<CanvasBloc>();
          if (font.editingSelection) {
            canvasBloc.add(ObjectFontChanged(
              font.ids,
              fontFamily: family,
              fontSize: size,
            ));
          } else {
            canvasBloc.add(GlobalFontChanged(
              fontFamily: family,
              fontSize: size,
            ));
          }
        },
        onReset: font.editingSelection && font.customized
            ? () => context.read<CanvasBloc>().add(ObjectFontReset(font.ids))
            : null,
      ),
    );
  }

  void _openColor(
    BuildContext anchor,
    CanvasState canvas,
    Set<String> ids,
  ) {
    Color? fill;
    Color stroke = DdtTheme.textPrimary(anchor);
    for (final id in ids) {
      final object = canvas.drawingObjects[id];
      final nextFill = switch (object) {
        RectangleObject(:final fillColor) => fillColor,
        CircleObject(:final fillColor) => fillColor,
        DiamondObject(:final fillColor) => fillColor,
        ParallelogramObject(:final fillColor) => fillColor,
        ForkJoinObject(:final fillColor) => fillColor,
        _ => null,
      };
      final nextStroke = switch (object) {
        RectangleObject(:final strokeColor) => strokeColor,
        CircleObject(:final strokeColor) => strokeColor,
        DiamondObject(:final strokeColor) => strokeColor,
        ParallelogramObject(:final strokeColor) => strokeColor,
        ForkJoinObject(:final strokeColor) => strokeColor,
        ArrowObject(:final strokeColor) => strokeColor,
        LineObject(:final strokeColor) => strokeColor,
        _ => null,
      };
      if (nextFill != null) fill = nextFill;
      if (nextStroke != null) stroke = nextStroke;
    }

    _openMenu(
      anchor,
      _ColorPanel(
        fill: fill,
        stroke: stroke,
        onFill: (color) {
          context.read<CanvasBloc>().add(ObjectColorsChanged(
                ids,
                fillColor: color,
                clearFill: color == null,
              ));
        },
        onStroke: (color) {
          context.read<CanvasBloc>().add(ObjectColorsChanged(
                ids,
                strokeColor: color,
              ));
        },
      ),
    );
  }

  void _openFit(BuildContext anchor) {
    _openMenu(
      anchor,
      _FitPanel(
        margin: _fitMargin,
        onMargin: (value) => setState(() => _fitMargin = value),
        onFit: () {
          final selected =
              context.read<SelectionBloc>().state.selectedDrawingObjectIds;
          context.read<CanvasBloc>().add(
                NodesFittedToContent(selected, margin: _fitMargin),
              );
          _closeMenu();
        },
      ),
    );
  }

  Future<void> _openMermaid(BuildContext context) async {
    final canvas = context.read<CanvasBloc>();
    final selection = context.read<SelectionBloc>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _MermaidDialog(
        canvas: canvas,
        selection: selection,
      ),
    );
  }

  Future<void> _exportSvg(BuildContext context) async {
    final canvas = context.read<CanvasBloc>().state;
    final svg = SvgExporter.export(
      canvas.drawingObjects,
      defaultFontFamily: canvas.defaultFontFamily,
      defaultFontSize: canvas.defaultFontSize,
    );
    if (!context.mounted) return;
    if (svg.isEmpty) {
      _toast(context, 'Нечего экспортировать');
      return;
    }
    try {
      await openSvgExport(svg);
      if (context.mounted) _toast(context, 'SVG скачан');
    } catch (_) {
      if (context.mounted) _toast(context, 'Не удалось экспортировать SVG');
    }
  }
}

class _BoardTool {
  const _BoardTool(this.tool, this.icon, this.label, {this.turns = 0});

  final EditorTool tool;
  final FaIconData icon;
  final String label;
  final double turns;
}

const _tools = <_BoardTool>[
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
  _BoardTool(EditorTool.figure, FontAwesomeIcons.shapes, 'Фигура'),
  _BoardTool(EditorTool.comment, FontAwesomeIcons.comment, 'Комментарий'),
];

class _BoardBarButton extends StatelessWidget {
  const _BoardBarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
    this.turns = 0,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool enabled;
  final double turns;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? DdtTheme.textMuted(context)
        : selected
            ? Colors.white
            : DdtTheme.textPrimary(context);
    final size = DdtTheme.shellSizeOf(context, 28);
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected && enabled
                  ? DdtTheme.primaryColor
                  : Colors.transparent,
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
      ),
    );
  }
}

Widget _cluster(
  BuildContext context,
  List<Widget> children,
  double gap, {
  Axis axis = Axis.horizontal,
}) {
  final padded = <Widget>[
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(width: axis == Axis.horizontal ? gap : 0, height: axis == Axis.vertical ? gap : 0),
      children[i],
    ],
  ];
  return DdtTheme.glass(
    context: context,
    padding: EdgeInsets.symmetric(
      horizontal: DdtTheme.shellSizeOf(context, 6),
      vertical: DdtTheme.shellSizeOf(context, 4),
    ),
    child: axis == Axis.horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: padded)
        : Column(mainAxisSize: MainAxisSize.min, children: padded),
  );
}

class _FontTarget {
  const _FontTarget({
    required this.ids,
    required this.family,
    required this.size,
    required this.globalFamily,
    required this.globalSize,
    required this.editingSelection,
    required this.customized,
  });

  final Set<String> ids;
  final String family;
  final double size;
  final String globalFamily;
  final double globalSize;
  final bool editingSelection;
  final bool customized;
}

_FontTarget _fontTarget(SelectionState selection, CanvasState canvas) {
  var hasText = false;
  var customized = false;
  var family = canvas.defaultFontFamily;
  var size = canvas.defaultFontSize;
  var gotFirst = false;
  final ids = <String>{};

  for (final id in selection.selectedDrawingObjectIds) {
    final object = canvas.drawingObjects[id];
    TextStyle? style;
    var objectCustomized = false;
    if (object is RectangleObject) {
      style = object.textStyle;
      objectCustomized = object.fontCustomized;
    } else if (object is CircleObject) {
      style = object.textStyle;
      objectCustomized = object.fontCustomized;
    } else if (object is DiamondObject) {
      style = object.textStyle;
      objectCustomized = object.fontCustomized;
    } else if (object is ParallelogramObject) {
      style = object.textStyle;
      objectCustomized = object.fontCustomized;
    } else if (object is TextObject) {
      style = object.style;
      objectCustomized = true;
    } else {
      continue;
    }
    hasText = true;
    ids.add(id);
    if (objectCustomized) customized = true;
    if (!gotFirst) {
      gotFirst = true;
      final resolved = effectiveShapeTextStyle(
        style: style,
        customized: objectCustomized,
        defaultFamily: canvas.defaultFontFamily,
        defaultSize: canvas.defaultFontSize,
      );
      family = resolved.fontFamily ?? canvas.defaultFontFamily;
      size = resolved.fontSize ?? canvas.defaultFontSize;
    }
  }

  if (!hasText) {
    return _FontTarget(
      ids: const {},
      family: canvas.defaultFontFamily,
      size: canvas.defaultFontSize,
      globalFamily: canvas.defaultFontFamily,
      globalSize: canvas.defaultFontSize,
      editingSelection: false,
      customized: false,
    );
  }
  return _FontTarget(
    ids: ids,
    family: family,
    size: size,
    globalFamily: canvas.defaultFontFamily,
    globalSize: canvas.defaultFontSize,
    editingSelection: true,
    customized: customized,
  );
}

Set<String> _colorableIds(SelectionState selection, CanvasState canvas) {
  return selection.selectedDrawingObjectIds.where((id) {
    final object = canvas.drawingObjects[id];
    return object is RectangleObject ||
        object is CircleObject ||
        object is DiamondObject ||
        object is ParallelogramObject ||
        object is ForkJoinObject ||
        object is ArrowObject ||
        object is LineObject;
  }).toSet();
}

Set<String> _arrowIds(SelectionState selection, CanvasState canvas) {
  return selection.selectedDrawingObjectIds.where((id) {
    return canvas.drawingObjects[id] is ArrowObject;
  }).toSet();
}

String _lineStyleLabel(LineStyle style) {
  return switch (style) {
    LineStyle.solid => 'Сплошная',
    LineStyle.dashed => 'Штриховая',
    LineStyle.dotted => 'Пунктир',
    LineStyle.rough => 'Шероховатая',
  };
}

const _presetLabels = <String, String>{
  'Title': 'Заголовок',
  'Heading 1': 'Заголовок 1',
  'Heading 2': 'Заголовок 2',
  'Subtitle': 'Подзаголовок',
  'Body': 'Основной',
  'Leaf node': 'Лист',
  'Caption': 'Подпись',
};

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.leading,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: DdtTheme.shellSizeOf(context, 6),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
              ],
              Expanded(
                child: Text(
                  label,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: DdtTheme.textPrimary(context),
                  ),
                ),
              ),
              if (selected)
                DdtIcon(
                  DdtIcons.check,
                  size: DdtTheme.shellSizeOf(context, 12),
                  color: DdtTheme.primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontPanel extends StatefulWidget {
  const _FontPanel({
    required this.target,
    required this.onChanged,
    this.onReset,
  });

  final _FontTarget target;
  final void Function(String family, double size) onChanged;
  final VoidCallback? onReset;

  @override
  State<_FontPanel> createState() => _FontPanelState();
}

class _FontPanelState extends State<_FontPanel> {
  late String _family = widget.target.family;
  late double _size = widget.target.size;

  void _emit(String family, double size) {
    setState(() {
      _family = family;
      _size = size.clamp(6, 96);
    });
    widget.onChanged(_family, _size);
  }

  @override
  Widget build(BuildContext context) {
    final globalSize = widget.target.globalSize;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: SingleChildScrollView(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.target.editingSelection
              ? 'Шрифт выделения'
              : 'Шрифт по умолчанию',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.textPrimary(context),
          ),
        ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 8)),
        for (final preset in kTextStylePresets)
          _MenuRow(
            label: _presetLabels[preset.label] ?? preset.label,
            selected: _family == widget.target.globalFamily &&
                (preset.sizeFor(globalSize) - _size).abs() < 0.5,
            onTap: () => _emit(
              widget.target.globalFamily,
              preset.sizeFor(globalSize),
            ),
          ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 6)),
        for (final family in kEditorFontFamilies)
          _MenuRow(
            label: family,
            selected: family == _family,
            onTap: () => _emit(family, _size),
          ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 6)),
        Row(
          children: [
            Text(
              'Размер ${_size.round()}',
              style: DdtTheme.style(
                fontSize: DdtTypography.bodySize,
                color: DdtTheme.textPrimary(context),
              ),
            ),
            const Spacer(),
            _BoardBarButton(
              icon: DdtIcons.remove,
              tooltip: 'Меньше',
              onPressed: () => _emit(_family, _size - 1),
            ),
            _BoardBarButton(
              icon: DdtIcons.add,
              tooltip: 'Больше',
              onPressed: () => _emit(_family, _size + 1),
            ),
          ],
        ),
        if (widget.onReset != null)
          _MenuRow(
            label: 'Сбросить к общему',
            onTap: widget.onReset!,
          ),
      ],
        ),
      ),
    );
  }
}

class _ColorPanel extends StatefulWidget {
  const _ColorPanel({
    required this.fill,
    required this.stroke,
    required this.onFill,
    required this.onStroke,
  });

  final Color? fill;
  final Color stroke;
  final ValueChanged<Color?> onFill;
  final ValueChanged<Color> onStroke;

  @override
  State<_ColorPanel> createState() => _ColorPanelState();
}

class _ColorPanelState extends State<_ColorPanel> {
  late Color? _fill = widget.fill;
  late Color _stroke = widget.stroke;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Заливка',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.textPrimary(context),
          ),
        ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 6)),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _swatch(
              context,
              color: null,
              selected: _fill == null,
              onTap: () {
                setState(() => _fill = null);
                widget.onFill(null);
              },
            ),
            for (final color in ColorPicker.presetColors)
              _swatch(
                context,
                color: color,
                selected: _fill?.toARGB32() == color.toARGB32(),
                onTap: () {
                  setState(() => _fill = color);
                  widget.onFill(color);
                },
              ),
          ],
        ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 10)),
        Text(
          'Обводка',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.textPrimary(context),
          ),
        ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 6)),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final color in ColorPicker.presetColors)
              _swatch(
                context,
                color: color,
                selected: _stroke.toARGB32() == color.toARGB32(),
                onTap: () {
                  setState(() => _stroke = color);
                  widget.onStroke(color);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _swatch(
    BuildContext context, {
    required Color? color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color ?? Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? DdtTheme.primaryColor
                  : DdtTheme.borderSubtle(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: color == null
              ? Icon(
                  Icons.block,
                  size: 14,
                  color: DdtTheme.textMuted(context),
                )
              : null,
        ),
      ),
    );
  }
}

class _FitPanel extends StatefulWidget {
  const _FitPanel({
    required this.margin,
    required this.onMargin,
    required this.onFit,
  });

  final double margin;
  final ValueChanged<double> onMargin;
  final VoidCallback onFit;

  @override
  State<_FitPanel> createState() => _FitPanelState();
}

class _FitPanelState extends State<_FitPanel> {
  late double _margin = widget.margin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Подогнать по содержимому',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.textPrimary(context),
          ),
        ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 8)),
        Row(
          children: [
            Text(
              'Поле ${_margin.round()}',
              style: DdtTheme.style(
                fontSize: DdtTypography.bodySize,
                color: DdtTheme.textPrimary(context),
              ),
            ),
            const Spacer(),
            _BoardBarButton(
              icon: DdtIcons.remove,
              tooltip: 'Меньше',
              onPressed: () {
                final next = (_margin - 2).clamp(0, 80).toDouble();
                setState(() => _margin = next);
                widget.onMargin(next);
              },
            ),
            _BoardBarButton(
              icon: DdtIcons.add,
              tooltip: 'Больше',
              onPressed: () {
                final next = (_margin + 2).clamp(0, 80).toDouble();
                setState(() => _margin = next);
                widget.onMargin(next);
              },
            ),
          ],
        ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 8)),
        _MenuRow(label: 'Подогнать', onTap: widget.onFit),
      ],
    );
  }
}

class _MermaidDialog extends StatefulWidget {
  const _MermaidDialog({required this.canvas, required this.selection});

  final CanvasBloc canvas;
  final SelectionBloc selection;

  @override
  State<_MermaidDialog> createState() => _MermaidDialogState();
}

class _MermaidDialogState extends State<_MermaidDialog> {
  final _import = TextEditingController();
  final _export = TextEditingController();
  var _exporting = false;

  @override
  void dispose() {
    _import.dispose();
    _export.dispose();
    super.dispose();
  }

  void _showExport() {
    final selected = widget.selection.state.selectedDrawingObjectIds;
    _export.text = MermaidExporter.export(
      widget.canvas.state.drawingObjects,
      selectedIds: selected.isNotEmpty ? selected : null,
    );
    setState(() => _exporting = true);
  }

  void _importDiagram() {
    final text = _import.text.trim();
    if (text.isEmpty) return;
    try {
      widget.canvas.add(ProjectLoaded(MermaidImporter.import(text)));
      Navigator.of(context).pop();
      _toast(context, 'Диаграмма импортирована');
    } catch (_) {
      _toast(context, 'Не удалось разобрать Mermaid');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: DdtTheme.contextMenuGlass(
        context: context,
        padding: EdgeInsets.all(DdtTheme.shellSizeOf(context, 16)),
        child: SizedBox(
          width: 420,
          child: _exporting ? _exportBody(context) : _importBody(context),
        ),
      ),
    );
  }

  Widget _importBody(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mermaid',
          style: DdtTheme.style(
            fontSize: DdtTypography.sectionTitleSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.textPrimary(context),
          ),
        ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 4)),
        Text(
          'Вставьте flowchart, чтобы заменить доску',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            color: DdtTheme.textSecondary(context),
          ),
        ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 10)),
        _mermaidField(context, _import, readOnly: false),
        SizedBox(height: DdtTheme.shellSizeOf(context, 10)),
        _MenuRow(label: 'Показать на доске', onTap: _importDiagram),
        _MenuRow(label: 'Экспортировать текущую', onTap: _showExport),
      ],
    );
  }

  Widget _exportBody(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Экспорт Mermaid',
          style: DdtTheme.style(
            fontSize: DdtTypography.sectionTitleSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.textPrimary(context),
          ),
        ),
        SizedBox(height: DdtTheme.shellSizeOf(context, 10)),
        _mermaidField(context, _export, readOnly: true),
        SizedBox(height: DdtTheme.shellSizeOf(context, 10)),
        _MenuRow(
          label: 'Копировать',
          onTap: () {
            Clipboard.setData(ClipboardData(text: _export.text));
            Navigator.of(context).pop();
            _toast(context, 'Mermaid скопирован');
          },
        ),
        _MenuRow(
          label: 'Назад',
          onTap: () => setState(() => _exporting = false),
        ),
      ],
    );
  }
}

Widget _mermaidField(
  BuildContext context,
  TextEditingController controller, {
  required bool readOnly,
}) {
  return TextField(
    controller: controller,
    readOnly: readOnly,
    maxLines: 8,
    style: DdtTheme.style(
      fontSize: DdtTypography.labelSize,
      color: DdtTheme.textPrimary(context),
    ).copyWith(fontFamily: 'monospace'),
    decoration: InputDecoration(
      isDense: true,
      hintText: readOnly ? null : 'graph TD\n  A[Старт] --> B[Конец]',
      hintStyle: DdtTheme.style(
        fontSize: DdtTypography.labelSize,
        color: DdtTheme.textMuted(context),
      ),
      filled: true,
      fillColor: DdtTheme.borderSubtle(context).withValues(alpha: 0.25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DdtTheme.shellSizeOf(context, 8)),
        borderSide: BorderSide(color: DdtTheme.borderSubtle(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DdtTheme.shellSizeOf(context, 8)),
        borderSide: BorderSide(color: DdtTheme.borderSubtle(context)),
      ),
    ),
  );
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ),
  );
}

class _LinePreviewPainter extends CustomPainter {
  _LinePreviewPainter(this.style, this.color);

  final LineStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    switch (style) {
      case LineStyle.solid:
        canvas.drawLine(Offset.zero, Offset(size.width, y), paint);
      case LineStyle.dashed:
        var x = 0.0;
        while (x < size.width) {
          canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
          x += 8;
        }
      case LineStyle.dotted:
        var x = 1.0;
        final dots = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        while (x < size.width) {
          canvas.drawCircle(Offset(x, y), 1.2, dots);
          x += 4;
        }
      case LineStyle.rough:
        final path = Path()..moveTo(0, y);
        var x = 0.0;
        var flip = false;
        while (x < size.width) {
          x += 4;
          flip = !flip;
          path.lineTo(x, y + (flip ? 1.2 : -1.2));
        }
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_LinePreviewPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.color != color;
}

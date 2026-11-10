part of 'tool_bloc.dart';

sealed class ToolEvent extends Equatable {
  const ToolEvent();

  @override
  List<Object> get props => [];
}

/// Event dispatched when a new tool is selected from the toolbar.
final class ToolSelected extends ToolEvent {
  final EditorTool tool;

  const ToolSelected(this.tool);

  @override
  List<Object> get props => [tool];
}

/// Event dispatched when a new line style is selected from the toolbar.
final class LineStyleSelected extends ToolEvent {
  final LineStyle lineStyle;

  const LineStyleSelected(this.lineStyle);

  @override
  List<Object> get props => [lineStyle];
}

final class PathTypeSelected extends ToolEvent {
  final LinkPathType pathType;

  const PathTypeSelected(this.pathType);

  @override
  List<Object> get props => [pathType];
}

final class ArrowHeadSelected extends ToolEvent {
  final ArrowHeadType arrowHead;

  const ArrowHeadSelected(this.arrowHead);

  @override
  List<Object> get props => [arrowHead];
}

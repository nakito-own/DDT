part of 'tool_bloc.dart';

class ToolState extends Equatable {
  final EditorTool activeTool;
  final LineStyle lineStyle;
  final LinkPathType pathType;
  final ArrowHeadType arrowHead;

  const ToolState({
    this.activeTool = EditorTool.arrow,
    this.lineStyle = LineStyle.solid,
    this.pathType = LinkPathType.orthogonal,
    this.arrowHead = ArrowHeadType.triangle,
  });

  ToolState copyWith({
    EditorTool? activeTool,
    LineStyle? lineStyle,
    LinkPathType? pathType,
    ArrowHeadType? arrowHead,
  }) {
    return ToolState(
      activeTool: activeTool ?? this.activeTool,
      lineStyle: lineStyle ?? this.lineStyle,
      pathType: pathType ?? this.pathType,
      arrowHead: arrowHead ?? this.arrowHead,
    );
  }

  @override
  List<Object> get props => [activeTool, lineStyle, pathType, arrowHead];
}

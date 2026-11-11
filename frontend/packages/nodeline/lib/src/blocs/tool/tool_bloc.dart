import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:nodeline/src/models/drawing_entities.dart';
import 'package:nodeline/src/models/styles.dart';

part 'tool_event.dart';
part 'tool_state.dart';

class ToolBloc extends Bloc<ToolEvent, ToolState> {
  ToolBloc() : super(const ToolState()) {
    on<ToolEvent>((event, emit) async {
      return (switch (event) {
        ToolSelected e => _onToolSelected(e, emit),
        LineStyleSelected e => _onLineStyleSelected(e, emit),
        PathTypeSelected e => emit(state.copyWith(pathType: e.pathType)),
        ArrowHeadSelected e => emit(state.copyWith(arrowHead: e.arrowHead)),
      });
    });
  }

  void _onToolSelected(ToolSelected event, Emitter<ToolState> emit) {
    emit(state.copyWith(activeTool: event.tool));
  }

  void _onLineStyleSelected(LineStyleSelected event, Emitter<ToolState> emit) {
    emit(state.copyWith(lineStyle: event.lineStyle));
  }
}

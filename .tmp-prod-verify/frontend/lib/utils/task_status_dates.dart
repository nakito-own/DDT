import '../models/task.dart';
import '../models/task_status.dart';

/// Даты начала и окончания следуют за текущим статусом, а не за первым переходом.
({DateTime? timeStart, DateTime? timeEnd}) statusTransitionDates({
  required TaskStatus from,
  required TaskStatus to,
  required DateTime? timeStart,
  required DateTime? timeEnd,
  DateTime? now,
}) {
  if (from == to) return (timeStart: timeStart, timeEnd: timeEnd);
  final moment = now ?? DateTime.now();
  return switch (to) {
    TaskStatus.inProgress => (timeStart: moment, timeEnd: null),
    TaskStatus.done => (timeStart: timeStart ?? moment, timeEnd: moment),
    TaskStatus.todo => (timeStart: null, timeEnd: null),
  };
}

Task applyTaskStatusDates(Task task, TaskStatus to, {DateTime? now}) {
  final dates = statusTransitionDates(
    from: task.status,
    to: to,
    timeStart: task.timeStart,
    timeEnd: task.timeEnd,
    now: now,
  );
  return task.copyWith(
    status: to,
    timeStart: dates.timeStart,
    clearTimeStart: dates.timeStart == null,
    timeEnd: dates.timeEnd,
    clearTimeEnd: dates.timeEnd == null,
  );
}

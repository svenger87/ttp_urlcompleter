// lib/models/schedule_action.dart

import 'fahrversuche.dart';

enum ActionType { add, delete, move, statusChange }

class ScheduleAction {
  final ActionType type;
  final FahrversuchItem item;
  final String fromDay;
  final int fromIndex;
  final String toDay;
  final int toIndex;

  // For statusChange
  final String oldStatus;
  final String newStatus;

  // Constructor for Add Action
  ScheduleAction.add({
    required this.item,
    required this.toDay,
    required this.toIndex,
  })  : type = ActionType.add,
        fromDay = '',
        fromIndex = -1,
        oldStatus = '',
        newStatus = '';

  // Constructor for Delete Action
  ScheduleAction.delete({
    required this.item,
    required this.fromDay,
    required this.fromIndex,
  })  : type = ActionType.delete,
        toDay = '',
        toIndex = -1,
        oldStatus = '',
        newStatus = '';

  // Constructor for Move Action
  ScheduleAction.move({
    required this.item,
    required this.fromDay,
    required this.fromIndex,
    required this.toDay,
    required this.toIndex,
  })  : type = ActionType.move,
        oldStatus = '',
        newStatus = '';

  // Constructor for Status Change Action
  ScheduleAction.statusChange({
    required this.item,
    required this.oldStatus, // Now non-nullable
    required this.newStatus, // Now non-nullable
  })  : type = ActionType.statusChange,
        fromDay = '',
        fromIndex = -1,
        toDay = '',
        toIndex = -1;
}

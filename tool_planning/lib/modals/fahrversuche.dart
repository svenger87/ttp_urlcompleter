import 'package:flutter/material.dart';

class FahrversuchItem {
  int? id;
  String projectName;
  String toolNumber;
  String dayName; // which row
  int tryoutIndex; // which column
  String status;

  FahrversuchItem({
    this.id,
    required this.projectName,
    required this.toolNumber,
    required this.dayName,
    required this.tryoutIndex,
    required this.status,
  });

  Color get color {
    switch (status) {
      case 'done':
        return Colors.green.withOpacity(0.3);
      case 'in_change':
        return Colors.red.withOpacity(0.3);
      default: // 'in_progress'
        return Colors.orange.withOpacity(0.3);
    }
  }
}

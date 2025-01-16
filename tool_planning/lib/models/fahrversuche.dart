// lib/models/fahrversuche.dart

import 'package:flutter/material.dart';

class FahrversuchItem {
  final int id;
  String projectName;
  String toolNumber;
  String dayName;
  int tryoutIndex;
  String status;
  int weekNumber;
  int year; // New field

  String? imageUri;
  String? localImagePath;
  bool hasBeenMoved;
  int? extrudermainId;
  String? machineNumber;

  FahrversuchItem({
    required this.id,
    required this.projectName,
    required this.toolNumber,
    required this.dayName,
    required this.tryoutIndex,
    required this.status,
    required this.weekNumber,
    required this.year, // Initialize
    this.imageUri,
    this.localImagePath,
    this.hasBeenMoved = false,
    this.extrudermainId,
    this.machineNumber,
  });

  // Map statuses to color
  Color get color {
    switch (status) {
      case 'Erledigt':
        return Colors.green.withOpacity(0.3);
      case 'In Änderung':
        return Colors.red.withOpacity(0.3);
      default: // "In Arbeit"
        return Colors.orange.withOpacity(0.3);
    }
  }
}

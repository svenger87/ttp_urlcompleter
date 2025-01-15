import 'package:flutter/material.dart';

class FahrversuchItem {
  final int id; // Changed from int? to int
  String projectName;
  String toolNumber;
  String dayName;
  int tryoutIndex;
  String status; // "In Arbeit", "In Änderung", "Erledigt", etc.
  int weekNumber;

  // If we have an imageUri from the secondary API, we store it here
  String? imageUri;

  // Once downloaded, store the local file path
  String? localImagePath;

  // New field to indicate if the item has been moved
  bool hasBeenMoved;

  int? extrudermainId;
  String? machineNumber;

  FahrversuchItem({
    required this.id, // Now required
    required this.projectName,
    required this.toolNumber,
    required this.dayName,
    required this.tryoutIndex,
    required this.status,
    required this.weekNumber,
    this.imageUri, // from secondaryProjects
    this.localImagePath, // after we download
    this.hasBeenMoved = false,
    this.extrudermainId, // Initialize as null
    this.machineNumber, // Initialize as null
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

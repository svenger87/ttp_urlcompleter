// lib/models/fahrversuche.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;

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
  bool isDeleted; // New field

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
    this.isDeleted = false, // Default to not deleted
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

  // Factory method to create an instance from JSON
  factory FahrversuchItem.fromJson(Map<String, dynamic> json) {
    return FahrversuchItem(
      id: json['id'],
      projectName: json['project_name'],
      toolNumber: json['tool_number'],
      dayName: json['day_name'],
      tryoutIndex: json['tryout_index'],
      status: json['status'],
      weekNumber: json['week_number'],
      year: json['year'],
      imageUri: json['imageuri'],
      hasBeenMoved: json['has_been_moved'] == 1,
      extrudermainId: json['extrudermain_id'],
      machineNumber: json['machine_number'],
      isDeleted: json['is_deleted'] == 1,
    );
  }

  // Method to convert an instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_name': projectName,
      'tool_number': toolNumber,
      'day_name': dayName,
      'tryout_index': tryoutIndex,
      'status': status,
      'week_number': weekNumber,
      'year': year,
      'imageuri': imageUri,
      'has_been_moved': hasBeenMoved ? 1 : 0,
      'extrudermain_id': extrudermainId,
      'machine_number': machineNumber,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  /// Generates a unique local image path based on the item's ID.
  /// **Updated to handle multiple image formats**
  Future<String> getUniqueImagePath() async {
    final directory =
        await getTemporaryDirectory(); // Changed to temporary directory
    String extension = '.jpg'; // Default extension

    if (imageUri != null && imageUri!.isNotEmpty) {
      final uriPath = Uri.parse(imageUri!).path;
      final ext = path.extension(uriPath).toLowerCase();
      if (ext == '.png' || ext == '.jpg' || ext == '.jpeg') {
        extension = ext;
      }
    }

    return '${directory.path}/ikoffice_$id$extension'; // Use dynamic extension
  }

  /// Checks if the image exists locally.
  Future<bool> hasLocalImage() async {
    final path = await getUniqueImagePath();
    return File(path).exists();
  }
}

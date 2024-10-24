import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/constants.dart';

class ApiService {
  // Fetch primary projects with initial data
  static Future<List<Map<String, dynamic>>> fetchPrimaryProjects() async {
    final response = await http.get(Uri.parse(primaryApiUrl));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load primary projects');
    }
  }

  // Fetch secondary projects containing more details
  static Future<List<Map<String, dynamic>>> fetchSecondaryProjects() async {
    final response = await http.get(Uri.parse(secondaryApiUrl));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
          json.decode(response.body)['projects']);
    } else {
      throw Exception('Failed to load secondary projects');
    }
  }

  // Method to Fetch Project Details by ID
  static Future<Map<String, dynamic>> fetchProjectDetailsById(
      int projectId) async {
    try {
      // Fetch both primary and secondary projects
      final primaryData = await fetchPrimaryProjects();
      final secondaryData = await fetchSecondaryProjects();

      // Find the primary project by projectId
      final primaryProject = primaryData.firstWhere(
        (project) => project['project_id'] == projectId,
        orElse: () => <String, dynamic>{}, // Return an empty map if not found
      );

      // Find the matching secondary project by projectId
      final matchingSecondary = secondaryData.firstWhere(
        (project) => project['id'] == projectId,
        orElse: () => <String, dynamic>{}, // Return an empty map if not found
      );

      // If primary and secondary data are available, merge them
      if (matchingSecondary.isNotEmpty) {
        return {
          ...primaryProject,
          'name': matchingSecondary['name'],
          'description': matchingSecondary['description'],
          'internalstatus': matchingSecondary['internalstatus'],
          'number': matchingSecondary['number'],
          'category': matchingSecondary['category'],
          'salamanderacprojectnumber':
              matchingSecondary['salamanderacprojectnumber'],
          'salamanderactaskid': matchingSecondary['salamanderactaskid'],
          'salamanderacbaseproject_id':
              matchingSecondary['salamanderacbaseproject_id'],
        };
      }

      // Return primary project data if no matching secondary data
      return primaryProject;
    } catch (e) {
      throw Exception(
          'Failed to load project details for ID: $projectId. Error: $e');
    }
  }

  // Update project priorities
  static Future<void> updatePriorities(
      List<Map<String, dynamic>> priorities) async {
    final List<Map<String, dynamic>> updatedPriorities =
        priorities.map((priority) {
      return {
        'project_id': priority['project_id'],
        'priority_order': priority['priority_order'],
        'category': priority['category'],
      };
    }).toList();

    final response = await http.post(
      Uri.parse(updatePriorityUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'priorities': updatedPriorities}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update priorities');
    }
  }

  // Delete project by ID
  static Future<void> deleteProjectById(int projectId) async {
    final response = await http.delete(Uri.parse('$primaryApiUrl/$projectId'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete project with ID: $projectId');
    }
  }

  // Add new project with category
  static Future<void> addProject(Map<String, dynamic> projectData) async {
    final response = await http.post(
      Uri.parse(primaryApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(projectData),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to add new project');
    }
  }
}

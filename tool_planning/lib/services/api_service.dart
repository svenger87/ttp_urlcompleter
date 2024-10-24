// lib/services/api_service.dart

import 'dart:io';

import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/constants.dart'; // Ensure this contains activeCollabApiUrl
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  static final _storage = FlutterSecureStorage();

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

  // Authenticate user and obtain session token
  static Future<void> authenticateUser({
    required String username,
    required String password,
  }) async {
    final url =
        '$activeCollabApiUrl/issue-token'; // Ensure this is the correct endpoint

    final body = jsonEncode({
      'email': username, // Adjust based on Active Collab's requirements
      'password': password,
      'client_name': 'ttpApp', // Replace with your app's name
      'client_vendor': 'ttp Papenburg Gmbh', // Replace with your company's name
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (kDebugMode) {
      print('Authentication response status: ${response.statusCode}');
      print('Authentication response body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final sessionToken = data['token'];

      if (sessionToken != null) {
        // Store the session token securely
        await _storage.write(
            key: 'activeCollabSessionToken', value: sessionToken);
        if (kDebugMode) {
          print('Session Token: $sessionToken');
        }
      } else {
        throw Exception('Session token not found in response');
      }
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to authenticate');
    }
  }

  // Retrieve session token
  static Future<String?> getSessionToken() async {
    return await _storage.read(key: 'activeCollabSessionToken');
  }

  // Update headers to use session token
  static Future<Map<String, String>> _getHeaders() async {
    String? sessionToken = await getSessionToken();

    if (sessionToken == null) {
      throw Exception('User not authenticated');
    }

    return {
      'X-Angie-AuthApiToken': sessionToken,
      'Content-Type': 'application/json',
    };
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'activeCollabSessionToken');
  }

  // Fetch comments for a task
  static Future<List<Map<String, dynamic>>> fetchCommentsForTask({
    required int taskId,
  }) async {
    final url = '$activeCollabApiUrl/api/v1/comments/task/$taskId';

    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (kDebugMode) {
      print('Fetch comments response status: ${response.statusCode}');
      print('Fetch comments response body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Failed to fetch comments: ${response.body}');
    }
  }

  // Fetch comments for a project
  static Future<List<Map<String, dynamic>>> fetchCommentsForProject({
    required int projectId,
  }) async {
    final url = '$activeCollabApiUrl/api/v1/comments/project/$projectId';

    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (kDebugMode) {
      print('Fetch comments response status: ${response.statusCode}');
      print('Fetch comments response body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Failed to fetch comments: ${response.body}');
    }
  }

  // Upload attachment and get attachment code
  static Future<String?> uploadAttachment(String filePath) async {
    final url = '$activeCollabApiUrl/api/v1/upload-files';

    String? sessionToken = await getSessionToken();
    if (sessionToken == null) {
      throw Exception('User not authenticated');
    }

    final mimeType = lookupMimeType(filePath);
    if (mimeType == null) {
      throw Exception('Could not determine MIME type of file: $filePath');
    }
    final mimeTypeData = mimeType.split('/');

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll({
      'X-Angie-AuthApiToken': sessionToken,
      'Content-Type': 'multipart/form-data',
    });

    try {
      final file = File(filePath);
      request.files.add(
        http.MultipartFile(
          'file', // Match the field name with the server expectations
          file.readAsBytes().asStream(),
          file.lengthSync(),
          filename: filePath.split("/").last,
          contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // If response body contains the code
        if (data is List && data.isNotEmpty) {
          final attachmentCode = data[0]['code'];
          return attachmentCode;
        } else {
          throw Exception('No files were uploaded. The response was empty.');
        }
      } else {
        throw Exception(
            'Failed to upload attachment: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error during attachment upload: $e');
    }
  }

  // Method to add comment to a task
  static Future<void> addCommentToTask({
    required int taskId,
    required Map<String, dynamic> commentData,
  }) async {
    final url =
        '$activeCollabApiUrl/api/v1/comments/task/$taskId'; // Correct endpoint

    final body = jsonEncode(commentData);

    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );

    if (kDebugMode) {
      print('Add Comment to Task response status: ${response.statusCode}');
      print('Add Comment to Task response body: ${response.body}');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Optionally handle successful response
      if (kDebugMode) {
        print('Comment added successfully.');
      }
    } else {
      throw Exception('Failed to add comment: ${response.body}');
    }
  }

  // Method to add comment to a project
  static Future<void> addCommentToProject({
    required int projectId,
    required Map<String, dynamic> commentData,
  }) async {
    final url = '$activeCollabApiUrl/api/v1/comments/projects/$projectId';

    final body = jsonEncode(commentData);

    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 201) {
      // Comment added successfully
    } else {
      throw Exception('Failed to add comment: ${response.body}');
    }
  }
}

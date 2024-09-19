import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tool.dart';
import 'package:intl/intl.dart'; // Importing intl for date formatting

class ToolService {
  final String localApiUrl = 'http://wim-solution:3000/tools';
  final String updateToolApiUrl = 'http://wim-solution:3000/update-tool';
  final String freeStoragesApiUrl = 'http://wim-solution:3000/free-storages';
  final String storageUtilizationApiUrl =
      'http://wim-solution:3000/storage-utilization';
  final String users = 'http://wim-solution:3000/users';
  final String toolForecastApiUrl = 'http://wim-solution:3000/tool-forecast';

  // Fetch tools from local API and separate them into has_storage and has_no_storage
  // Already included
  Future<Map<String, List<Tool>>> fetchTools() async {
    final response = await http.get(Uri.parse(localApiUrl));

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      List<Tool> hasStorage = (body['has_storage'] as List)
          .map((item) => Tool.fromJson(item))
          .toList();
      List<Tool> hasNoStorage = (body['has_no_storage'] as List)
          .map((item) => Tool.fromJson(item))
          .toList();

      return {
        'has_storage': hasStorage,
        'has_no_storage': hasNoStorage,
      };
    } else {
      throw Exception('Failed to load tools from local API');
    }
  }

  // Update an existing tool with proper date formatting
  Future<void> updateTool({
    required String toolNumber,
    required String storageLocationOne,
    required String storageLocationTwo,
    required String usedSpacePitchOne,
    required String usedSpacePitchTwo,
    required String storageStatus,
    required DateTime providedDate,
    required DateTime returnedDate,
    required String providedById,
    required String returnedById,
    required bool providedStatus,
  }) async {
    // Format the dates as 'YYYY-MM-DD HH:MM:SS'
    final String formattedProvidedDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(providedDate);
    final String formattedReturnedDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(returnedDate);

    final body = jsonEncode({
      'storage_location_one': storageLocationOne,
      'storage_location_two': storageLocationTwo,
      'used_space_pitch_one': usedSpacePitchOne,
      'used_space_pitch_two': usedSpacePitchTwo,
      'storage_status': storageStatus,
      'provided_date': providedStatus
          ? formattedProvidedDate
          : null, // Only send if "Ausgelagert"
      'returned_date': !providedStatus
          ? formattedReturnedDate
          : null, // Only send if "Eingelagert"
      'provideddby_id': providedById,
      'returnedby_id': returnedById,
      'provided': providedStatus // Boolean for provided status
    });

    final response = await http.put(
      Uri.parse('$updateToolApiUrl/$toolNumber'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update tool: ${response.body}');
    }
  }

  // Fetch free storages from API
  Future<List<String>> fetchFreeStorages() async {
    final response = await http.get(Uri.parse(freeStoragesApiUrl));

    if (response.statusCode == 200) {
      List<dynamic> body = json.decode(response.body);
      return body.map((dynamic item) => item as String).toList();
    } else {
      throw Exception('Failed to load free storages from API');
    }
  }

  // Fetch storage utilization data from API
  Future<Map<String, dynamic>> fetchStorageUtilization() async {
    final response = await http.get(Uri.parse(storageUtilizationApiUrl));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load storage utilization from API');
    }
  }

  // Add a method to fetch users
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final response = await http.get(Uri.parse(users));

    if (response.statusCode == 200) {
      List<dynamic> body = json.decode(response.body);
      return body.map((dynamic user) {
        return {
          'user_id': user['user_id'].toString(),
          'employeenumber': user['employeenumber'],
          'firstname': user['firstname'],
          'lastname': user['lastname'],
        };
      }).toList();
    } else {
      throw Exception('Failed to load users from API');
    }
  }

  Future<String?> getUserIdFromEmployeenumber(String? employeenumber) async {
    if (employeenumber == null) return null;

    final response = await http.get(Uri.parse('$users/$employeenumber'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['user_id'].toString();
    } else {
      throw Exception('Failed to load user ID from API');
    }
  }

  // Method to fetch tool forecast
  Future<List<Map<String, dynamic>>> fetchToolForecast() async {
    final response = await http.get(Uri.parse(toolForecastApiUrl));

    if (response.statusCode == 200) {
      List<dynamic> body = json.decode(response.body)['data'];

      // Filter out entries where Fertigungssteuerer is not "1"
      return body.where((item) {
        final workingPlan = item['workingPlan'] ?? {};
        // Check Fertigungssteuerer in both main node and subnode
        return item['Fertigungssteuerer'] == '1' ||
            workingPlan['Fertigungssteuerer'] == '1';
      }).map((item) {
        // Extract Equipment and Arbeitsplatz from the subnode workingPlan if it exists
        final workingPlan = item['workingPlan'] ?? {};
        return {
          'Eckstarttermin': item['Eckstarttermin'],
          'Hauptartikel': item['Hauptartikel'],
          'Equipment': workingPlan['Equipment'] ?? item['Equipment'] ?? 'N/A',
          'Arbeitsplatz':
              workingPlan['Arbeitsplatz'] ?? item['Arbeitsplatz'] ?? 'N/A',
        };
      }).toList();
    } else {
      throw Exception('Failed to load tool forecast from API');
    }
  }

  // Method to fetch tool by number
  Future<Tool?> fetchToolByNumber(String toolNumber) async {
    try {
      // Make a GET request to fetch tool data by tool number
      final response = await http.get(Uri.parse('$localApiUrl/$toolNumber'));

      // Log the response status and body for debugging
      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
      }
      if (kDebugMode) {
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> toolData = json.decode(response.body);
        return Tool.fromJson(toolData); // Convert response data to Tool model
      } else if (response.statusCode == 404) {
        throw Exception('Tool not found');
      } else {
        throw Exception('Failed to load tool data for $toolNumber');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching tool by number: $e');
      }
      return null; // Handle error
    }
  }
}

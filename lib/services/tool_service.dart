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

  // -------------------------------------------------------------------------
  // (A) New helper: fetchAllToolsAsMap() -> returns a map of tool_number to
  //     { 'provided': bool, 'freestatus_id': int? } from local API
  // -------------------------------------------------------------------------
  Future<Map<String, Map<String, dynamic>>> fetchAllToolsAsMap() async {
    final response = await http.get(Uri.parse(localApiUrl));

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      // Merge arrays has_storage + has_no_storage
      List<dynamic> allTools = [
        ...body['has_storage'],
        ...body['has_no_storage']
      ];

      // Key = tool_number, Value = { 'provided': bool, 'freestatus_id': int? }
      Map<String, Map<String, dynamic>> toolInfoMap = {};

      for (var item in allTools) {
        final String toolNumber = item['tool_number'] as String;
        // Convert `provided` to a bool
        final bool providedStatus =
            (item['provided'] == true || item['provided'] == '1');

        // Convert `freestatus_id` to int? if present
        final dynamic rawFreeId = item['freestatus_id'];
        int? freeStatusId;
        if (rawFreeId != null) {
          freeStatusId = int.tryParse(rawFreeId.toString());
        }

        toolInfoMap[toolNumber] = {
          'provided': providedStatus,
          'freestatus_id': freeStatusId,
        };
      }

      return toolInfoMap;
    } else {
      throw Exception('Failed to load tools from local API');
    }
  }

  // -------------------------------------------------------------------------
  // (B) Merge forecast data with local tools data
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> fetchToolForecast() async {
    // 1) Grab the forecast from /tool-forecast
    final forecastResponse = await http.get(Uri.parse(toolForecastApiUrl));
    if (forecastResponse.statusCode != 200) {
      throw Exception('Failed to load tool forecast from API');
    }

    // Parse forecast data
    Map<String, dynamic> responseBody = json.decode(forecastResponse.body);
    List<dynamic> forecastBody = responseBody['data'];
    String lastUpdated = responseBody['lastUpdated'] ?? '';

    // 2) Get local tool info -> map of { tool_number: { provided, freestatus_id } }
    final localToolsMap = await fetchAllToolsAsMap();

    // 3) Filter forecast items (Fertigungssteuerer == '1' & Prioritaet <= 2) as before
    final filteredList = forecastBody.where((item) {
      final workingPlan = item['workingPlan'] ?? {};

      final fertigungssteuererIsOne = (item['Fertigungssteuerer'] == '1') ||
          (workingPlan['Fertigungssteuerer'] == '1');

      final prioritaetStr =
          (item['Prioritaet'] ?? workingPlan['Prioritaet'] ?? '')
              .toString()
              .trim();
      final int? prioritaet = int.tryParse(prioritaetStr);

      final bool shouldInclude = (prioritaet == null || prioritaet <= 2);
      if (kDebugMode) {
        print("Processing ${item['Equipment']}: "
            "Fertigungssteuerer=$fertigungssteuererIsOne, "
            "Prioritaet=$prioritaet, Should Include=$shouldInclude");
      }
      return fertigungssteuererIsOne && shouldInclude;
    }).map((item) {
      // Debug log
      if (kDebugMode) {
        print("Including in forecast: ${item['Equipment']}");
      }

      // 4) Extract any relevant fields
      final workingPlan = item['workingPlan'] ?? {};
      final projectData = item['projectData'] ?? {};

      String lengthcuttoolgroup =
          projectData['lengthcuttoolgroup']?.toString() ?? 'Ohne';
      String internalstatus =
          projectData['internalstatus']?.toString() ?? 'unbekannt';
      String packagingtoolgroup =
          projectData['packagingtoolgroup']?.toString() ?? 'Ohne';

      // 5) Identify the tool number from forecast, match it in local map
      String? equipmentNumber =
          (workingPlan['Equipment'] ?? item['Equipment'])?.toString().trim();

      // This is the local record for that tool (if any)
      final localRecord = localToolsMap[equipmentNumber] ?? {};
      final bool providedStatus = localRecord['provided'] ?? false;
      final int? freeStatusId = localRecord['freestatus_id'] as int?;

      // 6) Build the final merged map
      return {
        'PlanStartDatum':
            item['PlanStartDatum'] ?? item['Eckstarttermin'] ?? 'N/A',
        'Hauptartikel': item['Hauptartikel'] ?? 'N/A',
        'Equipment': workingPlan['Equipment'] ?? item['Equipment'] ?? 'N/A',
        'Arbeitsplatz':
            workingPlan['Arbeitsplatz'] ?? item['Arbeitsplatz'] ?? 'N/A',
        'lengthcuttoolgroup': lengthcuttoolgroup,
        'packagingtoolgroup': packagingtoolgroup,
        'internalstatus': internalstatus,

        // From local map
        'provided': providedStatus,
        'freestatus_id': freeStatusId,
      };
    }).toList();

    return {
      'data': filteredList,
      'lastUpdated': lastUpdated,
    };
  }

  // -------------------------------------------------------------------------
  // Other existing methods
  // -------------------------------------------------------------------------

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
      'provided_date': providedStatus ? formattedProvidedDate : null,
      'returned_date': !providedStatus ? formattedReturnedDate : null,
      'provideddby_id': providedById,
      'returnedby_id': returnedById,
      'provided': providedStatus
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

  // Method to fetch tool by number
  Future<Tool?> fetchToolByNumber(String toolNumber) async {
    try {
      final response = await http.get(Uri.parse('$localApiUrl/$toolNumber'));
      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
      if (response.statusCode == 200) {
        final Map<String, dynamic> toolData = json.decode(response.body);
        return Tool.fromJson(toolData);
      } else if (response.statusCode == 404) {
        throw Exception('Tool not found');
      } else {
        throw Exception('Failed to load tool data for $toolNumber');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching tool by number: $e');
      }
      return null;
    }
  }
}

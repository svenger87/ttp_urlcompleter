import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tool.dart';

class ToolService {
  final String localApiUrl = 'http://wim-solution:3000/tools';
  final String updateToolApiUrl = 'http://wim-solution:3000/update-tool';
  final String freeStoragesApiUrl = 'http://wim-solution:3000/free-storages';
  final String storageUtilizationApiUrl =
      'http://wim-solution:3000/storage-utilization';

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

  // Update an existing tool, now with the stock status

  Future<void> updateTool(
      String toolNumber, String storageLocationOne, String storageLocationTwo,
      {required String usedSpacePitchOne,
      required String usedSpacePitchTwo,
      required String storageStatus // Add storage status parameter
      }) async {
    final response = await http.put(
      Uri.parse('$updateToolApiUrl/$toolNumber'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'storage_location_one': storageLocationOne,
        'used_space_pitch_one': usedSpacePitchOne,
        'storage_location_two': storageLocationTwo,
        'used_space_pitch_two': usedSpacePitchTwo,
        'storage_status': storageStatus, // Pass storage status
      }),
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
}

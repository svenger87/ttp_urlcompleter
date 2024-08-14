import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tool.dart';

class ToolService {
  // Local API URL
  final String localApiUrl = 'http://wim-solution:3000/tools';

  // Fetch tools from local API
  Future<List<Tool>> fetchTools() async {
    final response = await http.get(Uri.parse(localApiUrl));

    if (response.statusCode == 200) {
      List<dynamic> body = json.decode(response.body);
      return body.map((dynamic item) => Tool.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load tools from local API');
    }
  }

  // Add a new tool
  Future<void> addTool(Tool tool) async {
    final response = await http.post(
      Uri.parse(localApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(tool.toJson()),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add tool: ${response.body}');
    }
  }

  // Update an existing tool
  Future<String> updateTool(int id, String storageLocation,
      {required bool doNotUpdate}) async {
    final response = await http.put(
      Uri.parse('$localApiUrl/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'storage_location': storageLocation,
        'do_not_update': doNotUpdate ? 1 : 0,
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = response.body;
      if (responseBody.contains('Tool updated successfully')) {
        return 'success';
      } else if (responseBody.contains(
          'Storage location update ignored due to do_not_update flag')) {
        return 'ignored'; // Storage location update ignored
      } else {
        return 'unknown'; // Handle other responses
      }
    } else {
      throw Exception('Failed to update tool: ${response.body}');
    }
  }

  // Delete a tool
  Future<void> deleteTool(int id) async {
    final response = await http.delete(Uri.parse('$localApiUrl/$id'));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete tool: ${response.body}');
    }
  }
}

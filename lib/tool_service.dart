import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tool.dart';

class ToolService {
  // Local API URL
  final String localApiUrl = 'http://wim-solution:3000/tools';

  // Shlink API URL and API Key
  static const shlinkApiUrl =
      'https://wim-solution.sip.local:8081/rest/v2/short-urls?itemsPerPage=10000';
  static const apiKey = 'b2380a66-c965-4177-8bbf-6ecf03fbaa32';

  Future<List<Tool>> fetchTools() async {
    final response = await http.get(Uri.parse(localApiUrl));

    if (response.statusCode == 200) {
      List<dynamic> body = json.decode(response.body);
      return body.map((dynamic item) => Tool.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load tools');
    }
  }

  Future<List<Tool>> fetchToolsFromShlink() async {
    final response = await http.get(
      Uri.parse(shlinkApiUrl),
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = json.decode(response.body);
      // Assuming that the API response includes the necessary data fields
      return body.map((dynamic item) => Tool.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load tools from Shlink API');
    }
  }

  Future<void> addTool(Tool tool) async {
    final response = await http.post(
      Uri.parse(localApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(tool.toJson()),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add tool');
    }
  }

  Future<void> updateTool(int id, String storageLocation) async {
    final response = await http.put(
      Uri.parse('$localApiUrl/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'storage_location': storageLocation}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update tool');
    }
  }

  Future<void> deleteTool(int id) async {
    final response = await http.delete(Uri.parse('$localApiUrl/$id'));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete tool');
    }
  }
}

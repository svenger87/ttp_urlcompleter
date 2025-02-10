// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';
import '../models/profile.dart';
import '../constants/constants.dart';

class ApiService {
  /// Fetch profiles from server using `searchTerm` for partial/like matching
  Future<List<Profile>> fetchProfiles(String query) async {
    // If nothing is typed, return an empty list (or fetch all if you prefer)
    if (query.isEmpty) {
      return [];
    }

    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(httpClient);

      // Use `searchTerm` to tell the server to do partial matching
      // Also add `itemsPerPage=9999` or whatever your endpoint expects
      final uri = Uri.parse('$kApiUrl&searchTerm=$query&itemsPerPage=9999');

      final response = await ioClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'X-Api-Key': kApiKey,
        },
      );

      ioClient.close();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // Validate structure
        if (jsonResponse.containsKey('shortUrls') &&
            jsonResponse['shortUrls'].containsKey('data')) {
          final List<dynamic> data = jsonResponse['shortUrls']['data'];

          // Map JSON objects into Profile model
          return data.map<Profile>((item) => Profile.fromJson(item)).toList();
        } else {
          if (kDebugMode) {
            print('Unexpected JSON structure: $jsonResponse');
          }
          return [];
        }
      } else {
        if (kDebugMode) {
          print('Error fetching profiles. Status code: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching profiles: $e');
      }
      return [];
    }
  }
}

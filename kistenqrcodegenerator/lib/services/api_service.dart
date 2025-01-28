// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';
import '../models/profile.dart';
import '../constants/constants.dart';

class ApiService {
  /// Fetch ALL profiles (ignoring user query) so you can filter locally later
  Future<List<Profile>> fetchAllProfiles() async {
    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final ioClient = IOClient(httpClient);

      // Possibly a bigger itemsPerPage or separate “fetch everything” endpoint
      final Uri uri = Uri.parse('$kApiUrl&itemsPerPage=9999');
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
        if (jsonResponse.containsKey('shortUrls') &&
            jsonResponse['shortUrls'].containsKey('data')) {
          final List<dynamic> data = jsonResponse['shortUrls']['data'];
          return data.map((item) => Profile.fromJson(item)).toList();
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

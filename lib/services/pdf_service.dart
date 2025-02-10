import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class PdfService {
  static Future<Map<String, dynamic>> fetchPdfs(String folder) async {
    final url = 'http://wim-solution.sip.local:3001/api/pdfs/$folder';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('PDFs konnten nicht geladen werden');
    }
  }

  static Future<void> deletePdf(String folder, String fullPath) async {
    final encodedPath = Uri.encodeFull(fullPath);
    final url =
        'http://wim-solution.sip.local:3001/api/pdf/$folder/$encodedPath';
    final response = await http.delete(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('PDF konnte nicht gelöscht werden');
    }
  }

  static Future<void> markPdfAsDone(String folder, String fullPath) async {
    final encodedPath = Uri.encodeFull(fullPath);
    final url =
        'http://wim-solution.sip.local:3001/api/pdf/done/$folder/$encodedPath';
    final response = await http.put(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('PDF konnte nicht als erledigt markiert werden');
    }
  }

  static Future<void> uploadPdf(
      String folder, String fullPath, File file) async {
    final encodedPath = Uri.encodeFull(fullPath); // Properly encode the path
    final url =
        'http://wim-solution.sip.local:3001/api/pdf/upload/$folder/$encodedPath';

    var request = http.MultipartRequest('PUT', Uri.parse(url));
    request.files.add(await http.MultipartFile.fromPath(
        'file', file.path)); // Use the temp file

    try {
      final response = await request.send();

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('PDF successfully uploaded to: $url');
        }
      } else {
        if (kDebugMode) {
          print('Failed to upload PDF. Status code: ${response.statusCode}');
        }
        throw Exception('PDF could not be uploaded');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading PDF: $e');
      }
      throw Exception('PDF could not be uploaded');
    }
  }
}

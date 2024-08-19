import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class PdfService {
  static Future<List<String>> fetchPdfs(String folder) async {
    final url = 'http://wim-solution.sip.local:3001/api/pdfs/$folder';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return List<String>.from(json.decode(response.body));
    } else {
      throw Exception('PDFs konnten nicht geladen werden');
    }
  }

  static Future<void> deletePdf(String folder, String fileName) async {
    final url = 'http://wim-solution.sip.local:3001/api/pdf/$folder/$fileName';
    final response = await http.delete(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('PDF konnte nicht gelöscht werden');
    }
  }

  static Future<void> markPdfAsDone(String folder, String fileName) async {
    final url =
        'http://wim-solution.sip.local:3001/api/pdf/done/$folder/$fileName';
    final response = await http.put(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('PDF konnte nicht als erledigt markiert werden');
    } else {
      if (kDebugMode) {
        print('Server renamed the file to DONE_$fileName');
      }
    }
  }

  static Future<void> uploadPdf(
      String folder, String fileName, File file) async {
    final url =
        'http://wim-solution.sip.local:3001/api/pdf/upload/$folder/$fileName';

    var request = http.MultipartRequest('PUT', Uri.parse(url));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

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
        throw Exception('PDF konnte nicht hochgeladen werden');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading PDF: $e');
      }
      throw Exception('PDF konnte nicht hochgeladen werden');
    }
  }
}

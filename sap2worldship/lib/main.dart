// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:convert' show utf8;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';

void main() {
  runApp(const SAP2WorldShipApp());
}

class SAP2WorldShipApp extends StatelessWidget {
  const SAP2WorldShipApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Standalone MaterialApp:
    return MaterialApp(
      title: 'SAP2WorldShip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SAP2WorldShipScreen(),
    );
  }
}

/// Decides if we are embedded (i.e., inside a parent Scaffold) or standalone.
class SAP2WorldShipScreen extends StatelessWidget {
  const SAP2WorldShipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // If there's a parent Scaffold, we're embedded; otherwise, we're standalone.
    final bool hasParentScaffold = Scaffold.maybeOf(context) != null;

    // If embedded, just return our content. The parent app handles the AppBar.
    if (hasParentScaffold) {
      return const SAP2WorldShipBody();
    }

    // If standalone, we create our own Scaffold + AppBar.
    return Scaffold(
      appBar: AppBar(
        title: const Text('SAP2WorldShip'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: const SAP2WorldShipBody(),
    );
  }
}

/// The main body of the SAP2WorldShip screen, used both in embedded and standalone mode.
class SAP2WorldShipBody extends StatelessWidget {
  const SAP2WorldShipBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'SAP2WorldShip Export Converter',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/SAP.ico', width: 60, height: 60),
                  const SizedBox(width: 16),
                  const Text(
                    '2',
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Image.asset('assets/UPS.ico', width: 60, height: 60),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.file_upload),
                label: const Text('Exportdatei konvertieren'),
                onPressed: () => _processFile(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================== Excel Processing Logic ================== //

  // The column mapping from SAP headers => CSV headers
  static const Map<String, List<String>> columnMapping = {
    'Name 1': ['VersendenanFirmaoderName'],
    'Straße': ['VersendenanAdresse1'],
    'Postleitzahl': ['VersendenanPostleitzahl'],
    'Ort': ['VersendenanStadtoderOrt'],
    'Land': ['VersendenanLandGebiet'],
    'Markierung': ['PaketReferenz1'],
    'Länge': ['Laenge'],
    'Breite': ['Breite'],
    'Höhe': ['Hoehe'],
    'AnzPackstück': ['Packstuecke'],
    'Warenbeschreibung': ['Warenbeschreibung'],
    'Gewichtseinheit': ['Einheit'],
    'Ges.BrGew': ['Gewicht'],
    'Servicetyp': ['Servicetyp'],
  };

  // Text columns that need German char replacements
  static const List<String> textColumns = [
    'Name 1',
    'Straße',
    'Ort',
    'Warenbeschreibung',
  ];

  /// Overall file processing flow:
  static Future<void> _processFile(BuildContext context) async {
    try {
      File? inputFile = await _selectInputFile(context);
      if (inputFile == null || !context.mounted) return;

      String? outputFilePath = await _selectOutputFile(context);
      if (outputFilePath == null || !context.mounted) return;

      // Show a loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Process Excel to CSV
      await _processExcelFile(inputFile, outputFilePath);

      // Dismiss loading
      if (context.mounted) Navigator.pop(context);

      // Show success
      if (context.mounted) {
        _showMessage(
            context, 'Erfolgreich', 'SAP Export erfolgreich konvertiert.');
      }
    } catch (e) {
      // Dismiss loading on error
      if (context.mounted) Navigator.pop(context);

      // Show error
      if (context.mounted) {
        _showMessage(context, 'Fehler', 'Ein Fehler ist aufgetreten: $e');
      }
    }
  }

  // Prompt to pick an Excel file
  static Future<File?> _selectInputFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SAP Exportdatei auswählen.')),
      );
      return null;
    }
    return File(result.files.single.path!);
  }

  // Prompt to pick an output CSV file
  static Future<String?> _selectOutputFile(BuildContext context) async {
    String? outputFilePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Worldship Importdatei wählen',
      fileName: 'UPS_WorldShip_Formatted_Export.csv',
    );
    if (outputFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worldship Importdateinamen wählen.')),
      );
      return null;
    }
    return outputFilePath;
  }

  // Convert Excel -> CSV
  static Future<void> _processExcelFile(
      File inputFile, String outputFilePath) async {
    final bytes = await inputFile.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception('Die Excel-Datei ist leer oder ungültig.');
    }

    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw Exception('Das gewählte Arbeitsblatt ist leer.');
    }

    // Gather header map
    final headers = sheet.rows.first;
    final Map<String, int> headerMap = {};
    for (int colIndex = 0; colIndex < headers.length; colIndex++) {
      final cellVal = headers[colIndex]?.value?.toString().trim() ?? '';
      if (cellVal.isNotEmpty) {
        headerMap[cellVal] = colIndex;
      }
    }

    // Define desired CSV columns / order
    final List<String> outputOrder = [
      'VersendenanFirmaoderName',
      'VersendenanAdresse1',
      'VersendenanPostleitzahl',
      'VersendenanStadtoderOrt',
      'VersendenanLandGebiet',
      'PaketReferenz1',
      'Laenge',
      'Breite',
      'Hoehe',
      'Packstuecke',
      'Warenbeschreibung',
      'Einheit',
      'Gewicht',
      'Servicetyp',
    ];

    List<List<String>> csvRows = [];
    csvRows.add(outputOrder);

    // Start reading data rows from row 1
    for (int rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = sheet.rows[rowIndex];

      // Default values for each row
      Map<String, String> outputRowMap = {
        'Packstuecke': '1',
        'Servicetyp': 'Standard',
      };

      // Fill from columnMapping
      columnMapping.forEach((sourceCol, targetCols) {
        if (headerMap.containsKey(sourceCol)) {
          final sourceIndex = headerMap[sourceCol]!;
          String cellValue = '';
          if (sourceIndex < row.length && row[sourceIndex] != null) {
            cellValue = row[sourceIndex]!.value?.toString() ?? '';
          }

          // Replace special German chars if in textColumns
          if (textColumns.contains(sourceCol)) {
            cellValue = cellValue
                .replaceAll('ä', 'ae')
                .replaceAll('ö', 'oe')
                .replaceAll('ü', 'ue')
                .replaceAll('ß', 'ss');
          }

          // If 'Ges.BrGew', round up
          if (sourceCol == 'Ges.BrGew' && cellValue.isNotEmpty) {
            final val = double.tryParse(cellValue);
            if (val != null) {
              cellValue = val.ceil().toString();
            }
          }

          for (String target in targetCols) {
            outputRowMap[target] = cellValue;
          }
        } else {
          // If the source column doesn't exist, ensure it's empty
          for (String target in targetCols) {
            outputRowMap.putIfAbsent(target, () => '');
          }
        }
      });

      // Build final CSV row
      List<String> finalRow = [];
      for (String colName in outputOrder) {
        finalRow.add(outputRowMap[colName] ?? '');
      }
      csvRows.add(finalRow);
    }

    // Convert to CSV with semicolons
    final csvContent = csvRows.map((row) => row.join(';')).join('\n');

    // Write the file
    final outputFile = File(outputFilePath);
    await outputFile.writeAsString(csvContent, encoding: utf8);
  }

  // Show a message dialog
  static void _showMessage(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

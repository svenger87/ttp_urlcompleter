// import_customers_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/customer.dart';

class ImportCustomersScreen extends StatefulWidget {
  final ApiService apiService;

  const ImportCustomersScreen({super.key, required this.apiService});

  @override
  _ImportCustomersScreenState createState() => _ImportCustomersScreenState();
}

class _ImportCustomersScreenState extends State<ImportCustomersScreen> {
  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> _importExcel() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Kein File ausgewählt.';
        });
        return;
      }
      final filePath = result.files.single.path;
      if (filePath == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Konnte Datei nicht lesen (kein Pfad).';
        });
        return;
      }
      final file = File(filePath);
      final Uint8List fileBytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(fileBytes);
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];
      if (sheet == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Kein Tabellenblatt gefunden.';
        });
        return;
      }

      // Fetch existing customers from backend keyed by name (assumed unique)
      final List<Customer> existingCustomers =
          await widget.apiService.fetchCustomers();
      final Map<String, Customer> existingMap = {
        for (var c in existingCustomers) c.name: c
      };

      int insertedCount = 0;
      int updatedCount = 0;

      // Assuming first row is header
      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        final nameCell = row.isNotEmpty ? row[0]?.value?.toString().trim() : '';
        if (nameCell == null || nameCell.isEmpty) continue;
        final stadtCell = row.length > 1 ? row[1]?.value?.toString() : '';
        final postleitzahlCell =
            row.length > 2 ? row[2]?.value?.toString() : '';
        final strasseCell = row.length > 3 ? row[3]?.value?.toString() : '';
        final bundeslandCell = row.length > 4 ? row[4]?.value?.toString() : '';
        final landCell = row.length > 5 ? row[5]?.value?.toString() : '';

        final customerData = Customer(
          id: null,
          name: nameCell,
          stadt: stadtCell ?? '',
          postleitzahl: postleitzahlCell ?? '',
          strasse: strasseCell ?? '',
          bundesland: bundeslandCell ?? '',
          land: landCell ?? '',
        );

        if (existingMap.containsKey(nameCell)) {
          final existing = existingMap[nameCell]!;
          final updatedCustomer = Customer(
            id: existing.id,
            name: nameCell,
            stadt: stadtCell ?? '',
            postleitzahl: postleitzahlCell ?? '',
            strasse: strasseCell ?? '',
            bundesland: bundeslandCell ?? '',
            land: landCell ?? '',
          );
          await widget.apiService.updateCustomer(existing.id!, updatedCustomer);
          updatedCount++;
        } else {
          await widget.apiService.createCustomer(customerData);
          insertedCount++;
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage =
            'Import abgeschlossen! $insertedCount neu eingefügt, $updatedCount aktualisiert.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Fehler beim Import: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kunden Excel-Import'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _importExcel,
                    child: const Text('Excel importieren'),
                  ),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
      ),
    );
  }
}

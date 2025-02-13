// import_palatte_excel_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/palette_type.dart';

class ImportExcelScreen extends StatefulWidget {
  final ApiService apiService;

  const ImportExcelScreen({super.key, required this.apiService});

  @override
  _ImportExcelScreenState createState() => _ImportExcelScreenState();
}

class _ImportExcelScreenState extends State<ImportExcelScreen> {
  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> _importExcel() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // 1. Let user pick an Excel file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) {
        // User canceled picking a file
        setState(() {
          _isLoading = false;
          _statusMessage = 'Kein File ausgewählt.';
        });
        return;
      }

      // 2. Get the file path
      final filePath = result.files.single.path;
      if (filePath == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Konnte Datei nicht lesen (kein Pfad).';
        });
        return;
      }

      // 3. Read file bytes from path
      final file = File(filePath);
      final Uint8List fileBytes = await file.readAsBytes();

      // 4. Decode Excel
      final excel = Excel.decodeBytes(fileBytes);

      // For simplicity, assume the data is in the first sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];
      if (sheet == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Kein Tabellenblatt gefunden.';
        });
        return;
      }

      // 5. Fetch existing palette types from backend and build a lookup map keyed by lhm_nummer
      final List<PaletteType> existingPaletteTypes =
          await widget.apiService.fetchPaletteTypes();
      final Map<String, PaletteType> existingMap = {
        for (var pt in existingPaletteTypes) pt.lhmNummer: pt
      };

      int insertedCount = 0;
      int updatedCount = 0;

      // 6. Parse each row (skipping header row 0)
      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);

        // Read cells safely; adjust indices to match your Excel structure
        final lhmNummerCell =
            row.isNotEmpty ? row[0]?.value?.toString().trim() : '';
        if (lhmNummerCell == null || lhmNummerCell.isEmpty) {
          // Skip rows without a valid LHM-Nummer
          continue;
        }
        final materialCell = row.length > 1 ? row[1]?.value?.toString() : '';
        final debitorCell = row.length > 2 ? row[2]?.value?.toString() : '';
        final bezeichnungCell = row.length > 3 ? row[3]?.value?.toString() : '';
        final hoeheCell = row.length > 4 ? row[4]?.value : 0;
        final stapelCell = row.length > 5 ? row[5]?.value?.toString() : '';
        final breiteCell = row.length > 6 ? row[6]?.value : 0;
        final laengeCell = row.length > 7 ? row[7]?.value : 0;
        final platzbedarfCell = row.length > 8 ? row[8]?.value : 0.0;
        final bruttoCell = row.length > 9 ? row[9]?.value : 0.0;
        final gewichtseinheitCell =
            row.length > 10 ? row[10]?.value?.toString() : 'KG';
        final buchungsCell = row.length > 11 ? row[11]?.value?.toString() : '';
        final lhmKuehneNagelCell =
            row.length > 12 ? row[12]?.value?.toString() : '';

        // Build a PaletteType instance (id remains null for creation)
        final paletteTypeData = PaletteType(
          id: null,
          lhmNummer: lhmNummerCell,
          material: materialCell ?? '',
          debitor: debitorCell ?? '',
          bezeichnung: bezeichnungCell ?? '',
          hoeheMm: hoeheCell is num ? hoeheCell.toInt() : 0,
          stapelfaehigkeit: stapelCell ?? '',
          breiteMm: breiteCell is num ? breiteCell.toInt() : 0,
          laengeMm: laengeCell is num ? laengeCell.toInt() : 0,
          platzbedarf:
              platzbedarfCell is num ? platzbedarfCell.toDouble() : 0.0,
          bruttogewicht: bruttoCell is num ? bruttoCell.toDouble() : 0.0,
          gewichtseinheit: gewichtseinheitCell ?? 'KG',
          buchungsKz: buchungsCell ?? '',
          lhmKuehneNagel: lhmKuehneNagelCell ?? '',
          photo: '',
          globalInventory:
              0, // Default value because Excel has no quantity info.
          bookedQuantity: 0, // Default value.
        );

        // Check if a record with the same LHM-Nummer exists
        if (existingMap.containsKey(lhmNummerCell)) {
          // Update existing record
          final existing = existingMap[lhmNummerCell]!;
          final updatedPaletteType = PaletteType(
            id: existing.id,
            lhmNummer: lhmNummerCell,
            material: materialCell ?? '',
            debitor: debitorCell ?? '',
            bezeichnung: bezeichnungCell ?? '',
            hoeheMm: hoeheCell is num ? hoeheCell.toInt() : 0,
            stapelfaehigkeit: stapelCell ?? '',
            breiteMm: breiteCell is num ? breiteCell.toInt() : 0,
            laengeMm: laengeCell is num ? laengeCell.toInt() : 0,
            platzbedarf:
                platzbedarfCell is num ? platzbedarfCell.toDouble() : 0.0,
            bruttogewicht: bruttoCell is num ? bruttoCell.toDouble() : 0.0,
            gewichtseinheit: gewichtseinheitCell ?? 'KG',
            buchungsKz: buchungsCell ?? '',
            lhmKuehneNagel: lhmKuehneNagelCell ?? '',
            photo: '',
            globalInventory: existing.globalInventory, // retain existing value
            bookedQuantity: existing.bookedQuantity, // retain existing value
          );
          await widget.apiService
              .updatePaletteType(existing.id!, updatedPaletteType);
          updatedCount++;
        } else {
          // Create new record
          await widget.apiService.createPaletteType(paletteTypeData);
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
        title: const Text('Excel-Import'),
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

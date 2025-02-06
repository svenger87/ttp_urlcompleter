// lib/modules/converter_module.dart

// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Standalone ConverterModule remains available if needed.
class ConverterModule extends StatefulWidget {
  const ConverterModule({super.key});

  @override
  _ConverterModuleState createState() => _ConverterModuleState();
}

class _ConverterModuleState extends State<ConverterModule> {
  static const IconData translateRounded =
      IconData(0xf0250, fontFamily: 'MaterialIcons');

  List<Map<String, dynamic>> anbauteileData = [];
  String selectedNeueBezeichnung = '';
  String selectedAlteBezeichnung = '';

  @override
  void initState() {
    super.initState();
    loadAnbauteileData();
  }

  Future<void> loadAnbauteileData() async {
    final String data = await DefaultAssetBundle.of(context)
        .loadString('assets/anbauteile.json');
    final Map<String, dynamic> jsonData = json.decode(data);
    setState(() {
      anbauteileData = jsonData.entries
          .map((entry) => {
                'id': entry.key,
                'Neue_Bezeichnung': entry.value['Neue_Bezeichnung'] ?? '',
                'Alte_Bezeichnung': entry.value['Alte_Bezeichnung'] ?? '',
                'Beschreibung': entry.value['Beschreibung zum Sortieren'] ?? '',
                'Bauteilgruppe': entry.value['Bauteilgruppe'] ?? '',
              })
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // This is your standalone converter module.
    // For example, a ListTile that opens a translation dialog.
    return ListTile(
      leading: const Icon(translateRounded),
      title: const Text('Anbauteile Konverter'),
      onTap: () {
        _showTranslationDialog(context);
      },
    );
  }

  void _showTranslationDialog(BuildContext context) {
    // For demonstration, we show the same dialog as in ConverterModal.
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Anbauteilenummern übersetzen'),
          content: const Text('Hier würde der Konverter-Dialog erscheinen.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }
}

/// ConverterModal is a modal version of the converter.
/// It uses an AlertDialog to host the converter’s UI.
class ConverterModal extends StatefulWidget {
  const ConverterModal({super.key});

  @override
  _ConverterModalState createState() => _ConverterModalState();
}

class _ConverterModalState extends State<ConverterModal> {
  List<Map<String, dynamic>> anbauteileData = [];
  String selectedNeueBezeichnung = '';
  String selectedAlteBezeichnung = '';

  @override
  void initState() {
    super.initState();
    loadAnbauteileData();
  }

  Future<void> loadAnbauteileData() async {
    final String data = await DefaultAssetBundle.of(context)
        .loadString('assets/anbauteile.json');
    final Map<String, dynamic> jsonData = json.decode(data);
    setState(() {
      anbauteileData = jsonData.entries
          .map((entry) => {
                'id': entry.key,
                'Neue_Bezeichnung': entry.value['Neue_Bezeichnung'] ?? '',
                'Alte_Bezeichnung': entry.value['Alte_Bezeichnung'] ?? '',
                'Beschreibung': entry.value['Beschreibung zum Sortieren'] ?? '',
                'Bauteilgruppe': entry.value['Bauteilgruppe'] ?? '',
              })
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anbauteilenummern übersetzen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Neue Bezeichnung input
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Neue Bezeichnung'),
                const SizedBox(height: 8.0),
                TypeAheadField<String>(
                  controller: TextEditingController(),
                  builder: (context, textController, focusNode) {
                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Geben Sie eine neue Bezeichnung ein',
                        prefixIcon: Icon(Icons.search),
                      ),
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.trim().isEmpty) return [];
                    return anbauteileData
                        .where((item) =>
                            item['Neue_Bezeichnung']
                                .toLowerCase()
                                .contains(pattern.toLowerCase()) &&
                            (item['Neue_Bezeichnung'] as String).isNotEmpty)
                        .map((item) => item['Neue_Bezeichnung'] as String)
                        .toList();
                  },
                  itemBuilder: (context, String suggestion) {
                    return ListTile(title: Text(suggestion));
                  },
                  onSelected: (String suggestion) {
                    if (selectedNeueBezeichnung != suggestion) {
                      setState(() {
                        selectedNeueBezeichnung = suggestion;
                      });
                      _showTranslationResultDialog(selectedNeueBezeichnung);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Bezeichnung bereits ausgewählt.')),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Alte Bezeichnung input
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alte Bezeichnung'),
                const SizedBox(height: 8.0),
                TypeAheadField<String>(
                  controller: TextEditingController(),
                  builder: (context, textController, focusNode) {
                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Geben Sie eine alte Bezeichnung ein',
                        prefixIcon: Icon(Icons.search),
                      ),
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.trim().isEmpty) return [];
                    return anbauteileData
                        .where((item) =>
                            item['Alte_Bezeichnung']
                                .toLowerCase()
                                .contains(pattern.toLowerCase()) &&
                            (item['Alte_Bezeichnung'] as String).isNotEmpty)
                        .map((item) => item['Alte_Bezeichnung'] as String)
                        .toList();
                  },
                  itemBuilder: (context, String suggestion) {
                    return ListTile(title: Text(suggestion));
                  },
                  onSelected: (String suggestion) {
                    if (selectedAlteBezeichnung != suggestion) {
                      setState(() {
                        selectedAlteBezeichnung = suggestion;
                      });
                      _showTranslationResultDialog(selectedAlteBezeichnung);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Bezeichnung bereits ausgewählt.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  void _showTranslationResultDialog(String selectedValue) async {
    if (selectedValue.isEmpty) return;
    final item = anbauteileData.firstWhere(
      (element) =>
          element['Neue_Bezeichnung'] == selectedValue ||
          element['Alte_Bezeichnung'] == selectedValue,
      orElse: () => {
        "Neue_Bezeichnung": "Nicht gefunden",
        "Alte_Bezeichnung": "Nicht gefunden",
        "Beschreibung": "Nicht gefunden",
        "Bauteilgruppe": "Nicht gefunden",
      },
    );

    final pdfFileName = "${item["Alte_Bezeichnung"]}.pdf";
    final pdfExists = await _pdfFileExists(pdfFileName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Übersetzte Anbauteile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ausgewähltes Bauteil: $selectedValue',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              _buildCopyableField(
                label: 'Neue Bezeichnung',
                value: item['Neue_Bezeichnung'],
              ),
              _buildCopyableField(
                label: 'Alte Bezeichnung',
                value: item['Alte_Bezeichnung'],
              ),
              _buildCopyableField(
                label: 'Beschreibung',
                value: item['Beschreibung'],
              ),
              _buildCopyableField(
                label: 'Bauteilgruppe',
                value: item['Bauteilgruppe'],
              ),
              const SizedBox(height: 8.0),
              if (pdfExists)
                ElevatedButton(
                  onPressed: () {
                    _openPDFFile(pdfFileName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF104382),
                  ),
                  child: const Text('PDF Zeichnung öffnen'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCopyableField({required String label, required String value}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(fontSize: 16.0),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.content_copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label kopiert!'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<bool> _pdfFileExists(String pdfFileName) async {
    try {
      await rootBundle.load('assets/wzabt_pdfs/$pdfFileName');
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<void> _openPDFFile(String pdfFileName) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PDFViewerPage(filePath: 'assets/wzabt_pdfs/$pdfFileName'),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        print('Error: $error');
      }
    }
  }
}

/// A PDF viewer page (unchanged)
class PDFViewerPage extends StatelessWidget {
  final String filePath;

  const PDFViewerPage({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zeichnung Anbauteil'),
        backgroundColor: const Color(0xFF104382),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SfPdfViewer.asset(filePath),
    );
  }
}

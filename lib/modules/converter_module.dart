// lib/modules/converter_module.dart

// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
// Notice: we still import flutter_typeahead, but we'll use the new API
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ConverterModule extends StatefulWidget {
  const ConverterModule({super.key});

  @override
  _ConverterModuleState createState() => _ConverterModuleState();
}

class _ConverterModuleState extends State<ConverterModule> {
  static const IconData translateRounded =
      IconData(0xf0250, fontFamily: 'MaterialIcons');

  List<Map<String, dynamic>> anbauteileData = [];
  String? selectedNeueBezeichnung;
  String? selectedAlteBezeichnung;

  @override
  void initState() {
    super.initState();
    loadAnbauteileData();
  }

  Future<void> loadAnbauteileData() async {
    final String data = await DefaultAssetBundle.of(context)
        .loadString('assets/anbauteile.json');
    final Map<String, dynamic> jsonData = json.decode(data);

    // Convert JSON map to list of maps
    anbauteileData = jsonData.entries
        .map((entry) => {
              'id': entry.key,
              'Neue_Bezeichnung': entry.value['Neue_Bezeichnung'] ?? '',
              'Alte_Bezeichnung': entry.value['Alte_Bezeichnung'] ?? '',
              'Beschreibung': entry.value['Beschreibung zum Sortieren'] ?? '',
              'Bauteilgruppe': entry.value['Bauteilgruppe'] ?? '',
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(translateRounded),
      title: const Text('Anbauteile Konverter'),
      onTap: () {
        _showTranslationDialog(context);
      },
    );
  }

  void _showTranslationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Anbauteilenummern übersetzen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Neue Bezeichnung
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Neue Bezeichnung'),
                  TypeAheadField<String>(
                    // REQUIRED in flutter_typeahead >=5.0.0
                    onSelected: (String suggestion) {
                      setState(() {
                        selectedNeueBezeichnung = suggestion;
                      });
                      _showTranslationResultDialog(
                          context, selectedNeueBezeichnung);
                    },

                    // Replace old textFieldConfiguration with a builder
                    builder: (context, textEditingController, focusNode) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(),
                      );
                    },

                    // Called when user types
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

                    // How each item in the dropdown is built
                    itemBuilder: (context, String suggestion) {
                      return ListTile(
                        title: Text(suggestion),
                      );
                    },

                    // Optionally define emptyBuilder if you want a “no items found” UI
                    // emptyBuilder: (context) => const ListTile(
                    //   title: Text('Nichts gefunden'),
                    // ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Alte Bezeichnung
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alte Bezeichnung'),
                  TypeAheadField<String>(
                    onSelected: (String suggestion) {
                      setState(() {
                        selectedAlteBezeichnung = suggestion;
                      });
                      _showTranslationResultDialog(
                          context, selectedAlteBezeichnung);
                    },
                    builder: (context, textEditingController, focusNode) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(),
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
                      return ListTile(
                        title: Text(suggestion),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTranslationResultDialog(
      BuildContext context, String? selectedValue) async {
    if (selectedValue == null) {
      return;
    }

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                ],
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
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Schließen',
                    style: TextStyle(color: Color(0xFF104382)),
                  ),
                ),
              ),
            ],
          ),
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
            _copyToClipboard(value);
            setState(() {});
          },
        ),
      ],
    );
  }

  void _copyToClipboard(String data) {
    Clipboard.setData(ClipboardData(text: data));
    // Show a Snackbar or message if desired
  }

  Future<bool> _pdfFileExists(String pdfFileName) async {
    try {
      final ByteData data =
          await rootBundle.load('assets/wzabt_pdfs/$pdfFileName');
      // ignore: unnecessary_null_comparison
      return data != null; // If load succeeds, file presumably exists
    } catch (error) {
      return false;
    }
  }

  Future<void> _openPDFFile(String pdfFileName) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerPage(
            filePath: 'assets/wzabt_pdfs/$pdfFileName',
          ),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        print('Error: $error');
      }
    }
  }
}

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

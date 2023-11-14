// ignore_for_file: prefer_const_constructors, prefer_adjacent_string_concatenation, prefer_interpolation_to_compose_strings, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter/services.dart';

class ConverterModule extends StatefulWidget {
  const ConverterModule({super.key});

  @override
  // ignore: library_private_types_in_public_api
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Neue Bezeichnung'),
                  TypeAheadField<String>(
                    textFieldConfiguration: TextFieldConfiguration(
                      decoration: InputDecoration(),
                    ),
                    suggestionsCallback: (pattern) async {
                      return anbauteileData
                          .where((item) =>
                              item['Neue_Bezeichnung']
                                  .toLowerCase()
                                  .contains(pattern.toLowerCase()) &&
                              item['Neue_Bezeichnung'].isNotEmpty)
                          .map((item) => item['Neue_Bezeichnung'] as String)
                          .toList();
                    },
                    itemBuilder: (context, suggestion) {
                      return ListTile(
                        title: Text(suggestion),
                      );
                    },
                    onSuggestionSelected: (suggestion) {
                      setState(() {
                        selectedNeueBezeichnung = suggestion;
                      });
                      _showTranslationResultDialog(
                          context, selectedNeueBezeichnung);
                    },
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alte Bezeichnung'),
                  TypeAheadField<String>(
                    textFieldConfiguration: TextFieldConfiguration(
                      decoration: InputDecoration(),
                    ),
                    suggestionsCallback: (pattern) async {
                      return anbauteileData
                          .where((item) =>
                              item['Alte_Bezeichnung']
                                  .toLowerCase()
                                  .contains(pattern.toLowerCase()) &&
                              item['Alte_Bezeichnung'].isNotEmpty)
                          .map((item) => item['Alte_Bezeichnung'] as String)
                          .toList();
                    },
                    itemBuilder: (context, suggestion) {
                      return ListTile(
                        title: Text(suggestion),
                      );
                    },
                    onSuggestionSelected: (suggestion) {
                      setState(() {
                        selectedAlteBezeichnung = suggestion;
                      });
                      _showTranslationResultDialog(
                          context, selectedAlteBezeichnung);
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
        return StatefulBuilder(
          builder: (context, setState) {
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
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
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
                  ),
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
    // You can show a snackbar or toast here to inform the user that the data has been copied.
  }

  Future<bool> _pdfFileExists(String pdfFileName) async {
    try {
      final ByteData data =
          await rootBundle.load('assets/wzabt_pdfs/$pdfFileName');
      // ignore: unnecessary_null_comparison
      return data != null;
    } catch (error) {
      return false;
    }
  }

  Future<void> _openPDFFile(String pdfFileName) async {
    try {
      final pdfController = PdfController(
        document: PdfDocument.openAsset('assets/wzabt_pdfs/$pdfFileName'),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerPage(pdfController),
        ),
      );
    } catch (error) {
      // ignore: avoid_print
      print('Error: $error');
    }
  }
}

class PDFViewerPage extends StatelessWidget {
  final PdfController pdfController;

  const PDFViewerPage(this.pdfController, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zeichnung Anbauteil'),
        backgroundColor: const Color(0xFF104382),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            color: const Color(0xFF104382),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: PdfView(
        controller: pdfController,
      ),
    );
  }
}

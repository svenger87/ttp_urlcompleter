// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pdfx/pdfx.dart';
import 'package:flutter/services.dart';

class ConverterModule extends StatefulWidget {
  const ConverterModule({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ConverterModuleState createState() => _ConverterModuleState();
}

class _ConverterModuleState extends State<ConverterModule> {
  static const IconData translateRounded = IconData(0xf0250, fontFamily: 'MaterialIcons');

  List<Map<String, dynamic>> anbauteileData = [];
  String? selectedNeueBezeichnung;
  String? selectedAlteBezeichnung;

  @override
  void initState() {
    super.initState();
    loadAnbauteileData();
  }

  Future<void> loadAnbauteileData() async {
    final String data = await DefaultAssetBundle.of(context).loadString('assets/anbauteile.json');
    final Map<String, dynamic> jsonData = json.decode(data);

    anbauteileData = jsonData.entries.map((entry) => {
      'id': entry.key,
      'Neue_Bezeichnung': entry.value['Neue_Bezeichnung'] ?? '',
      'Alte_Bezeichnung': entry.value['Alte_Bezeichnung'] ?? '',
      'Beschreibung': entry.value['Beschreibung zum Sortieren'] ?? '',
      'Bauteilgruppe': entry.value['Bauteilgruppe'] ?? '',
    }).toList();
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButton<String>(
                      value: selectedNeueBezeichnung,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedNeueBezeichnung = newValue;
                        });
                        _showTranslationResultDialog(context, selectedNeueBezeichnung);
                      },
                      itemHeight: null, // Allows the dropdown to be as tall as the content
                      items: anbauteileData
                          .map((item) => DropdownMenuItem<String>(
                                value: item['Neue_Bezeichnung'],
                                child: Text(item['Neue_Bezeichnung']!),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alte Bezeichnung'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButton<String>(
                      value: selectedAlteBezeichnung,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedAlteBezeichnung = newValue;
                        });
                        _showTranslationResultDialog(context, selectedAlteBezeichnung);
                      },
                      itemHeight: null, // Allows the dropdown to be as tall as the content
                      items: anbauteileData
                          .map((item) => DropdownMenuItem<String>(
                                value: item['Alte_Bezeichnung'],
                                child: Text(item['Alte_Bezeichnung']!),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTranslationResultDialog(BuildContext context, String? selectedValue) async {
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
      });

    final pdfFileName = "${item["Alte_Bezeichnung"]}.pdf";
    final pdfExists = await _pdfFileExists(pdfFileName);

    // ignore: use_build_context_synchronously
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
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Neue Bezeichnung: ${item["Neue_Bezeichnung"]}'),
                    Text('Alte Bezeichnung: ${item["Alte_Bezeichnung"]}'),
                    Text('Beschreibung: ${item["Beschreibung"]}'),
                    Text('Bauteilgruppe: ${item["Bauteilgruppe"]}'),
                  ],
                ),
              ),
              if (pdfExists)
                ElevatedButton(
                  onPressed: () {
                    _openPDFFile(pdfFileName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF104382), // Set button background color
                  ),
                  child: const Text('PDF Zeichnung öffnen'),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Schließen',
                style: TextStyle(color: Color(0xFF104382)), // Set text color
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _pdfFileExists(String pdfFileName) async {
    try {
      final ByteData data = await rootBundle.load('assets/wzabt_pdfs/$pdfFileName');
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
        backgroundColor: const Color(0xFF104382), // Set app bar color
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            color: const Color(0xFF104382), // Set button color
            onPressed: () {
              Navigator.pop(context); // Close the PDF view and return to the previous screen
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

import 'package:flutter/material.dart';
import 'dart:convert';

class ConverterModule extends StatefulWidget {
  const ConverterModule({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ConverterModuleState createState() => _ConverterModuleState();
}

class _ConverterModuleState extends State<ConverterModule> {
  static const IconData translateRounded = IconData(0xf0250, fontFamily: 'MaterialIcons');

  List<Map<String, String>> anbauteileData = [];
  String? selectedNeueBezeichnung;
  String? selectedAlteBezeichnung;

  @override
  void initState() {
    super.initState();
    loadAnbauteileData();
  }

  Future<void> loadAnbauteileData() async {
    final String data = await DefaultAssetBundle.of(context).loadString('assets/anbauteile.json');
    final List<dynamic> jsonData = json.decode(data);

    // ignore: unnecessary_type_check
    if (jsonData is List) {
      anbauteileData = jsonData.map((item) => Map<String, String>.from(item)).toList();
    }
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

  void _showTranslationResultDialog(BuildContext context, String? selectedValue) {
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
          ],
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Schließen'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
}
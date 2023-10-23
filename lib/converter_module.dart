import 'package:flutter/material.dart';
import 'dart:convert';

class ConverterModule extends StatefulWidget {
  @override
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
    final String data = await DefaultAssetBundle.of(context).loadString('anbauteile.json');
    final List<dynamic> jsonData = json.decode(data);

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
          title: Text('Translate Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedNeueBezeichnung,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedNeueBezeichnung = newValue;
                    selectedAlteBezeichnung = null; // Reset the other dropdown
                  });
                },
                items: anbauteileData
                    .map((item) => DropdownMenuItem<String>(
                          value: item['Neue_Bezeichnung'],
                          child: Text(item['Neue_Bezeichnung']!),
                        ))
                    .toList(),
              ),
              DropdownButton<String>(
                value: selectedAlteBezeichnung,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedAlteBezeichnung = newValue;
                    selectedNeueBezeichnung = null; // Reset the other dropdown
                  });
                },
                items: anbauteileData
                    .map((item) => DropdownMenuItem<String>(
                          value: item['Alte_Bezeichnung'],
                          child: Text(item['Alte_Bezeichnung']!),
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

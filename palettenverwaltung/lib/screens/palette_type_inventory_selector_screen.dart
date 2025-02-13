// palette_type_inventory_selector_screen.dart
import 'package:flutter/material.dart';
import '../models/palette_type.dart';
import '../services/api_service.dart';
import 'palette_type_inventory_screen.dart';

class PaletteTypeInventorySelectorScreen extends StatelessWidget {
  final ApiService apiService;
  final List<PaletteType> paletteTypes;

  const PaletteTypeInventorySelectorScreen({
    Key? key,
    required this.apiService,
    required this.paletteTypes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paletten-Typ auswählen')),
      body: ListView.builder(
        itemCount: paletteTypes.length,
        itemBuilder: (context, index) {
          final pt = paletteTypes[index];
          return ListTile(
            title: Text(pt.bezeichnung),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaletteTypeInventoryScreen(
                    apiService: apiService,
                    paletteType: pt,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

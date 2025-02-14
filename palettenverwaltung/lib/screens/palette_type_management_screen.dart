// palette_type_management_screen.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/palette_type.dart';
import '../services/api_service.dart';
import 'palette_type_form_screen.dart';
import 'import_palatte_excel_screen.dart';

class PaletteTypeManagementScreen extends StatefulWidget {
  final ApiService apiService;

  const PaletteTypeManagementScreen({super.key, required this.apiService});

  @override
  _PaletteTypeManagementScreenState createState() =>
      _PaletteTypeManagementScreenState();
}

class _PaletteTypeManagementScreenState
    extends State<PaletteTypeManagementScreen> {
  late Future<List<PaletteType>> _futurePaletteTypes;

  @override
  void initState() {
    super.initState();
    _loadPaletteTypes();
  }

  void _loadPaletteTypes() {
    _futurePaletteTypes = widget.apiService.fetchPaletteTypes();
  }

  void _deletePaletteType(int id) async {
    try {
      await widget.apiService.deletePaletteType(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Palette-Typ gelöscht')),
      );
      setState(() {
        _loadPaletteTypes();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Löschen: $e')),
      );
    }
  }

  void _openForm({PaletteType? paletteType}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaletteTypeFormScreen(
          apiService: widget.apiService,
          paletteType: paletteType,
        ),
      ),
    );
    if (result == true) {
      setState(() {
        _loadPaletteTypes();
      });
    }
  }

  void _openImportExcel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportExcelScreen(apiService: widget.apiService),
      ),
    ).then((_) {
      _loadPaletteTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<PaletteType>>(
          future: _futurePaletteTypes,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final paletteTypes = snapshot.data ?? [];
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: paletteTypes.length,
              itemBuilder: (context, index) {
                final paletteType = paletteTypes[index];
                final available =
                    paletteType.globalInventory - paletteType.bookedQuantity;
                return ListTile(
                  title: Text(paletteType.bezeichnung),
                  subtitle: Text(
                      'Global: ${paletteType.globalInventory} | Kunden: ${paletteType.bookedQuantity} | Verfügbar: $available'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openForm(paletteType: paletteType),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deletePaletteType(paletteType.id!),
                      ),
                    ],
                  ),
                  onTap: () => _openForm(paletteType: paletteType),
                );
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'import',
                onPressed: _openImportExcel,
                mini: true,
                child: const Icon(Icons.file_upload),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'add',
                onPressed: () => _openForm(),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

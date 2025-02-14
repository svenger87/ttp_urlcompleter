// palette_type_inventory_selector_screen.dart
import 'package:flutter/material.dart';
import '../models/palette_type.dart';
import '../services/api_service.dart';
import 'palette_type_inventory_screen.dart';

class PaletteTypeInventorySelectorScreen extends StatefulWidget {
  final ApiService apiService;
  final List<PaletteType> paletteTypes;

  const PaletteTypeInventorySelectorScreen({
    super.key,
    required this.apiService,
    required this.paletteTypes,
  });

  @override
  // ignore: library_private_types_in_public_api
  _PaletteTypeInventorySelectorScreenState createState() =>
      _PaletteTypeInventorySelectorScreenState();
}

class _PaletteTypeInventorySelectorScreenState
    extends State<PaletteTypeInventorySelectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PaletteType> get _filteredPaletteTypes {
    if (_searchQuery.isEmpty) {
      return widget.paletteTypes;
    } else {
      return widget.paletteTypes
          .where((pt) =>
              pt.bezeichnung.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey[800] : Colors.white;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paletten-Typ auswählen'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Paletten-Typ suchen',
                prefixIcon: const Icon(Icons.search),
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                filled: true,
                fillColor: fillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: _filteredPaletteTypes.length,
        itemBuilder: (context, index) {
          final pt = _filteredPaletteTypes[index];
          return ListTile(
            title: Text(pt.bezeichnung),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaletteTypeInventoryScreen(
                    apiService: widget.apiService,
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

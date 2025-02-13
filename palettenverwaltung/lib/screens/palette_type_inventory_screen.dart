// palette_type_inventory_screen.dart
import 'package:flutter/material.dart';
import '../models/palette_type.dart';
import '../models/palette_type_inventory_item.dart';
import '../services/api_service.dart';

class PaletteTypeInventoryScreen extends StatefulWidget {
  final ApiService apiService;
  final PaletteType paletteType;

  const PaletteTypeInventoryScreen(
      {Key? key, required this.apiService, required this.paletteType})
      : super(key: key);

  @override
  _PaletteTypeInventoryScreenState createState() =>
      _PaletteTypeInventoryScreenState();
}

class _PaletteTypeInventoryScreenState
    extends State<PaletteTypeInventoryScreen> {
  late Future<List<PaletteTypeInventoryItem>> _futureInventory;

  @override
  void initState() {
    super.initState();
    _futureInventory =
        widget.apiService.fetchPaletteTypeInventory(widget.paletteType.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.paletteType.bezeichnung} Inventar'),
      ),
      body: FutureBuilder<List<PaletteTypeInventoryItem>>(
        future: _futureInventory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final inventory = snapshot.data ?? [];
          if (inventory.isEmpty) {
            return const Center(child: Text('Kein Inventar vorhanden.'));
          }
          return ListView.builder(
            itemCount: inventory.length,
            itemBuilder: (context, index) {
              final item = inventory[index];
              return ListTile(
                title: Text(item.customerName),
                subtitle: Text('Menge: ${item.totalQuantity}'),
              );
            },
          );
        },
      ),
    );
  }
}

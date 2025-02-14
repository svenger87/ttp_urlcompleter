// customer_inventory_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/customer_inventory_item.dart';
import '../services/api_service.dart';

class CustomerInventoryScreen extends StatefulWidget {
  final ApiService apiService;
  final Customer customer;

  const CustomerInventoryScreen(
      {super.key, required this.apiService, required this.customer});

  @override
  _CustomerInventoryScreenState createState() =>
      _CustomerInventoryScreenState();
}

class _CustomerInventoryScreenState extends State<CustomerInventoryScreen> {
  late Future<List<CustomerInventoryItem>> _futureInventory;

  @override
  void initState() {
    super.initState();
    _futureInventory =
        widget.apiService.fetchCustomerInventory(widget.customer.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customer.name} Inventar'),
      ),
      body: FutureBuilder<List<CustomerInventoryItem>>(
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
                title: Text(item.paletteTypeName),
                subtitle: Text('Verfügbar: ${item.totalQuantity}'),
              );
            },
          );
        },
      ),
    );
  }
}

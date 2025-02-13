// customer_inventory_selector_screen.dart
import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import 'customer_inventory_screen.dart';

class CustomerInventorySelectorScreen extends StatelessWidget {
  final ApiService apiService;
  final List<Customer> customers;

  const CustomerInventorySelectorScreen({
    Key? key,
    required this.apiService,
    required this.customers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kunden auswählen')),
      body: ListView.builder(
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return ListTile(
            title: Text(customer.name),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerInventoryScreen(
                    apiService: apiService,
                    customer: customer,
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

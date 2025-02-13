// customer_management_screen.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import 'customer_form_screen.dart';
import 'import_customers_excel_screen.dart';

class CustomerManagementScreen extends StatefulWidget {
  final ApiService apiService;

  const CustomerManagementScreen({super.key, required this.apiService});

  @override
  _CustomerManagementScreenState createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  late Future<List<Customer>> _futureCustomers;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  void _loadCustomers() {
    _futureCustomers = widget.apiService.fetchCustomers();
  }

  void _deleteCustomer(int id) async {
    try {
      await widget.apiService.deleteCustomer(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kunde gelöscht')),
      );
      setState(() {
        _loadCustomers();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Löschen: $e')),
      );
    }
  }

  void _openForm({Customer? customer}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerFormScreen(
          apiService: widget.apiService,
          customer: customer,
        ),
      ),
    );
    if (result == true) {
      setState(() {
        _loadCustomers();
      });
    }
  }

  void _openImportScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ImportCustomersScreen(apiService: widget.apiService),
      ),
    ).then((_) {
      _loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<Customer>>(
          future: _futureCustomers,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final customers = snapshot.data ?? [];
            return ListView.builder(
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final customer = customers[index];
                return ListTile(
                  title: Text(customer.name),
                  subtitle: Text('${customer.stadt}, ${customer.land}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openForm(customer: customer),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteCustomer(customer.id!),
                      ),
                    ],
                  ),
                  onTap: () => _openForm(customer: customer),
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
                heroTag: 'import_customer',
                onPressed: _openImportScreen,
                mini: true,
                child: const Icon(Icons.file_upload),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'add_customer',
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

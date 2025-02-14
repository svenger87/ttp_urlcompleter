// customer_inventory_selector_screen.dart
import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import 'customer_inventory_screen.dart';

class CustomerInventorySelectorScreen extends StatefulWidget {
  final ApiService apiService;
  final List<Customer> customers;

  const CustomerInventorySelectorScreen({
    super.key,
    required this.apiService,
    required this.customers,
  });

  @override
  // ignore: library_private_types_in_public_api
  _CustomerInventorySelectorScreenState createState() =>
      _CustomerInventorySelectorScreenState();
}

class _CustomerInventorySelectorScreenState
    extends State<CustomerInventorySelectorScreen> {
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

  List<Customer> get _filteredCustomers {
    if (_searchQuery.isEmpty) {
      return widget.customers;
    } else {
      return widget.customers
          .where((customer) =>
              customer.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine appropriate fill color based on theme brightness
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey[800] : Colors.white;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kunden auswählen'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Kunde suchen',
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
        itemCount: _filteredCustomers.length,
        itemBuilder: (context, index) {
          final customer = _filteredCustomers[index];
          return ListTile(
            title: Text(customer.name),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerInventoryScreen(
                    apiService: widget.apiService,
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

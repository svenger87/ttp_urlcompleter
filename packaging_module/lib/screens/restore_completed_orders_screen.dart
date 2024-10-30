// restore_completed_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RestoreCompletedOrdersScreen extends StatefulWidget {
  const RestoreCompletedOrdersScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _RestoreCompletedOrdersScreenState createState() =>
      _RestoreCompletedOrdersScreenState();
}

class _RestoreCompletedOrdersScreenState
    extends State<RestoreCompletedOrdersScreen> {
  List<dynamic> completedOrders = [];
  String? errorMessage;
  bool restorationOccurred = false;

  @override
  void initState() {
    super.initState();
    fetchCompletedOrders();
  }

  Future<void> fetchCompletedOrders() async {
    try {
      final response = await http.get(
          Uri.parse('http://wim-solution.sip.local:3005/completed-entries'));

      if (response.statusCode == 200) {
        setState(() {
          completedOrders = json.decode(response.body);
          errorMessage = null;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load completed orders. Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load completed orders. Error: $e';
      });
    }
  }

  Future<void> restoreCompletedOrder(String sequenznummer) async {
    try {
      final response = await http.post(
        Uri.parse('http://wim-solution.sip.local:3005/restore-completed'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode({'sequenznummer': sequenznummer}),
      );

      if (response.statusCode == 200) {
        restorationOccurred = true;
        fetchCompletedOrders();
      } else {
        throw Exception('Failed to restore completed order');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to restore completed order. Error: $e';
      });
    }
  }

  String formatDate(String? dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fertiggestellte Aufträge wiederherstellen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, restorationOccurred),
        ),
      ),
      body: errorMessage != null
          ? Center(child: Text(errorMessage!))
          : completedOrders.isEmpty
              ? const Center(
                  child: Text('Keine fertiggestellten Aufträge vorhanden'))
              : ListView.builder(
                  itemCount: completedOrders.length,
                  itemBuilder: (context, index) {
                    final orderEntry = completedOrders[index];
                    final orderData = orderEntry['order_data'];
                    final sequenznummer =
                        orderData['productionOrder']?['Sequenznummer'] ?? 'N/A';
                    final hauptartikel = orderData['Hauptartikel'] ?? 'Unknown';
                    final eckstarttermin = orderData['productionOrder'] != null
                        ? formatDate(
                            orderData['productionOrder']['Eckstarttermin'])
                        : 'N/A';
                    final arbeitsplatz = orderData['productionOrder'] != null
                        ? orderData['productionOrder']['Arbeitsplatz'] ?? 'N/A'
                        : 'N/A';
                    final karton =
                        orderData['materialDetails']?['Karton'] ?? 'N/A';
                    final kartonlaenge =
                        orderData['materialDetails']?['Kartonlaenge'] ?? 'N/A';
                    final kollomenge =
                        orderData['materialDetails']?['Kollomenge'] ?? 'N/A';

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text('Sequenznummer: $sequenznummer'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Geometrie: $hauptartikel'),
                            Text('Arbeitsplatz: $arbeitsplatz'),
                            Text('Eckstart: $eckstarttermin'),
                            Text('Karton: $karton'),
                            Text('Kartonlänge: $kartonlaenge'),
                            Text('Menge: $kollomenge'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => restoreCompletedOrder(sequenznummer),
                          child: const Text('Wiederherstellen'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// production_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'restore_completed_orders_screen.dart';

class ProductionOrdersScreen extends StatefulWidget {
  @override
  _ProductionOrdersScreenState createState() => _ProductionOrdersScreenState();
}

class _ProductionOrdersScreenState extends State<ProductionOrdersScreen> {
  List<dynamic> productionOrders = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchProductionOrders();
  }

  Future<void> fetchProductionOrders() async {
    try {
      final response = await http
          .get(Uri.parse('http://wim-solution.sip.local:3005/matched-data'));

      if (response.statusCode == 200) {
        List<dynamic> orders = json.decode(response.body);

        // Sort by 'Arbeitsplatz'
        orders.sort((a, b) {
          final aArbeitsplatz = (a['productionOrder'] != null)
              ? a['productionOrder']['Arbeitsplatz'] ?? ''
              : '';
          final bArbeitsplatz = (b['productionOrder'] != null)
              ? b['productionOrder']['Arbeitsplatz'] ?? ''
              : '';
          return aArbeitsplatz.compareTo(bArbeitsplatz);
        });

        setState(() {
          productionOrders = orders;
          errorMessage = null;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load production orders. Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load production orders. Error: $e';
      });
    }
  }

  void markAsDone(int index) {
    setState(() {
      final order = productionOrders[index];
      productionOrders.removeAt(index);
      saveCompletedOrder(order);
    });
  }

  Future<void> saveCompletedOrder(dynamic order) async {
    try {
      final response = await http.post(
        Uri.parse('http://wim-solution.sip.local:3005/save-completed'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(
            {'sequenznummer': order['productionOrder']['Sequenznummer']}),
      );

      if (response.statusCode == 200) {
        print(
            'Order saved successfully: ${order['productionOrder']['Sequenznummer']}');
      } else {
        throw Exception('Failed to save completed order');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to save completed order. Error: $e';
      });
    }
  }

  Future<void> navigateToRestoreScreen() async {
    final restorationOccurred = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestoreCompletedOrdersScreen(),
      ),
    );

    if (restorationOccurred == true) {
      fetchProductionOrders();
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
        title: Text('Kartonfertigungsaufträge Übersicht'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchProductionOrders,
          ),
          IconButton(
            icon: Icon(Icons.restore),
            onPressed: navigateToRestoreScreen,
          ),
        ],
      ),
      body: errorMessage != null
          ? Center(child: Text(errorMessage!))
          : productionOrders.isEmpty
              ? Center(child: CircularProgressIndicator())
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 3 / 2,
                  ),
                  padding: EdgeInsets.all(16.0),
                  itemCount: productionOrders.length,
                  itemBuilder: (context, index) {
                    final order = productionOrders[index];
                    final productionOrder = order['productionOrder'];
                    final eckstarttermin = productionOrder != null
                        ? formatDate(productionOrder['Eckstarttermin'])
                        : 'N/A';
                    final arbeitsplatz = productionOrder != null
                        ? productionOrder['Arbeitsplatz'] ?? 'N/A'
                        : 'N/A';
                    final karton = order['materialDetails']?['Karton'] ?? 'N/A';
                    final kartonlaenge =
                        order['materialDetails']?['Kartonlaenge'] ?? 'N/A';
                    final kollomenge =
                        order['materialDetails']?['Kollomenge'] ?? 'N/A';
                    final sequenznummer = productionOrder != null
                        ? productionOrder['Sequenznummer'] ?? 'N/A'
                        : 'N/A';

                    return Card(
                      margin: EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Arbeitsplatz: $arbeitsplatz',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Hauptartikel: ${order['Hauptartikel']}'),
                            Text('Eckstart: $eckstarttermin'),
                            Text('Karton: $karton'),
                            Text('Kartonlänge: $kartonlaenge'),
                            Text('Menge: $kollomenge'),
                            Text('Sequenznummer: $sequenznummer'),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => markAsDone(index),
                              child: Text('Als erledigt markieren'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

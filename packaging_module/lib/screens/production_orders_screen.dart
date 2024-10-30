// production_orders_screen.dart

// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'restore_completed_orders_screen.dart';

class ProductionOrdersScreen extends StatefulWidget {
  const ProductionOrdersScreen({super.key});

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
          body: jsonEncode({
            'sequenznummer': order['productionOrder']['Sequenznummer'],
            'orderData': order,
          }));

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print(
              'Order saved successfully: ${order['productionOrder']['Sequenznummer']}');
        }
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
        builder: (context) => const RestoreCompletedOrdersScreen(),
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
    // Group productionOrders by 'Eckstarttermin' as DateTime objects
    Map<DateTime, List<dynamic>> groupedByEckstarttermin = {};
    for (var order in productionOrders) {
      DateTime eckstartDate;
      final productionOrder = order['productionOrder'];
      final eckstartterminStr =
          productionOrder != null ? productionOrder['Eckstarttermin'] : null;
      if (eckstartterminStr != null) {
        try {
          eckstartDate = DateTime.parse(eckstartterminStr);
        } catch (e) {
          eckstartDate = DateTime.fromMillisecondsSinceEpoch(0); // Default date
        }
      } else {
        eckstartDate = DateTime.fromMillisecondsSinceEpoch(0); // Default date
      }
      if (!groupedByEckstarttermin.containsKey(eckstartDate)) {
        groupedByEckstarttermin[eckstartDate] = [];
      }
      groupedByEckstarttermin[eckstartDate]!.add(order);
    }

    // Convert Map to List and sort by DateTime keys ascending
    var sortedGroupedEntries = groupedByEckstarttermin.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kartonfertigungsaufträge Übersicht'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchProductionOrders,
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: navigateToRestoreScreen,
          ),
        ],
      ),
      body: errorMessage != null
          ? Center(child: Text(errorMessage!))
          : productionOrders.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: sortedGroupedEntries.map((eckEntry) {
                    DateTime eckstartDate = eckEntry.key;
                    String eckstarttermin =
                        formatDate(eckstartDate.toIso8601String());
                    List<dynamic> ordersByEckstart = eckEntry.value;

                    // Within each 'Eckstarttermin', group by 'Hauptartikel'
                    Map<String, List<dynamic>> groupedByHauptartikel = {};
                    for (var order in ordersByEckstart) {
                      String hauptartikel = order['Hauptartikel'] ?? 'Unknown';
                      if (!groupedByHauptartikel.containsKey(hauptartikel)) {
                        groupedByHauptartikel[hauptartikel] = [];
                      }
                      groupedByHauptartikel[hauptartikel]!.add(order);
                    }

                    return ExpansionTile(
                      title: Text(
                        'Eckstarttermin: $eckstarttermin',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: groupedByHauptartikel.entries.map((hauptEntry) {
                        String hauptartikel = hauptEntry.key;
                        List<dynamic> orders = hauptEntry.value;

                        // Sort the orders by 'Sequenznummer' descending
                        orders.sort((a, b) {
                          final aSeq = int.tryParse(a['productionOrder']
                                      ?['Sequenznummer'] ??
                                  '0') ??
                              0;
                          final bSeq = int.tryParse(b['productionOrder']
                                      ?['Sequenznummer'] ??
                                  '0') ??
                              0;
                          return bSeq.compareTo(aSeq); // Descending order
                        });

                        return ExpansionTile(
                          title: Text(
                            'Geometrie: $hauptartikel',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          children: orders.map<Widget>((order) {
                            final productionOrder = order['productionOrder'];
                            final eckstarttermin = productionOrder != null
                                ? formatDate(productionOrder['Eckstarttermin'])
                                : 'N/A';
                            final arbeitsplatz = productionOrder != null
                                ? productionOrder['Arbeitsplatz'] ?? 'N/A'
                                : 'N/A';
                            final karton =
                                order['materialDetails']?['Karton'] ?? 'N/A';
                            final kartonlaenge = order['materialDetails']
                                    ?['Kartonlaenge'] ??
                                'N/A';
                            final kollomenge = order['materialDetails']
                                    ?['Kollomenge'] ??
                                'N/A';
                            final sequenznummer = productionOrder != null
                                ? productionOrder['Sequenznummer'] ?? 'N/A'
                                : 'N/A';

                            // Find the index of the order in the original list
                            int index = productionOrders.indexOf(order);

                            return Card(
                              margin: const EdgeInsets.all(8.0),
                              elevation: 4.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: ListTile(
                                title: Text('Sequenznummer: $sequenznummer'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Arbeitsplatz: $arbeitsplatz'),
                                    Text('Eckstart: $eckstarttermin'),
                                    Text('Karton: $karton'),
                                    Text('Kartonlänge: $kartonlaenge'),
                                    Text('Menge: $kollomenge'),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(200, 80),
                                  ),
                                  onPressed: () => markAsDone(index),
                                  child: const Text('Als erledigt markieren'),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
    );
  }
}

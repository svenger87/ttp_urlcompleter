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

  int calculateMenge(dynamic order) {
    final productionOrder = order['productionOrder'];
    final materialDetails = order['materialDetails'];
    if (productionOrder != null && materialDetails != null) {
      // Parse Restmenge and Menge_Kollo as doubles
      final restmenge =
          double.tryParse(productionOrder['Restmenge'] ?? '0') ?? 0;
      final mengeKollo =
          double.tryParse(materialDetails['Menge_Kollo'] ?? '1') ?? 1;

      // Check to prevent division by zero and round up the result
      if (mengeKollo != 0) {
        return (restmenge / mengeKollo).ceil();
      }
    }
    return 0; // Return 0 if any required field is missing or Menge_Kollo is 0
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
          eckstartDate = DateTime.fromMillisecondsSinceEpoch(0);
        }
      } else {
        eckstartDate = DateTime.fromMillisecondsSinceEpoch(0);
      }
      if (!groupedByEckstarttermin.containsKey(eckstartDate)) {
        groupedByEckstarttermin[eckstartDate] = [];
      }
      groupedByEckstarttermin[eckstartDate]!.add(order);
    }

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

                        orders.sort((a, b) {
                          final aSeq = int.tryParse(a['productionOrder']
                                      ?['Sequenznummer'] ??
                                  '0') ??
                              0;
                          final bSeq = int.tryParse(b['productionOrder']
                                      ?['Sequenznummer'] ??
                                  '0') ??
                              0;
                          return bSeq.compareTo(aSeq);
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
                            final menge = calculateMenge(order);

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
                                    Text('Menge: $menge'),
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

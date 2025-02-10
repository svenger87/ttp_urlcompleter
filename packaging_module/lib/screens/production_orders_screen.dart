import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:packaging_module/screens/printer_management_screen.dart';
import 'restore_completed_orders_screen.dart';

class ProductionOrdersScreen extends StatefulWidget {
  const ProductionOrdersScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
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
      final restmenge =
          double.tryParse(productionOrder['Restmenge'] ?? '0') ?? 0;
      final mengeKollo =
          double.tryParse(materialDetails['Menge_Kollo'] ?? '1') ?? 1;

      if (mengeKollo != 0) {
        return (restmenge / mengeKollo).ceil();
      }
    }
    return 0;
  }

  void markAsDone(int index) {
    final order = productionOrders[index];
    final menge = calculateMenge(order); // Calculate menge from API
    setState(() {
      productionOrders.removeAt(index);
      saveCompletedOrder(order, menge); // Pass menge
    });
  }

  Future<void> saveCompletedOrder(dynamic order, int menge) async {
    try {
      final response = await http.post(
        Uri.parse('http://wim-solution.sip.local:3005/save-completed'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode({
          'sequenznummer': order['productionOrder']['Sequenznummer'],
          'orderData': order,
          'menge': menge, // Include menge in the request
        }),
      );

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

// Update showMengeDialog to allow printing with custom menge values
  Future<void> showMengeDialog(dynamic order) async {
    final TextEditingController mengeController = TextEditingController();
    final initialMenge = calculateMenge(order);
    mengeController.text = initialMenge.toString();

    final modifiedMenge = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Produzierte Menge"),
          content: TextField(
            controller: mengeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Menge',
              hintText: 'Menge eingeben',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text("Abbrechen"),
            ),
            TextButton(
              onPressed: () {
                int enteredMenge =
                    int.tryParse(mengeController.text) ?? initialMenge;
                Navigator.of(context).pop(enteredMenge);
              },
              child: const Text("Bestätigen"),
            ),
          ],
        );
      },
    );

    if (modifiedMenge != null) {
      await printLabel(order, modifiedMenge); // Use custom menge if provided
    }
  }

  Future<void> printLabel(dynamic order, int menge) async {
    try {
      final response = await http.post(
        Uri.parse('http://wim-solution.sip.local:3005/print-label'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode({
          'entryData': order,
          'menge': menge // Send calculated menge
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to print label');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to print label. Error: $e';
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
    Map<DateTime, Map<String, List<dynamic>>> groupedByDateAndArticle = {};

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

      final hauptartikel = productionOrder?['Hauptartikel'] ?? 'Unknown';
      groupedByDateAndArticle.putIfAbsent(eckstartDate, () => {});
      groupedByDateAndArticle[eckstartDate]!
          .putIfAbsent(hauptartikel, () => [])
          .add(order);
    }

    var sortedGroupedEntries = groupedByDateAndArticle.entries.toList()
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
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PrinterManagementScreen()),
              );
            },
          ),
        ],
      ),
      body: errorMessage != null
          ? Center(child: Text(errorMessage!))
          : productionOrders.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: sortedGroupedEntries.map((dateEntry) {
                    DateTime eckstartDate = dateEntry.key;
                    String eckstarttermin =
                        formatDate(eckstartDate.toIso8601String());
                    var articlesByDate = dateEntry.value;

                    return ExpansionTile(
                      title: Text(
                        'Eckstarttermin: $eckstarttermin',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: articlesByDate.entries.map((articleEntry) {
                        String hauptartikel = articleEntry.key;
                        List<dynamic> orders = articleEntry.value;

                        orders.sort((a, b) {
                          int aSeq = int.tryParse(a['productionOrder']
                                      ?['Sequenznummer'] ??
                                  '0') ??
                              0;
                          int bSeq = int.tryParse(b['productionOrder']
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
                            final sequenznummer = order['productionOrder']
                                    ?['Sequenznummer'] ??
                                'N/A';
                            final menge = calculateMenge(order);
                            final arbeitsplatz = order['productionOrder']
                                    ?['Arbeitsplatz'] ??
                                'N/A';
                            final karton =
                                order['materialDetails']?['Karton'] ?? 'N/A';
                            final kartonlaenge = order['materialDetails']
                                    ?['Kartonlaenge'] ??
                                'N/A';

                            int index = productionOrders.indexOf(order);

                            return Card(
                              margin: const EdgeInsets.all(8.0),
                              elevation: 4.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    title:
                                        Text('Sequenznummer: $sequenznummer'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Arbeitsplatz: $arbeitsplatz'),
                                        Text('Eckstart: $eckstarttermin'),
                                        Text('Karton: $karton'),
                                        Text('Kartonlänge: $kartonlaenge'),
                                        Text('Menge: $menge'),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: Column(
                                      children: [
                                        ElevatedButton(
                                          onPressed: () => markAsDone(index),
                                          child: const Text(
                                              'Als erledigt markieren'),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () =>
                                              showMengeDialog(order),
                                          child: const Text(
                                              'Etikett für Teilmenge drucken'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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

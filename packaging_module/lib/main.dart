// ignore_for_file: prefer_const_constructors

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const primaryColor = Color(0xFF104382);

final appLightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: primaryColor,
  primarySwatch: Colors.blue,
  scaffoldBackgroundColor: const Color(0xFFF0F0F0),
  appBarTheme: const AppBarTheme(
    backgroundColor: primaryColor,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(
      color: Colors.white,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primaryColor,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: primaryColor,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: const BorderSide(color: primaryColor),
    ),
  ),
  iconTheme: const IconThemeData(
    color: primaryColor,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.black87),
  ),
);

void main() {
  runApp(const ProductionOrdersApp());
}

class ProductionOrdersApp extends StatelessWidget {
  const ProductionOrdersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appLightTheme,
      home: const ProductionOrdersScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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
      if (kDebugMode) {
        if (kDebugMode) {
          print("Saving order: ${order['productionOrder']['Sequenznummer']}");
        }
      }

      final response = await http.post(
        Uri.parse('http://wim-solution.sip.local:3005/save-completed'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(
            {'sequenznummer': order['productionOrder']['Sequenznummer']}),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print(
              'Order saved successfully: ${order['productionOrder']['Sequenznummer']}');
        }
      } else {
        if (kDebugMode) {
          print('Failed to save order. Status code: ${response.statusCode}');
        }
        if (kDebugMode) {
          print('Response body: ${response.body}');
        }
        throw Exception('Failed to save completed order');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to save completed order. Error: $e';
      });
      if (kDebugMode) {
        print('Error saving order: $e');
      }
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

  @override
  Widget build(BuildContext context) {
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
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 3 / 2,
                  ),
                  padding: const EdgeInsets.all(16.0),
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
                      margin: const EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Arbeitsplatz: $arbeitsplatz',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('Hauptartikel: ${order['Hauptartikel']}'),
                            Text('Eckstart: $eckstarttermin'),
                            Text('Karton: $karton'),
                            Text('Kartonlänge: $kartonlaenge'),
                            Text('Menge: $kollomenge'),
                            Text('Sequenznummer: $sequenznummer'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => markAsDone(index),
                              child: const Text('Als erledigt markieren'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
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
}

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
        if (kDebugMode) {
          print('Order $sequenznummer restored successfully');
        }
        restorationOccurred = true;
        fetchCompletedOrders(); // Refresh list after restoration
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          print(
              'No entry found with the specified sequenznummer: $sequenznummer');
        }
      } else {
        throw Exception('Failed to restore completed order');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to restore completed order. Error: $e';
      });
      if (kDebugMode) {
        print('Error restoring order: $e');
      }
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
                  child: Text('Keine fertiggestellen Aufträge vorhanden'))
              : ListView.builder(
                  itemCount: completedOrders.length,
                  itemBuilder: (context, index) {
                    final order = completedOrders[index];
                    final sequenznummer = order['sequenznummer'] ?? 'N/A';

                    return ListTile(
                      title: Text('Order $sequenznummer'),
                      trailing: ElevatedButton(
                        onPressed: () => restoreCompletedOrder(sequenznummer),
                        child: const Text('Restore'),
                      ),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/foundation.dart';
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
    if (kDebugMode) {
      print('Fetching completed orders...');
    }
    try {
      final response = await http.get(
          Uri.parse('http://wim-solution.sip.local:3005/completed-entries'));

      if (kDebugMode) {
        print('Received response with status code: ${response.statusCode}');
      }
      if (response.statusCode == 200) {
        setState(() {
          completedOrders = json.decode(response.body);
          errorMessage = null;
        });
        if (kDebugMode) {
          print(
              'Successfully loaded completed orders. Number of orders: ${completedOrders.length}');
        }
      } else {
        setState(() {
          errorMessage =
              'Failed to load completed orders. Status code: ${response.statusCode}';
        });
        if (kDebugMode) {
          print(
              'Error loading completed orders: Status code ${response.statusCode}');
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load completed orders. Error: $e';
      });
      if (kDebugMode) {
        print('Exception while fetching completed orders: $e');
      }
    }
  }

  int calculateMenge(dynamic orderData) {
    final productionOrder = orderData['productionOrder'];
    final materialDetails = orderData['materialDetails'];
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

  Future<void> showMengeDialog(String sequenznummer, int initialMenge) async {
    if (kDebugMode) {
      print(
          'Showing Menge dialog for Sequenznummer: $sequenznummer with initial Menge: $initialMenge');
    }
    final TextEditingController mengeController = TextEditingController();
    mengeController.text = initialMenge.toString();

    final modifiedMenge = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Menge"),
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
              onPressed: () {
                if (kDebugMode) {
                  print(
                      'Menge dialog canceled for Sequenznummer: $sequenznummer');
                }
                Navigator.of(context).pop(null);
              },
              child: const Text("Abbrechen"),
            ),
            TextButton(
              onPressed: () {
                int enteredMenge =
                    int.tryParse(mengeController.text) ?? initialMenge;
                if (kDebugMode) {
                  print(
                      'User entered Menge: $enteredMenge for Sequenznummer: $sequenznummer');
                }
                Navigator.of(context).pop(enteredMenge);
              },
              child: const Text("Bestätigen"),
            ),
          ],
        );
      },
    );

    if (modifiedMenge != null) {
      if (kDebugMode) {
        print(
            'Menge modified to: $modifiedMenge for Sequenznummer: $sequenznummer');
      }
      // Pass the modifiedMenge to the print function
      await printLabelFromRestore(sequenznummer, modifiedMenge);
    } else {
      if (kDebugMode) {
        print(
            'No Menge modification performed for Sequenznummer: $sequenznummer');
      }
    }
  }

  Future<void> printLabelFromRestore(String sequenznummer, int menge) async {
    if (kDebugMode) {
      print(
          'Attempting to print label from restore. Sequenznummer: $sequenznummer, Menge: $menge');
    }
    try {
      final response = await http.post(
        Uri.parse(
            'http://wim-solution.sip.local:3005/print-label-from-restore'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'sequenznummer': sequenznummer,
          'menge': menge
        }), // Use modified menge
      );

      if (kDebugMode) {
        print('Print label response status code: ${response.statusCode}');
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to print label');
      }
      if (kDebugMode) {
        print(
            'Label printed successfully for Sequenznummer: $sequenznummer, Menge: $menge');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to print label. Error: $e';
      });
      if (kDebugMode) {
        print('Exception while printing label: $e');
      }
    }
  }

  Future<void> restoreCompletedOrder(String sequenznummer) async {
    if (kDebugMode) {
      print(
          'Attempting to restore completed order with Sequenznummer: $sequenznummer');
    }
    try {
      final response = await http.post(
        Uri.parse('http://wim-solution.sip.local:3005/restore-completed'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode({'sequenznummer': sequenznummer}),
      );

      if (kDebugMode) {
        print(
            'Restore completed order response status code: ${response.statusCode}');
      }
      if (response.statusCode == 200) {
        restorationOccurred = true;
        if (kDebugMode) {
          print('Successfully restored completed order: $sequenznummer');
        }
        fetchCompletedOrders();
      } else {
        throw Exception(
            'Failed to restore completed order. Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to restore completed order. Error: $e';
      });
      if (kDebugMode) {
        print('Exception while restoring completed order: $e');
      }
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

  Map<String, Map<String, Map<String, List<dynamic>>>> categorizeOrdersByDate(
      List<dynamic> orders) {
    final Map<String, Map<String, Map<String, List<dynamic>>>> groupedOrders =
        {};

    for (var order in orders) {
      final eckstarttermin =
          order['order_data']['productionOrder']?['Eckstarttermin'];
      if (eckstarttermin != null) {
        final date = DateTime.parse(eckstarttermin);
        final year = date.year.toString();
        final month = date.month.toString().padLeft(2, '0');
        final day = date.day.toString().padLeft(2, '0');

        groupedOrders.putIfAbsent(year, () => {});
        groupedOrders[year]!.putIfAbsent(month, () => {});
        groupedOrders[year]![month]!.putIfAbsent(day, () => []);
        groupedOrders[year]![month]![day]!.add(order);
      }
    }

    return groupedOrders;
  }

  String getMonthName(String monthNumber) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final monthIndex = int.parse(monthNumber) - 1;
    return monthNames[monthIndex];
  }

  @override
  Widget build(BuildContext context) {
    final groupedOrders = categorizeOrdersByDate(completedOrders);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fertiggestellte Aufträge wiederherstellen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, restorationOccurred);
          },
        ),
      ),
      body: errorMessage != null
          ? Center(child: Text(errorMessage!))
          : groupedOrders.isEmpty
              ? const Center(
                  child: Text('Keine fertiggestellten Aufträge vorhanden'))
              : ListView(
                  children: groupedOrders.entries.map((yearEntry) {
                    final year = yearEntry.key;
                    return ExpansionTile(
                      title: Text(year),
                      children: yearEntry.value.entries.map((monthEntry) {
                        final month = monthEntry.key;
                        final monthName = getMonthName(month);

                        // Sort days in ascending order
                        final sortedDays = monthEntry.value.keys.toList()
                          ..sort();

                        return ExpansionTile(
                          title: Text(monthName),
                          children: sortedDays.map((day) {
                            final ordersForDay = monthEntry.value[day]!;
                            return ExpansionTile(
                              title: Text('Tag: $day'),
                              children: ordersForDay.map((orderEntry) {
                                final orderData = orderEntry['order_data'];
                                final sequenznummer =
                                    orderData['productionOrder']
                                            ?['Sequenznummer'] ??
                                        'N/A';
                                final hauptartikel =
                                    orderData['Hauptartikel'] ?? 'Unknown';
                                final arbeitsplatz =
                                    orderData['productionOrder'] != null
                                        ? orderData['productionOrder']
                                                ['Arbeitsplatz'] ??
                                            'N/A'
                                        : 'N/A';
                                final karton = orderData['materialDetails']
                                        ?['Karton'] ??
                                    'N/A';
                                final kartonlaenge =
                                    orderData['materialDetails']
                                            ?['Kartonlaenge'] ??
                                        'N/A';
                                final menge = calculateMenge(orderData);

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
                                        title: Text('Geometrie: $hauptartikel'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Sequenznummer: $sequenznummer'),
                                            Text('Arbeitsplatz: $arbeitsplatz'),
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
                                              onPressed: () {
                                                restoreCompletedOrder(
                                                    sequenznummer);
                                              },
                                              child: const Text(
                                                  'Wiederherstellen'),
                                            ),
                                            const SizedBox(height: 8),
                                            ElevatedButton(
                                              onPressed: () {
                                                showMengeDialog(
                                                    sequenznummer, menge);
                                              },
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
                    );
                  }).toList(),
                ),
    );
  }
}

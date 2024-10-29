// restore_completed_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RestoreCompletedOrdersScreen extends StatefulWidget {
  @override
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fertiggestellte Aufträge wiederherstellen'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, restorationOccurred),
        ),
      ),
      body: errorMessage != null
          ? Center(child: Text(errorMessage!))
          : completedOrders.isEmpty
              ? Center(child: Text('Keine fertiggestellten Aufträge vorhanden'))
              : ListView.builder(
                  itemCount: completedOrders.length,
                  itemBuilder: (context, index) {
                    final order = completedOrders[index];
                    final sequenznummer = order['sequenznummer'] ?? 'N/A';

                    return ListTile(
                      title: Text('Sequenznummer: $sequenznummer'),
                      trailing: ElevatedButton(
                        onPressed: () => restoreCompletedOrder(sequenznummer),
                        child: Text('Wiederherstellen'),
                      ),
                    );
                  },
                ),
    );
  }
}

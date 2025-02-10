import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PrinterManagementScreen extends StatefulWidget {
  const PrinterManagementScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PrinterManagementScreenState createState() =>
      _PrinterManagementScreenState();
}

class _PrinterManagementScreenState extends State<PrinterManagementScreen> {
  List<dynamic> printers = [];
  String? errorMessage;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchPrinters();
  }

  Future<void> fetchPrinters() async {
    try {
      final response = await http.get(
        Uri.parse('http://wim-solution.sip.local:3005/printers'),
      );

      if (response.statusCode == 200) {
        setState(() {
          printers = json.decode(response.body);
          errorMessage = null;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load printers. Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load printers. Error: $e';
      });
    }
  }

  Future<void> addPrinter() async {
    final name = nameController.text.trim();
    final ipAddress = ipController.text.trim();

    if (name.isEmpty || ipAddress.isEmpty) {
      setState(() {
        errorMessage = 'Name and IP Adresse kann nicht leer sein.';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://wim-solution.sip.local:3005/printers'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'name': name,
          'ip_address': ipAddress,
        }),
      );

      if (response.statusCode == 201) {
        setState(() {
          nameController.clear();
          ipController.clear();
          errorMessage = null;
        });
        fetchPrinters();
      } else {
        setState(() {
          errorMessage =
              'Failed to add printer. Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to add printer. Error: $e';
      });
    }
  }

  Future<void> setDefaultPrinter(int id) async {
    try {
      final response = await http.post(
        Uri.parse('http://wim-solution.sip.local:3005/printers/default'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({'id': id}),
      );

      if (response.statusCode == 200) {
        setState(() {
          errorMessage = null;
        });
        fetchPrinters();
      } else {
        setState(() {
          errorMessage =
              'Failed to set default printer. Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to set default printer. Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drucker Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: printers.length,
                itemBuilder: (context, index) {
                  final printer = printers[index];
                  final isDefault = printer['is_default'] == 1 ||
                      printer['is_default'] == true;
                  return ListTile(
                    title: Text(printer['name']),
                    subtitle: Text('IP: ${printer['ip_address']}'),
                    trailing: isDefault
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(
                            onPressed: () {
                              setDefaultPrinter(printer['id']);
                            },
                            child: const Text('Als Standard setzen'),
                          ),
                  );
                },
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Neuen Drucker hinzufügen',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Druckername',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Addresse',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8.0),
            ElevatedButton(
              onPressed: addPrinter,
              child: const Text('Drucker hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}

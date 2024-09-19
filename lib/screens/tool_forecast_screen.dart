// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttp_app/models/tool.dart';
import '../services/tool_service.dart';
import 'edit_tool_screen.dart';

class ToolSimple {
  final String toolNumber;

  ToolSimple({
    required this.toolNumber,
  });

  factory ToolSimple.fromJson(Map<String, dynamic> json) {
    return ToolSimple(
      toolNumber: json['tool_number'] ?? 'Unknown Tool Number',
    );
  }
}

class ToolForecastScreen extends StatelessWidget {
  final List<Map<String, dynamic>> forecastData;
  final ToolService _toolService = ToolService(); // Initialize the tool service

  ToolForecastScreen({Key? key, required this.forecastData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Werkzeugvorschau'),
        backgroundColor: const Color(0xFF104382),
      ),
      body: Column(
        children: [
          // Add the hint message at the top
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.yellow[100],
            child: const Text(
              'Wenn das Werkzeug den Status "Ausgelagert" hat, erscheint dieses NICHT mehr in der Tabelle!',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: forecastData.isNotEmpty
                ? SingleChildScrollView(
                    child: DataTable(
                      showCheckboxColumn: false,
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Starttermin',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Schicht',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Hauptartikel',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Auftragsnummer',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Werkzeug',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Arbeitsplatz',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: forecastData.map((tool) {
                        return DataRow(
                          cells: [
                            DataCell(Text(_formatDate(tool['Eckstarttermin']))),
                            DataCell(Text(tool['Schicht'] ?? 'N/A')),
                            DataCell(Text(tool['Hauptartikel'] ?? 'N/A')),
                            DataCell(Text(tool['Auftragsnummer'] ?? 'N/A')),
                            DataCell(
                              Text(tool['Equipment'] ?? 'N/A'),
                              onTap: () {
                                _navigateToEditTool(context, tool['Equipment']);
                              },
                            ),
                            DataCell(Text(tool['Arbeitsplatz'] ?? 'N/A')),
                          ],
                          onSelectChanged: (selected) {
                            if (selected == true) {
                              _navigateToEditTool(context, tool['Equipment']);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  )
                : const Center(
                    child: Text(
                      'Keine Werkzeuge verfügbar.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Helper method to format the date
  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    final DateTime date = DateTime.parse(dateString);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Method to navigate to the EditToolScreen with the selected tool number
  void _navigateToEditTool(
      BuildContext context, String? equipmentNumber) async {
    if (equipmentNumber == null) return;

    try {
      _showLoadingDialog(context);

      // Fetch the full tool data for editing (This should happen here, not earlier)
      final Tool? tool = await _toolService.fetchToolByNumber(equipmentNumber);

      Navigator.pop(context); // Close the loading dialog

      if (tool != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditToolScreen(tool: tool),
          ),
        );
      } else {
        _showErrorDialog(context, 'Werkzeug nicht gefunden');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog(context, 'Fehler beim Abrufen des Werkzeugs: $e');
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Fehler'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

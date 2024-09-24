// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttp_app/models/tool.dart';
import '../services/tool_service.dart';
import 'edit_tool_screen.dart';

class ToolForecastScreen extends StatelessWidget {
  final List<Map<String, dynamic>> forecastData;
  final ToolService _toolService = ToolService(); // Initialize the tool service
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController =
      ScrollController(); // For vertical scrolling

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
          // Hint message
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.yellow[100],
            child: const Text(
              'Wenn das Werkzeug den Status "Ausgelagert" hat erscheint dieses NICHT mehr in der Tabelle!',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller:
                  _verticalController, // Attach controller for vertical scrolling
              thumbVisibility:
                  true, // Use thumbVisibility instead of isAlwaysShown
              child: SingleChildScrollView(
                controller:
                    _verticalController, // Vertical scrolling controller
                child: Scrollbar(
                  controller:
                      _horizontalController, // Attach controller for horizontal scrolling
                  thumbVisibility:
                      true, // Use thumbVisibility instead of isAlwaysShown
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _horizontalController, // Horizontal scrolling
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
                        DataColumn(
                          label: Text(
                            'Längsschnittwerkzeuggruppe',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: forecastData.map((tool) {
                        String lengthcuttoolgroup =
                            tool['lengthcuttoolgroup']?.toString() ?? 'N/A';

                        bool highlightRow = true;
                        if (lengthcuttoolgroup.startsWith('Gr.1') ||
                            lengthcuttoolgroup == 'N/A') {
                          highlightRow = false;
                        }

                        return DataRow(
                          color: MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                            if (highlightRow) {
                              return Colors.orange
                                  .withOpacity(0.3); // Highlight in orange
                            }
                            return null; // Default color
                          }),
                          cells: [
                            DataCell(Text(_formatDate(
                                tool['PlanStartDatum'] as String?))),
                            DataCell(Text(tool['Hauptartikel'] ?? 'N/A')),
                            DataCell(Text(tool['Auftragsnummer'] ?? 'N/A')),
                            DataCell(
                              Text(tool['Equipment'] ?? 'N/A'),
                              onTap: () {
                                if (tool['Equipment'] != null &&
                                    tool['Equipment'] != 'N/A') {
                                  _navigateToEditTool(
                                      context, tool['Equipment']);
                                }
                              },
                            ),
                            DataCell(Text(tool['Arbeitsplatz'] ?? 'N/A')),
                            DataCell(Text(lengthcuttoolgroup)),
                          ],
                          onSelectChanged: (selected) {
                            if (selected == true &&
                                tool['Equipment'] != null &&
                                tool['Equipment'] != 'N/A') {
                              _navigateToEditTool(context, tool['Equipment']);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Updated _formatDate method
  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  // Method to navigate to the EditToolScreen with the selected tool number
  void _navigateToEditTool(
      BuildContext context, String? equipmentNumber) async {
    if (equipmentNumber == null ||
        equipmentNumber.isEmpty ||
        equipmentNumber == 'N/A') return;

    try {
      _showLoadingDialog(context);

      // Fetch the full tool data for editing
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

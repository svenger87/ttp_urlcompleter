// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/gestures.dart'; // Necessary for PointerDeviceKind
import 'package:ttp_app/models/tool.dart';
import '../services/tool_service.dart';
import 'edit_tool_screen.dart';

// Custom ScrollBehavior to enable mouse wheel scrolling
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        // You can add more pointer device kinds if needed
      };
}

class ToolForecastScreen extends StatelessWidget {
  final List<Map<String, dynamic>> forecastData;
  final ToolService _toolService = ToolService();

  ToolForecastScreen({Key? key, required this.forecastData}) : super(key: key);

  // Method to check if lengthcuttoolgroup starts with 'Gr.1'
  bool startsWithGr1(String? lengthcuttoolgroup) {
    if (lengthcuttoolgroup == null) return false;
    return lengthcuttoolgroup.startsWith('Gr.1');
  }

  @override
  Widget build(BuildContext context) {
    // Determine font size based on screen width
    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 360 ? 12 : 14;

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
              'Wenn das Werkzeug den Status "Ausgelagert" hat, erscheint dieses NICHT mehr in der Tabelle!',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: forecastData.isNotEmpty
                ? LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      if (constraints.maxWidth < 600) {
                        // Small screen layout
                        return ListView.builder(
                          itemCount: forecastData.length,
                          itemBuilder: (context, index) {
                            final tool = forecastData[index];
                            return Card(
                              color: !startsWithGr1(
                                      tool['lengthcuttoolgroup'] as String?)
                                  ? Colors.orange.withOpacity(0.3)
                                  : null,
                              child: ListTile(
                                title: Text(
                                  tool['Hauptartikel'] ?? 'N/A',
                                  style: TextStyle(fontSize: fontSize),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Starttermin: ${_formatDate(tool['PlanStartDatum'] as String?)}',
                                      style: TextStyle(fontSize: fontSize),
                                    ),
                                    Text(
                                      'Auftragsnummer: ${tool['Auftragsnummer'] ?? 'N/A'}',
                                      style: TextStyle(fontSize: fontSize),
                                    ),
                                    Text(
                                      'Werkzeug: ${tool['Equipment'] ?? 'N/A'}',
                                      style: TextStyle(fontSize: fontSize),
                                    ),
                                    Text(
                                      'Arbeitsplatz: ${tool['Arbeitsplatz'] ?? 'N/A'}',
                                      style: TextStyle(fontSize: fontSize),
                                    ),
                                    Text(
                                      'Längsschnittwerkzeuggruppe: ${tool['lengthcuttoolgroup'] ?? 'N/A'}',
                                      style: TextStyle(fontSize: fontSize),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  if (tool['Equipment'] != null &&
                                      tool['Equipment'] != 'N/A') {
                                    _navigateToEditTool(
                                        context, tool['Equipment']);
                                  }
                                },
                              ),
                            );
                          },
                        );
                      } else {
                        // Large screen layout with custom scroll behavior
                        return ScrollConfiguration(
                          behavior: MyCustomScrollBehavior(),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable2(
                                columnSpacing: 12,
                                horizontalMargin: 12,
                                minWidth: 800,
                                columns: const [
                                  DataColumn2(
                                    label: Text(
                                      'Starttermin',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    size: ColumnSize.S,
                                  ),
                                  DataColumn2(
                                    label: Text(
                                      'Hauptartikel',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    size: ColumnSize.M,
                                  ),
                                  DataColumn2(
                                    label: Text(
                                      'Auftragsnummer',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    size: ColumnSize.S,
                                  ),
                                  DataColumn2(
                                    label: Text(
                                      'Werkzeug',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    size: ColumnSize.S,
                                  ),
                                  DataColumn2(
                                    label: Text(
                                      'Arbeitsplatz',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    size: ColumnSize.S,
                                  ),
                                  DataColumn2(
                                    label: Text(
                                      'Längsschnittwerkzeuggruppe',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    size: ColumnSize.L,
                                  ),
                                ],
                                rows: forecastData.map((tool) {
                                  return DataRow(
                                    color: MaterialStateProperty.resolveWith<
                                        Color?>(
                                      (Set<MaterialState> states) {
                                        if (!startsWithGr1(
                                            tool['lengthcuttoolgroup']
                                                as String?)) {
                                          return Colors.orange.withOpacity(0.3);
                                        }
                                        return null;
                                      },
                                    ),
                                    cells: [
                                      DataCell(Text(
                                        _formatDate(
                                            tool['PlanStartDatum'] as String?),
                                        style: TextStyle(fontSize: fontSize),
                                      )),
                                      DataCell(Text(
                                        tool['Hauptartikel'] ?? 'N/A',
                                        style: TextStyle(fontSize: fontSize),
                                      )),
                                      DataCell(Text(
                                        tool['Auftragsnummer'] ?? 'N/A',
                                        style: TextStyle(fontSize: fontSize),
                                      )),
                                      DataCell(
                                        Text(
                                          tool['Equipment'] ?? 'N/A',
                                          style: TextStyle(fontSize: fontSize),
                                        ),
                                        onTap: () {
                                          if (tool['Equipment'] != null &&
                                              tool['Equipment'] != 'N/A') {
                                            _navigateToEditTool(
                                                context, tool['Equipment']);
                                          }
                                        },
                                      ),
                                      DataCell(Text(
                                        tool['Arbeitsplatz'] ?? 'N/A',
                                        style: TextStyle(fontSize: fontSize),
                                      )),
                                      DataCell(Text(
                                        tool['lengthcuttoolgroup'] ?? 'N/A',
                                        style: TextStyle(fontSize: fontSize),
                                      )),
                                    ],
                                    onSelectChanged: (selected) {
                                      if (selected == true &&
                                          tool['Equipment'] != null &&
                                          tool['Equipment'] != 'N/A') {
                                        _navigateToEditTool(
                                            context, tool['Equipment']);
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      }
                    },
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

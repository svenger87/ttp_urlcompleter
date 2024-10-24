// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:ttp_app/models/tool.dart';
import '../services/tool_service.dart';
import 'edit_tool_screen.dart';

class ToolForecastScreen extends StatefulWidget {
  final List<Map<String, dynamic>> forecastData;
  final String lastUpdated; // Add lastUpdated to the screen

  const ToolForecastScreen({
    super.key,
    required this.forecastData,
    required this.lastUpdated, // Accept lastUpdated as a required argument
  });

  @override
  // ignore: library_private_types_in_public_api
  _ToolForecastScreenState createState() => _ToolForecastScreenState();
}

class _ToolForecastScreenState extends State<ToolForecastScreen> {
  final ToolService _toolService = ToolService();
  final ScrollController _verticalController = ScrollController();

  bool _isProvidedCollapsed = true;
  bool _isForecastCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Werkzeugvorschau (Letzte Aktualisierung: ${widget.lastUpdated})'),
        backgroundColor: const Color(0xFF104382),
        titleTextStyle: const TextStyle(
          color: Colors.white, // Set the text color to white
          fontSize: 20, // Optionally adjust the font size
          fontWeight: FontWeight.bold, // Optionally adjust the font weight
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProvidedSection(),
            _buildForecastSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProvidedSection() {
    final providedData =
        widget.forecastData.where((tool) => tool['provided'] == true).toList();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _isProvidedCollapsed = !isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            headerBuilder: (BuildContext context, bool isExpanded) {
              return const ListTile(
                title: Text(
                  'Bereitgestellte Werkzeuge',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
            body: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  columnSpacing: 20,
                  columns: _buildColumns(),
                  rows:
                      providedData.map((tool) => _buildDataRow(tool)).toList(),
                ),
              ),
            ),
            isExpanded: !_isProvidedCollapsed,
          ),
        ],
      ),
    );
  }

  Widget _buildForecastSection() {
    final forecastData =
        widget.forecastData.where((tool) => tool['provided'] != true).toList();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _isForecastCollapsed = !isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            headerBuilder: (BuildContext context, bool isExpanded) {
              return const ListTile(
                title: Text(
                  'Werkzeugvorschau',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
            body: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  columnSpacing: 20,
                  columns: _buildColumns(),
                  rows:
                      forecastData.map((tool) => _buildDataRow(tool)).toList(),
                ),
              ),
            ),
            isExpanded: !_isForecastCollapsed,
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    return const [
      DataColumn(
        label: Text(
          'Starttermin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      DataColumn(
        label: Text(
          'Bereitstellung',
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
          'Längswzgr',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      DataColumn(
        label: Text(
          'Verpwzgr',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      DataColumn(
        label: Text(
          'Status',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ];
  }

  DataRow _buildDataRow(Map<String, dynamic> tool) {
    String lengthcuttoolgroup =
        (tool['lengthcuttoolgroup']?.toString().split(' ')[0] ?? 'Ohne');
    String packagingtoolgroup =
        (tool['packagingtoolgroup']?.toString().split(' ')[0] ?? 'Ohne');

    bool highlightRow = !(lengthcuttoolgroup == 'Ohne' ||
        lengthcuttoolgroup.startsWith('Gr.1'));
    bool isInactive = tool['internalstatus'] != 'aktiv';
    bool isOutOfStock = tool['provided'] ?? false;

    return _buildPulsatingRow(tool, highlightRow, isInactive, [
      DataCell(Text(_formatDate(tool['PlanStartDatum']))),
      DataCell(_buildStockStatusCell(isOutOfStock)),
      DataCell(Text(tool['Hauptartikel'] ?? 'N/A')),
      DataCell(
        Text(tool['Equipment'] ?? 'N/A'),
        onTap: () {
          if (tool['Equipment'] != null && tool['Equipment'] != 'N/A') {
            _navigateToEditTool(context, tool['Equipment']);
          }
        },
      ),
      DataCell(Text(tool['Arbeitsplatz'] ?? 'N/A')),
      DataCell(Text(lengthcuttoolgroup)),
      DataCell(Text(packagingtoolgroup)),
      DataCell(Text(tool['internalstatus'] ?? 'N/A')),
    ]);
  }

  DataRow _buildPulsatingRow(Map<String, dynamic> tool, bool highlightRow,
      bool isInactive, List<DataCell> cells) {
    if (!isInactive) {
      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
          if (highlightRow) {
            return Colors.orange.withOpacity(0.3); // Highlight in orange
          }
          return null;
        }),
        cells: cells,
      );
    }

    return DataRow(
      cells: cells.map((cell) {
        return DataCell(
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.5, end: 1.0),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: cell.child,
              );
            },
            onEnd: () {
              Future.delayed(const Duration(milliseconds: 500), () {
                _verticalController.jumpTo(_verticalController.offset);
              });
            },
          ),
          onTap: cell.onTap,
        );
      }).toList(),
      color: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
        return Colors.red.withOpacity(0.3); // Highlight in red for inactive
      }),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  void _navigateToEditTool(
      BuildContext context, String? equipmentNumber) async {
    if (equipmentNumber == null ||
        equipmentNumber.isEmpty ||
        equipmentNumber == 'N/A') return;

    try {
      _showLoadingDialog(context);
      final Tool? tool = await _toolService.fetchToolByNumber(equipmentNumber);
      Navigator.pop(context);

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

  Widget _buildStockStatusCell(bool isOutOfStock) {
    return Row(
      children: [
        Icon(
          isOutOfStock ? Icons.cancel : Icons.check_circle,
          color: isOutOfStock ? Colors.red : Colors.green,
        ),
        const SizedBox(width: 4),
        Text(
          isOutOfStock ? 'Ausgelagert' : 'Eingelagert',
          style: TextStyle(
            color: isOutOfStock ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

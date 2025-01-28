// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
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

  // We store the separated data for Provided and Forecast in state,
  // so we can sort them as needed.
  late List<Map<String, dynamic>> _providedData;
  late List<Map<String, dynamic>> _forecastData;

  // Track which column is sorted and ascending/descending for provided data
  int _sortColumnIndexProvided = 0; // Default to Starttermin column index
  bool _sortAscendingProvided = true; // Default ascending

  // Track which column is sorted and ascending/descending for forecast data
  int _sortColumnIndexForecast = 0; // Default to Starttermin column index
  bool _sortAscendingForecast = true; // Default ascending

  @override
  void initState() {
    super.initState();
    // Separate providedData and forecastData
    _providedData =
        widget.forecastData.where((tool) => tool['provided'] == true).toList();
    _forecastData =
        widget.forecastData.where((tool) => tool['provided'] != true).toList();

    // Default sort by Starttermin (column index 0) ascending
    _sortProvidedData(_sortColumnIndexProvided, _sortAscendingProvided);
    _sortForecastData(_sortColumnIndexForecast, _sortAscendingForecast);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Werkzeugvorschau (Letzte Aktualisierung: ${widget.lastUpdated})',
        ),
        backgroundColor: const Color(0xFF104382),
        titleTextStyle: const TextStyle(
          color: Colors.white, // Set the text color to white
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        controller: _verticalController,
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

  // -- Provided Section

  Widget _buildProvidedSection() {
    if (kDebugMode) {
      print(
        "Provided Data includes: ${_providedData.map((tool) => tool['Equipment']).toList()}",
      );
    }

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
                  sortColumnIndex: _sortColumnIndexProvided,
                  sortAscending: _sortAscendingProvided,
                  showCheckboxColumn: false,
                  columnSpacing: 20,
                  columns: _buildColumns(
                    isProvidedTable: true,
                  ),
                  rows:
                      _providedData.map((tool) => _buildDataRow(tool)).toList(),
                ),
              ),
            ),
            isExpanded: !_isProvidedCollapsed,
          ),
        ],
      ),
    );
  }

  // -- Forecast Section

  Widget _buildForecastSection() {
    if (kDebugMode) {
      print(
        "Forecast Data includes: ${_forecastData.map((tool) => tool['Equipment']).toList()}",
      );
    }

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
                  sortColumnIndex: _sortColumnIndexForecast,
                  sortAscending: _sortAscendingForecast,
                  showCheckboxColumn: false,
                  columnSpacing: 20,
                  columns: _buildColumns(
                    isProvidedTable: false,
                  ),
                  rows:
                      _forecastData.map((tool) => _buildDataRow(tool)).toList(),
                ),
              ),
            ),
            isExpanded: !_isForecastCollapsed,
          ),
        ],
      ),
    );
  }

  // -- Build Columns

  /// The only difference between the Provided and Forecast tables is which data
  /// list they sort. So we use `isProvidedTable` to distinguish in [onSort].
  List<DataColumn> _buildColumns({required bool isProvidedTable}) {
    return [
      DataColumn(
        label: const Text(
          'Starttermin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // We set the onSort callback for each column
        onSort: (columnIndex, ascending) {
          if (isProvidedTable) {
            _sortProvidedData(columnIndex, ascending);
          } else {
            _sortForecastData(columnIndex, ascending);
          }
        },
      ),
      DataColumn(
        label: const Text(
          'Bereitstellung',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: (columnIndex, ascending) {
          if (isProvidedTable) {
            _sortProvidedData(columnIndex, ascending);
          } else {
            _sortForecastData(columnIndex, ascending);
          }
        },
      ),
      DataColumn(
        label: const Text(
          'Hauptartikel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: (columnIndex, ascending) {
          if (isProvidedTable) {
            _sortProvidedData(columnIndex, ascending);
          } else {
            _sortForecastData(columnIndex, ascending);
          }
        },
      ),
      DataColumn(
        label: const Text(
          'Werkzeug',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: (columnIndex, ascending) {
          if (isProvidedTable) {
            _sortProvidedData(columnIndex, ascending);
          } else {
            _sortForecastData(columnIndex, ascending);
          }
        },
      ),
      DataColumn(
        label: const Text(
          'Arbeitsplatz',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: (columnIndex, ascending) {
          if (isProvidedTable) {
            _sortProvidedData(columnIndex, ascending);
          } else {
            _sortForecastData(columnIndex, ascending);
          }
        },
      ),
      DataColumn(
        label: const Text(
          'Längswzgr',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: (columnIndex, ascending) {
          if (isProvidedTable) {
            _sortProvidedData(columnIndex, ascending);
          } else {
            _sortForecastData(columnIndex, ascending);
          }
        },
      ),
      DataColumn(
        label: const Text(
          'Verpwzgr',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: (columnIndex, ascending) {
          if (isProvidedTable) {
            _sortProvidedData(columnIndex, ascending);
          } else {
            _sortForecastData(columnIndex, ascending);
          }
        },
      ),
      DataColumn(
        label: const Text(
          'Status',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: (columnIndex, ascending) {
          if (isProvidedTable) {
            _sortProvidedData(columnIndex, ascending);
          } else {
            _sortForecastData(columnIndex, ascending);
          }
        },
      ),
    ];
  }

  // -- Sort Logic

  /// Sort the Provided Data
  void _sortProvidedData(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndexProvided = columnIndex;
      _sortAscendingProvided = ascending;

      _providedData.sort((a, b) => _compareCells(a, b, columnIndex, ascending));
    });
  }

  /// Sort the Forecast Data
  void _sortForecastData(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndexForecast = columnIndex;
      _sortAscendingForecast = ascending;

      _forecastData.sort((a, b) => _compareCells(a, b, columnIndex, ascending));
    });
  }

  /// A helper method to compare row data based on which column was tapped.
  int _compareCells(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    int columnIndex,
    bool ascending,
  ) {
    late int compareResult;

    switch (columnIndex) {
      // Starttermin
      case 0:
        final dateA = _tryParseDate(a['PlanStartDatum']);
        final dateB = _tryParseDate(b['PlanStartDatum']);
        compareResult = dateA.compareTo(dateB);
        break;

      // Bereitstellung
      case 1:
        // This is a boolean comparison: 'provided' = true/false
        final bool valA = (a['provided'] == true);
        final bool valB = (b['provided'] == true);
        compareResult = valA == valB
            ? 0
            : (valA
                ? 1
                : -1); // you could also invert if you prefer false first
        break;

      // Hauptartikel
      case 2:
        final String valA = a['Hauptartikel'] ?? '';
        final String valB = b['Hauptartikel'] ?? '';
        compareResult = valA.compareTo(valB);
        break;

      // Werkzeug (Equipment)
      case 3:
        final String valA = a['Equipment'] ?? '';
        final String valB = b['Equipment'] ?? '';
        compareResult = valA.compareTo(valB);
        break;

      // Arbeitsplatz
      case 4:
        final String valA = a['Arbeitsplatz'] ?? '';
        final String valB = b['Arbeitsplatz'] ?? '';
        compareResult = valA.compareTo(valB);
        break;

      // Längswzgr
      case 5:
        final String valA =
            (a['lengthcuttoolgroup']?.toString().split(' ')[0]) ?? 'Ohne';
        final String valB =
            (b['lengthcuttoolgroup']?.toString().split(' ')[0]) ?? 'Ohne';
        compareResult = valA.compareTo(valB);
        break;

      // Verpwzgr
      case 6:
        final String valA =
            (a['packagingtoolgroup']?.toString().split(' ')[0]) ?? 'Ohne';
        final String valB =
            (b['packagingtoolgroup']?.toString().split(' ')[0]) ?? 'Ohne';
        compareResult = valA.compareTo(valB);
        break;

      // Status
      case 7:
        final String valA = a['internalstatus'] ?? 'N/A';
        final String valB = b['internalstatus'] ?? 'N/A';
        compareResult = valA.compareTo(valB);
        break;

      default:
        compareResult = 0;
    }

    return ascending ? compareResult : -compareResult;
  }

  DateTime _tryParseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      // Return a default fallback date
      return DateTime(1900);
    }
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      // Return a default fallback if parse fails
      return DateTime(1900);
    }
  }

  // -- Build Each Data Row

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

  /// Updated method to handle the blueAccent case (freestatus_id == 37 or 133).
  DataRow _buildPulsatingRow(
    Map<String, dynamic> tool,
    bool highlightRow,
    bool isInactive,
    List<DataCell> cells,
  ) {
    // Always print something when the method is called, so we know it's invoked.
    if (kDebugMode) {
      print(
        '[DEBUG] _buildPulsatingRow called. '
        'Equipment: ${tool['Equipment']} | '
        'freestatus_id: ${tool['freestatus_id']} | '
        'isInactive: $isInactive | '
        'highlightRow: $highlightRow',
      );
    }

    final bool isFreeStatusBlue =
        (tool['freestatus_id'] == 37 || tool['freestatus_id'] == 133);

    // If the tool is inactive, return a red pulsating row.
    if (isInactive) {
      if (kDebugMode) {
        print('[DEBUG] --> Using RED pulsating row (tool is inactive).');
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
          },
        ),
      );
    }
    // Else if freestatus_id = 37 or 133, highlight in blueAccent.
    else if (isFreeStatusBlue) {
      if (kDebugMode) {
        print('[DEBUG] --> Using BLUE accent row (freestatus_id = 37 or 133).');
      }
      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
            return Colors.blueAccent.withOpacity(0.3); // Highlight in blue
          },
        ),
        cells: cells,
      );
    }
    // Else if "highlightRow" is true, highlight in orange.
    else if (highlightRow) {
      if (kDebugMode) {
        print('[DEBUG] --> Using ORANGE highlight row (highlightRow=true).');
      }
      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
            return Colors.orange.withOpacity(0.3);
          },
        ),
        cells: cells,
      );
    }
    // Otherwise, no special highlight.
    else {
      if (kDebugMode) {
        print('[DEBUG] --> Using NO special highlight.');
      }
      return DataRow(
        cells: cells,
      );
    }
  }

  // -- Utility Methods

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

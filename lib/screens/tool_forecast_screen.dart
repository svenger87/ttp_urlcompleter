// tool_forecast_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttp_app/models/tool.dart';
import '../services/tool_service.dart';
import 'edit_tool_screen.dart';

class ToolForecastScreen extends StatefulWidget {
  final List<Map<String, dynamic>> forecastData;
  final String lastUpdated;

  const ToolForecastScreen({
    super.key,
    required this.forecastData,
    required this.lastUpdated,
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
  bool _isProvidedWithoutOrdersCollapsed = true;

  late List<Map<String, dynamic>> _providedData;
  late List<Map<String, dynamic>> _forecastData;
  late List<Map<String, dynamic>> _providedWithoutOrdersData;

  int _sortColumnIndexProvided = 0;
  bool _sortAscendingProvided = true;

  int _sortColumnIndexForecast = 0;
  bool _sortAscendingForecast = true;

  int _sortColumnIndexProvidedWithoutOrders = 0;
  bool _sortAscendingProvidedWithoutOrders = true;

  @override
  void initState() {
    super.initState();
    _providedData =
        widget.forecastData.where((tool) => tool['provided'] == true).toList();
    _forecastData =
        widget.forecastData.where((tool) => tool['provided'] != true).toList();

    final twoWeeksFromNow = DateTime.now().add(const Duration(days: 14));
    _providedWithoutOrdersData = _providedData.where((tool) {
      bool hasOrder = tool.containsKey('Auftragsnummer') &&
          tool['Auftragsnummer'] != null &&
          tool['Auftragsnummer'].toString().trim().isNotEmpty;

      final String? planStartDatum = tool['PlanStartDatum'];
      if (planStartDatum == null || planStartDatum.isEmpty) {
        return !hasOrder;
      }
      final toolDate = _tryParseDate(planStartDatum);
      return !hasOrder && toolDate.isAfter(twoWeeksFromNow);
    }).toList();

    _sortProvidedData(_sortColumnIndexProvided, _sortAscendingProvided);
    _sortForecastData(_sortColumnIndexForecast, _sortAscendingForecast);
    _sortProvidedWithoutOrdersData(_sortColumnIndexProvidedWithoutOrders,
        _sortAscendingProvidedWithoutOrders);
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: We removed the Scaffold wrapper so that the ToolForecastWrapper’s
    // Scaffold (with the app bar and bottom nav) is used.
    return SingleChildScrollView(
      controller: _verticalController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProvidedSection(),
          _buildForecastSection(),
          _buildProvidedWithoutOrdersSection(),
        ],
      ),
    );
  }

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
                    onSort: (columnIndex, ascending) =>
                        _sortProvidedData(columnIndex, ascending),
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
                    onSort: (columnIndex, ascending) =>
                        _sortForecastData(columnIndex, ascending),
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

  Widget _buildProvidedWithoutOrdersSection() {
    if (kDebugMode) {
      print(
        "Provided Without Orders Data includes: ${_providedWithoutOrdersData.map((tool) => tool['Equipment']).toList()}",
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _isProvidedWithoutOrdersCollapsed = !isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            headerBuilder: (BuildContext context, bool isExpanded) {
              return const ListTile(
                title: Text(
                  'Bereitgestellte Werkzeuge ohne Produktionsaufträge',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
            body: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: _sortColumnIndexProvidedWithoutOrders,
                  sortAscending: _sortAscendingProvidedWithoutOrders,
                  showCheckboxColumn: false,
                  columnSpacing: 20,
                  columns: _buildColumns(
                    isProvidedTable: true,
                    onSort: (columnIndex, ascending) =>
                        _sortProvidedWithoutOrdersData(columnIndex, ascending),
                  ),
                  rows: _providedWithoutOrdersData
                      .map((tool) => _buildDataRow(tool))
                      .toList(),
                ),
              ),
            ),
            isExpanded: !_isProvidedWithoutOrdersCollapsed,
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns({
    required bool isProvidedTable,
    required void Function(int columnIndex, bool ascending) onSort,
  }) {
    return [
      DataColumn(
        label: const Text(
          'Starttermin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: onSort,
      ),
      DataColumn(
        label: const Text(
          'Bereitstellung',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: onSort,
      ),
      DataColumn(
        label: const Text(
          'Hauptartikel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: onSort,
      ),
      DataColumn(
        label: const Text(
          'Werkzeug',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: onSort,
      ),
      DataColumn(
        label: const Text(
          'Arbeitsplatz',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: onSort,
      ),
      DataColumn(
        label: const Text(
          'Längswzgr',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: onSort,
      ),
      DataColumn(
        label: const Text(
          'Verpwzgr',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: onSort,
      ),
      DataColumn(
        label: const Text(
          'Status',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: onSort,
      ),
    ];
  }

  void _sortProvidedData(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndexProvided = columnIndex;
      _sortAscendingProvided = ascending;

      _providedData.sort((a, b) => _compareCells(a, b, columnIndex, ascending));
    });
  }

  void _sortForecastData(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndexForecast = columnIndex;
      _sortAscendingForecast = ascending;

      _forecastData.sort((a, b) => _compareCells(a, b, columnIndex, ascending));
    });
  }

  void _sortProvidedWithoutOrdersData(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndexProvidedWithoutOrders = columnIndex;
      _sortAscendingProvidedWithoutOrders = ascending;

      _providedWithoutOrdersData
          .sort((a, b) => _compareCells(a, b, columnIndex, ascending));
    });
  }

  int _compareCells(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    int columnIndex,
    bool ascending,
  ) {
    late int compareResult;

    switch (columnIndex) {
      case 0:
        final dateA = _tryParseDate(a['PlanStartDatum']);
        final dateB = _tryParseDate(b['PlanStartDatum']);
        compareResult = dateA.compareTo(dateB);
        break;
      case 1:
        final bool valA = (a['provided'] == true);
        final bool valB = (b['provided'] == true);
        compareResult = valA == valB ? 0 : (valA ? 1 : -1);
        break;
      case 2:
        final String valA = a['Hauptartikel'] ?? '';
        final String valB = b['Hauptartikel'] ?? '';
        compareResult = valA.compareTo(valB);
        break;
      case 3:
        final String valA = a['Equipment'] ?? '';
        final String valB = b['Equipment'] ?? '';
        compareResult = valA.compareTo(valB);
        break;
      case 4:
        final String valA = a['Arbeitsplatz'] ?? '';
        final String valB = b['Arbeitsplatz'] ?? '';
        compareResult = valA.compareTo(valB);
        break;
      case 5:
        final String valA =
            (a['lengthcuttoolgroup']?.toString().split(' ')[0]) ?? 'Ohne';
        final String valB =
            (b['lengthcuttoolgroup']?.toString().split(' ')[0]) ?? 'Ohne';
        compareResult = valA.compareTo(valB);
        break;
      case 6:
        final String valA =
            (a['packagingtoolgroup']?.toString().split(' ')[0]) ?? 'Ohne';
        final String valB =
            (b['packagingtoolgroup']?.toString().split(' ')[0]) ?? 'Ohne';
        compareResult = valA.compareTo(valB);
        break;
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
      return DateTime(1900);
    }
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      return DateTime(1900);
    }
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

  DataRow _buildPulsatingRow(
    Map<String, dynamic> tool,
    bool highlightRow,
    bool isInactive,
    List<DataCell> cells,
  ) {
    final bool isFreeStatusBlue =
        (tool['freestatus_id'] == 37 || tool['freestatus_id'] == 133);

    if (isInactive) {
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
            return Colors.red.withOpacity(0.3);
          },
        ),
      );
    } else if (isFreeStatusBlue) {
      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
            return Colors.blueAccent.withOpacity(0.3);
          },
        ),
        cells: cells,
      );
    } else if (highlightRow) {
      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
            return Colors.orange.withOpacity(0.3);
          },
        ),
        cells: cells,
      );
    } else {
      return DataRow(
        cells: cells,
      );
    }
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
        equipmentNumber == 'N/A') {
      return;
    }

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

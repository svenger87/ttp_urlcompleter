import 'package:flutter/material.dart';
import 'package:ttp_app/screens/tool_forecast_screen.dart';
import 'pin_entry_screen.dart';
import '../services/tool_service.dart';
import '../models/tool.dart';
import 'edit_tool_screen.dart';
import 'storage_utilization_screen.dart';

class ToolInventoryScreen extends StatefulWidget {
  const ToolInventoryScreen({Key? key}) : super(key: key);

  @override
  ToolInventoryScreenState createState() => ToolInventoryScreenState();
}

class ToolInventoryScreenState extends State<ToolInventoryScreen> {
  final ToolService toolService = ToolService();
  List<Tool> _toolsWithStorage = [];
  List<Tool> _toolsWithoutStorage = [];
  String _filterQuery = '';
  bool _isLoading = true;
  String? _errorMessage;
  bool _isToolsWithStorageCollapsed = false; // Uncollapsed by default
  bool _isToolsWithoutStorageCollapsed = true; // Collapsed by default
  bool _toolsLoaded = false; // Track if tools are loaded

  final TextEditingController _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPinScreen());
  }

  void _showPinScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinEntryScreen(
          onSubmit: (pin) {
            if (pin == '3006') {
              Navigator.pop(context, true); // PIN is correct
            } else {
              Navigator.pop(context, false); // PIN is incorrect
            }
          },
        ),
      ),
    );

    if (result == true && !_toolsLoaded) {
      _loadTools();
    } else if (!_toolsLoaded) {
      // Prevent loading if tools are already loaded
      // ignore: use_build_context_synchronously
      Navigator.pop(context); // Close the screen if PIN is incorrect
    }
  }

  Future<void> _loadTools() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final toolsData = await toolService.fetchTools();
      setState(() {
        _toolsWithStorage = toolsData['has_storage']!;
        _toolsWithoutStorage = toolsData['has_no_storage']!;
        _applyFilters();
        _isLoading = false;
        _toolsLoaded = true; // Mark tools as loaded
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler beim Laden der Werkzeuge: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      bool hasFilteredWithoutStorage =
          _filterTools(_toolsWithoutStorage).isNotEmpty;
      _isToolsWithoutStorageCollapsed = !hasFilteredWithoutStorage;
    });
  }

  List<Tool> _filterTools(List<Tool> tools) {
    return tools.where((tool) {
      final lowerCaseQuery = _filterQuery.toLowerCase();
      return tool.toolNumber.toLowerCase().contains(lowerCaseQuery) ||
          (tool.storageLocationOne?.toLowerCase().contains(lowerCaseQuery) ??
              false) ||
          (tool.storageLocationTwo?.toLowerCase().contains(lowerCaseQuery) ??
              false) ||
          tool.storageStatus.toLowerCase().contains(lowerCaseQuery);
    }).toList();
  }

  Future<void> _navigateToEditTool(Tool tool) async {
    final isUpdated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditToolScreen(tool: tool),
      ),
    );
    if (isUpdated == true) {
      await _loadTools();
    }
  }

  void _clearFilter() {
    setState(() {
      _filterController.clear();
      _filterQuery = '';
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadToolForecast() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final forecastData = await toolService.fetchToolForecast();
      // ignore: use_build_context_synchronously
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ToolForecastScreen(forecastData: forecastData),
        ),
      );

      // Ensure toolsLoaded is set to true after returning
      setState(() {
        _isLoading = false;
        _toolsLoaded = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Fehler beim Laden der Werkzeugbereitstellungsvorhersage: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF104382),
        title: const Text('Werkzeuglager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTools,
          ),
          IconButton(
            icon: const Icon(Icons.storage),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StorageUtilizationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
                Icons.pending_actions), // Add new button for tool forecast
            onPressed:
                _loadToolForecast, // Call the method to load the tool forecast
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchBar(),
                      _buildToolsWithStorageSection(), // Uncollapsed by default
                      _buildToolsWithoutStorageSection(), // Collapsed by default
                    ],
                  ),
                ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Filter nach Werkzeug, Lagerplatz oder Lagerstatus',
                border: OutlineInputBorder(),
              ),
              controller: _filterController,
              onChanged: (value) {
                setState(() {
                  _filterQuery = value;
                  _applyFilters();
                });
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearFilter,
          ),
        ],
      ),
    );
  }

  Widget _buildToolsWithStorageSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _isToolsWithStorageCollapsed = !isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            headerBuilder: (BuildContext context, bool isExpanded) {
              return const ListTile(
                title: Text(
                  'Werkzeuge mit Lagerplatz',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
            body: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildToolTable(_filterTools(_toolsWithStorage)),
              ),
            ),
            isExpanded: !_isToolsWithStorageCollapsed,
          ),
        ],
      ),
    );
  }

  Widget _buildToolsWithoutStorageSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _isToolsWithoutStorageCollapsed = isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            headerBuilder: (BuildContext context, bool isExpanded) {
              return const ListTile(
                title: Text(
                  'Werkzeuge ohne Lagerplatz',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
            body: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildToolTable(_filterTools(_toolsWithoutStorage)),
              ),
            ),
            isExpanded:
                _isToolsWithoutStorageCollapsed, // Collapse the section by default
          ),
        ],
      ),
    );
  }

  Widget _buildToolTable(List<Tool> tools) {
    if (tools.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Keine Werkzeuge gefunden'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 10, // Reduce spacing between columns
        // ignore: deprecated_member_use
        dataRowHeight: 40, // Reduce the height of each row
        columns: const [
          DataColumn(label: Text('Werkzeugnummer')),
          DataColumn(label: Text('Lagerplatz 1')),
          DataColumn(label: Text('Belegter Platz 1')),
          DataColumn(label: Text('Lagerplatz 2')),
          DataColumn(label: Text('Belegter Platz 2')),
          DataColumn(label: Text('Lagerstatus')),
        ],
        rows: tools.map((tool) {
          return DataRow(
            cells: [
              DataCell(Text(tool.toolNumber),
                  onTap: () => _navigateToEditTool(tool)),
              DataCell(Text(tool.storageLocationOne ?? 'Ohne')),
              DataCell(Text(tool.usedSpacePitchOne ?? 'Ohne')),
              DataCell(Text(tool.storageLocationTwo ?? 'Ohne')),
              DataCell(Text(tool.usedSpacePitchTwo ?? 'Ohne')),
              DataCell(_buildStockStatusCell(tool)), // Use the modified method
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStockStatusCell(Tool tool) {
    bool isOutOfStock = tool.provided; // Use the 'provided' field directly

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

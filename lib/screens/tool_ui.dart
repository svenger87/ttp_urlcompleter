import 'package:flutter/material.dart';
import '../services/tool_service.dart';
import '../models/tool.dart';
import 'edit_tool_screen.dart';
import 'storage_utilization_screen.dart';

class ToolInventoryScreen extends StatefulWidget {
  const ToolInventoryScreen({super.key});

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
  bool _isToolsWithoutStorageCollapsed = true;

  // Add TextEditingController for managing filter input
  final TextEditingController _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  Future<void> _loadTools() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch tools from the API
      final toolsData = await toolService.fetchTools();

      setState(() {
        _toolsWithStorage = toolsData['has_storage']!;
        _toolsWithoutStorage = toolsData['has_no_storage']!;
        _applyFilters(); // Apply initial filter (if needed)
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler beim Laden der Werkzeuge: $e';
        _isLoading = false;
      });
    }
  }

  // Apply filter to tools with and without storage
  void _applyFilters() {
    setState(() {
      bool hasFilteredWithoutStorage =
          _filterTools(_toolsWithoutStorage).isNotEmpty;

      // Automatically expand "Tools without Storage" section if filter applies to them
      _isToolsWithoutStorageCollapsed = !hasFilteredWithoutStorage;
    });
  }

  // Filters a given tool list by the current filter query (tool number, storage location, or stock status)
  List<Tool> _filterTools(List<Tool> tools) {
    return tools.where((tool) {
      return tool.toolNumber
              .toLowerCase()
              .contains(_filterQuery.toLowerCase()) ||
          (tool.storageLocationOne
                  ?.toLowerCase()
                  .contains(_filterQuery.toLowerCase()) ??
              false) ||
          (tool.storageLocationTwo
                  ?.toLowerCase()
                  .contains(_filterQuery.toLowerCase()) ??
              false) ||
          tool.storageStatus.toLowerCase().contains(_filterQuery.toLowerCase());
    }).toList();
  }

  Future<void> _navigateToEditTool(Tool tool) async {
    // After editing, refresh the list only if the tool was updated
    final isUpdated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditToolScreen(tool: tool),
      ),
    );

    // Check if the tool was updated, if true, reload the tools
    if (isUpdated == true) {
      await _loadTools(); // This re-fetches tools from the backend
    }
  }

  // Clears the current filter
  void _clearFilter() {
    setState(() {
      _filterController.clear();
      _filterQuery = '';
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _filterController.dispose(); // Dispose of the controller when done
    super.dispose();
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
                      _buildSectionTitle('Werkzeuge mit Lagerplatz'),
                      _buildToolTable(_filterTools(_toolsWithStorage)),
                      _buildToolsWithoutStorageSection(),
                    ],
                  ),
                ),
    );
  }

  // Search bar to filter tools by their number, storage, or stock status
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

  // Build the section title
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
      ),
    );
  }

  // Build the tool table with headers and content
  Widget _buildToolTable(List<Tool> tools) {
    if (tools.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Keine Werkzeuge gefunden'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // Enable horizontal scrolling
      child: DataTable(
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
              DataCell(_buildStockStatusCell(tool.storageStatus)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Build the stock status cell with icon and color
  Widget _buildStockStatusCell(String status) {
    bool isInStock = status == 'In stock';
    return Row(
      children: [
        Icon(
          isInStock ? Icons.check_circle : Icons.cancel,
          color: isInStock ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 4),
        Text(
          isInStock ? 'Eingelagert' : 'Ausgelagert', // Translate for display
          style: TextStyle(
            color: isInStock ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Build the collapsible section for tools without storage
  Widget _buildToolsWithoutStorageSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _isToolsWithoutStorageCollapsed = !isExpanded;
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
              alignment:
                  Alignment.centerLeft, // Ensure the table is aligned left
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildToolTable(_filterTools(_toolsWithoutStorage)),
              ),
            ),
            isExpanded: !_isToolsWithoutStorageCollapsed,
          ),
        ],
      ),
    );
  }
}

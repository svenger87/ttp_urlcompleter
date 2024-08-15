// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'tool_service.dart';
import 'tool.dart';
import 'edit_tool_screen.dart';

class ToolInventoryScreen extends StatefulWidget {
  const ToolInventoryScreen({super.key});

  @override
  _ToolInventoryScreenState createState() => _ToolInventoryScreenState();
}

class _ToolInventoryScreenState extends State<ToolInventoryScreen> {
  final ToolService toolService = ToolService();
  List<Tool> _allTools = [];
  List<Tool> _filteredTools = [];
  String _toolFilter = '';
  String _storageLocationFilter = '';
  String _storageStatusFilter = '';
  bool _isUpdatingTools = false;

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  Future<void> _loadTools() async {
    try {
      final tools = await toolService.fetchTools();
      setState(() {
        _allTools = tools;
        _applyFilters();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tools: $e')),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTools = _allTools.where((tool) {
        final matchesToolNumber = tool.toolNumber.contains(_toolFilter);
        final matchesStorageLocation =
            tool.storageLocation.contains(_storageLocationFilter);
        final matchesStorageStatus = _storageStatusFilter.isEmpty ||
            tool.storageStatus == _storageStatusFilter;
        return matchesToolNumber &&
            matchesStorageLocation &&
            matchesStorageStatus;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _toolFilter = '';
      _storageLocationFilter = '';
      _storageStatusFilter = '';
      _filteredTools = List.from(_allTools);
    });
  }

  Future<void> _updateTools() async {
    setState(() {
      _isUpdatingTools = true;
    });

    try {
      await toolService.updateTools();
      await _loadTools();
      // Show a success message when tools are successfully updated
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Werkzeuge erfolgreich aktualisiert!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating tools: $e')),
      );
    } finally {
      setState(() {
        _isUpdatingTools = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Adjust the padding and font size based on screen width
    double fontSize = 14;  // Keep the font size consistent
    double paddingSize = 4.0;  // Reduced padding to make better use of space
    double buttonHeight = 30;  // Set a fixed height for buttons

    return Scaffold(
      appBar: AppBar(
        title: const Text('Werkzeuglagerverwaltung'),
        backgroundColor: const Color(0xFF104382),
        actions: [
          _isUpdatingTools
              ? const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4.0,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _updateTools,
                ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(paddingSize),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Werkzeugnr.',
                      labelStyle: TextStyle(fontSize: fontSize),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _toolFilter = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                SizedBox(width: paddingSize),
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Lagerpl.',
                      labelStyle: TextStyle(fontSize: fontSize),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _storageLocationFilter = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                SizedBox(width: paddingSize),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Status',
                      labelStyle: TextStyle(fontSize: fontSize),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    ),
                    value: _storageStatusFilter.isEmpty
                        ? null
                        : _storageStatusFilter,
                    onChanged: (value) {
                      setState(() {
                        _storageStatusFilter = value ?? '';
                        _applyFilters();
                      });
                    },
                    items: <String>['', 'In stock', 'Out of stock']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.isEmpty
                            ? 'Alle'
                            : value == 'In stock'
                                ? 'Auf Lager'
                                : 'Nicht auf Lager'),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(width: paddingSize),
                SizedBox(
                  height: buttonHeight,
                  child: ElevatedButton(
                    onPressed: _clearFilters,
                    child: const Text('Löschen'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTools.length,
              itemBuilder: (context, index) {
                final tool = _filteredTools[index];

                // Ensure storage status is correctly interpreted and displayed
                Color statusColor = tool.storageStatus == 'In stock'
                    ? Colors.green
                    : Colors.red;

                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: paddingSize, vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ListTile(
                          title: Text(
                            tool.toolNumber,
                            style: TextStyle(fontSize: fontSize),
                          ),
                          subtitle: Text(
                            'Nr.: ${tool.toolNumber}',
                            style: TextStyle(fontSize: fontSize - 2),
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditToolScreen(tool: tool),
                              ),
                            );
                            _loadTools(); // Refresh the tool list
                          },
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          tool.storageLocation.isNotEmpty
                              ? tool.storageLocation
                              : 'Unbekannt',
                          style: TextStyle(fontSize: fontSize),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: statusColor, // Use the statusColor variable here
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            tool.storageStatus == 'In stock'
                                ? 'Auf Lager'
                                : 'Nicht auf Lager',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

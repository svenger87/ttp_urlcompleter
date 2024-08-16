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
  String _storageStatusFilter = ''; // Represents the selected filter value
  bool _isUpdatingTools = false;
  bool _isLoading = true;
  String? _errorMessage;

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
      // Fetch tools from the API including the correct storage states
      final tools = await toolService.fetchTools();

      // Sort the tools by storage location
      tools.sort(
          (a, b) => _compareStorageNames(a.storageLocation, b.storageLocation));

      // Update the tool list in the state
      setState(() {
        _allTools = tools;
        _applyFilters(); // Re-apply filters to update the displayed list
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading tools: $e';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  // Custom compare function for storage locations
  int _compareStorageNames(String a, String b) {
    final regex = RegExp(r'R(\d+)-E(\d+)-S(\d+)');
    final matchA = regex.firstMatch(a);
    final matchB = regex.firstMatch(b);

    if (matchA != null && matchB != null) {
      // Both match the R-E-S pattern, compare by row, then element, then shelf
      final int rowA = int.parse(matchA.group(1)!);
      final int rowB = int.parse(matchB.group(1)!);

      if (rowA != rowB) {
        return rowA.compareTo(rowB);
      }

      final int elementA = int.parse(matchA.group(2)!);
      final int elementB = int.parse(matchB.group(2)!);

      if (elementA != elementB) {
        return elementA.compareTo(elementB);
      }

      final int shelfA = int.parse(matchA.group(3)!);
      final int shelfB = int.parse(matchB.group(3)!);

      return shelfA.compareTo(shelfB);
    }

    // If only one matches the pattern, prioritize the matching one
    if (matchA != null && matchB == null) {
      return -1; // a should come before b
    }
    if (matchA == null && matchB != null) {
      return 1; // b should come before a
    }

    // If neither matches, use lexicographical comparison
    return a.compareTo(b);
  }

  void _applyFilters() {
    setState(() {
      _filteredTools = _allTools.where((tool) {
        final matchesToolNumber = tool.toolNumber.contains(_toolFilter);
        final matchesStorageLocation =
            tool.storageLocation.contains(_storageLocationFilter);

        // Ensure storage status is correctly compared
        final matchesStorageStatus = _storageStatusFilter.isEmpty ||
            (tool.storageStatus.toLowerCase() ==
                _storageStatusFilter.toLowerCase());

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
    double fontSize = 14; // Keep the font size consistent
    double paddingSize = 4.0; // Reduced padding to make better use of space
    double buttonHeight = 30; // Set a fixed height for buttons

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Column(
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
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
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
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
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
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
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
                              items: const <String>[
                                '', // Empty for "All"
                                'In stock',
                                'Out of stock'
                              ].map((String value) {
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
                          Color statusColor =
                              tool.storageStatus.toLowerCase() == 'in stock'
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
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Text(
                                      tool.storageStatus.toLowerCase() ==
                                              'in stock'
                                          ? 'Auf Lager'
                                          : 'Nicht auf Lager',
                                      style:
                                          const TextStyle(color: Colors.white),
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

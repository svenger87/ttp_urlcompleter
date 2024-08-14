// ignore_for_file: library_private_types_in_public_api

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

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  Future<void> _loadTools() async {
    final tools = await toolService.fetchTools();
    setState(() {
      _allTools = tools;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredTools = _allTools.where((tool) {
        final matchesToolNumber = tool.toolNumber.contains(_toolFilter);
        final matchesStorageLocation =
            tool.storageLocation.contains(_storageLocationFilter);
        return matchesToolNumber && matchesStorageLocation;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _toolFilter = '';
      _storageLocationFilter = '';
      _filteredTools = List.from(_allTools);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Werkzeuglagerverwaltung')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Filtern nach Werkzeug',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _toolFilter = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Filtern nach Lagerplatz',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _storageLocationFilter = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _clearFilters();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTools.length,
              itemBuilder: (context, index) {
                final tool = _filteredTools[index];
                return ListTile(
                  title: Text(tool.name),
                  subtitle: Text('Werkzeugnummer: ${tool.toolNumber}'),
                  trailing: Text('Lagerplatz: ${tool.storageLocation}'),
                  onTap: () async {
                    // Navigate to the EditToolScreen
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditToolScreen(tool: tool),
                      ),
                    );

                    // Refresh the tool list after returning from edit screen
                    _loadTools();
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Handle add functionality or navigate to add tool screen if needed
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

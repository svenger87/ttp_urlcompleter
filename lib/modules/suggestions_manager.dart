// suggestions_manager.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../screens/pin_entry_screen.dart'; // Import the PIN module

/// The model for a suggestion node.
class PredefinedTextNode {
  final String id;
  final String title;
  final String? text; // Optional text for leaf nodes.
  final int sortOrder;
  final List<PredefinedTextNode> children;

  PredefinedTextNode({
    required this.id,
    required this.title,
    this.text,
    required this.sortOrder,
    this.children = const [],
  });

  factory PredefinedTextNode.fromJson(Map<String, dynamic> json) {
    return PredefinedTextNode(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      text: json['text'],
      sortOrder: json['sort_order'] ?? 0,
      children: json['children'] != null
          ? (json['children'] as List)
              .map((child) => PredefinedTextNode.fromJson(child))
              .toList()
          : [],
    );
  }
}

// Change this URL to match your backend endpoint.
const String suggestionsApiUrl =
    'http://wim-solution.sip.local:3006/suggestions';

/// Fetches the suggestions tree from the backend.
Future<List<PredefinedTextNode>> fetchSuggestions() async {
  final response = await http.get(Uri.parse(suggestionsApiUrl));
  if (response.statusCode == 200) {
    final List<dynamic> jsonData = json.decode(response.body);
    return jsonData.map((node) => PredefinedTextNode.fromJson(node)).toList();
  } else {
    throw Exception(
        'Failed to fetch suggestions: ${response.statusCode} - ${response.reasonPhrase}');
  }
}

/// Adds a new suggestion node.
Future<PredefinedTextNode> addSuggestion({
  String? parentId,
  required String title,
  String? text,
}) async {
  final response = await http.post(
    Uri.parse(suggestionsApiUrl),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      "parent_id": parentId,
      "title": title,
      "text": text,
    }),
  );
  if (response.statusCode == 201) {
    return PredefinedTextNode.fromJson(json.decode(response.body));
  } else {
    throw Exception('Failed to add suggestion: ${response.statusCode}');
  }
}

/// Updates an existing suggestion.
Future<void> updateSuggestion(String id,
    {required String title, String? text, int? sortOrder}) async {
  final response = await http.put(
    Uri.parse('$suggestionsApiUrl/$id'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      "title": title,
      "text": text,
      "sort_order": sortOrder,
    }),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to update suggestion: ${response.statusCode}');
  }
}

/// Deletes a suggestion.
Future<void> deleteSuggestion(String id) async {
  final response = await http.delete(Uri.parse('$suggestionsApiUrl/$id'));
  if (response.statusCode != 200) {
    throw Exception('Failed to delete suggestion: ${response.statusCode}');
  }
}

/// The SuggestionsManager widget is an admin tool for managing suggestions.
class SuggestionsManager extends StatefulWidget {
  const SuggestionsManager({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SuggestionsManagerState createState() => _SuggestionsManagerState();
}

class _SuggestionsManagerState extends State<SuggestionsManager> {
  List<PredefinedTextNode> _suggestions = [];
  bool _loading = false;
  String? _error;
  // Preserve the expanded nodes by their id.
  final Set<String> _expandedNodes = {};

  // PIN authentication state.
  bool _authenticated = false;

  // Hard-coded PIN. In production, use a secure method.
  static const String correctPin = '4444';

  @override
  void initState() {
    super.initState();
    // If already authenticated, load suggestions.
    if (_authenticated) {
      _loadSuggestions();
    }
  }

  /// Called when a PIN is submitted from the PIN module.
  void _handlePinSubmit(String enteredPin) {
    if (enteredPin == correctPin) {
      setState(() {
        _authenticated = true;
      });
      _loadSuggestions();
    } else {
      // Show a brief message if the PIN is incorrect.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falscher PIN!')),
      );
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final suggestions = await fetchSuggestions();
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /// Reorders nodes within a given sibling list.
  Future<void> _updateOrder(List<PredefinedTextNode> siblings) async {
    // Update each sibling's sort_order to its current index.
    for (int i = 0; i < siblings.length; i++) {
      final node = siblings[i];
      try {
        await updateSuggestion(node.id,
            title: node.title, text: node.text, sortOrder: i);
      } catch (e) {
        if (kDebugMode) print('Error updating order for node ${node.id}: $e');
      }
    }
    // Reload suggestions without resetting expanded nodes.
    await _loadSuggestions();
  }

  void _moveUp(List<PredefinedTextNode> siblings, int index) {
    if (index <= 0) return;
    setState(() {
      final temp = siblings[index - 1];
      siblings[index - 1] = siblings[index];
      siblings[index] = temp;
    });
    _updateOrder(siblings);
  }

  void _moveDown(List<PredefinedTextNode> siblings, int index) {
    if (index >= siblings.length - 1) return;
    setState(() {
      final temp = siblings[index + 1];
      siblings[index + 1] = siblings[index];
      siblings[index] = temp;
    });
    _updateOrder(siblings);
  }

  /// Builds a tile for a suggestion node.
  Widget _buildSuggestionTile(
      PredefinedTextNode node, List<PredefinedTextNode> siblings, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        key: PageStorageKey(node.id),
        initiallyExpanded: _expandedNodes.contains(node.id),
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedNodes.add(node.id);
            } else {
              _expandedNodes.remove(node.id);
            }
          });
        },
        title: Row(
          children: [
            const Icon(Icons.arrow_right, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(node.title)),
          ],
        ),
        subtitle: node.text != null ? Text(node.text!) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: 'Editieren',
              onPressed: () => _showEditDialog(node),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.green),
              tooltip: 'Kind hinzufügen',
              onPressed: () => _showAddDialog(parentId: node.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Löschen',
              onPressed: () => _confirmDelete(node),
            ),
            if (index > 0)
              IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.orange),
                tooltip: 'Nach oben verschieben',
                onPressed: () => _moveUp(siblings, index),
              ),
            if (index < siblings.length - 1)
              IconButton(
                icon: const Icon(Icons.arrow_downward, color: Colors.orange),
                tooltip: 'Nach unten verschieben',
                onPressed: () => _moveDown(siblings, index),
              ),
          ],
        ),
        children: node.children.asMap().entries.map((entry) {
          int childIndex = entry.key;
          PredefinedTextNode child = entry.value;
          return _buildSuggestionTile(child, node.children, childIndex);
        }).toList(),
      ),
    );
  }

  /// Shows a dialog to edit an existing suggestion.
  Future<void> _showEditDialog(PredefinedTextNode node) async {
    final titleController = TextEditingController(text: node.title);
    final textController = TextEditingController(text: node.text ?? '');
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Textbaustein bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Titel'),
              ),
              TextField(
                controller: textController,
                decoration: const InputDecoration(labelText: 'Text'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                try {
                  await updateSuggestion(node.id,
                      title: titleController.text.trim(),
                      text: textController.text.trim());
                  Navigator.pop(context);
                  await _loadSuggestions();
                } catch (e) {
                  if (kDebugMode) print(e);
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  /// Shows a dialog to add a new suggestion (optionally as a child).
  Future<void> _showAddDialog({String? parentId}) async {
    final titleController = TextEditingController();
    final textController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Neuen Textbaustein hinzufügen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Titel'),
              ),
              TextField(
                controller: textController,
                decoration: const InputDecoration(labelText: 'Text'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                try {
                  await addSuggestion(
                    parentId: parentId,
                    title: titleController.text.trim(),
                    text: textController.text.trim(),
                  );
                  Navigator.pop(context);
                  await _loadSuggestions();
                } catch (e) {
                  if (kDebugMode) print(e);
                }
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    );
  }

  /// Confirms deletion of a suggestion node.
  Future<void> _confirmDelete(PredefinedTextNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Löschen bestätigen'),
          content:
              const Text('Möchten Sie diesen Textbaustein wirklich löschen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      try {
        await deleteSuggestion(node.id);
        await _loadSuggestions();
      } catch (e) {
        if (kDebugMode) print(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not yet authenticated, show the PIN entry screen.
    if (!_authenticated) {
      return PinEntryScreen(onSubmit: _handlePinSubmit);
    }

    // Otherwise, show the Suggestions Manager.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Textbaustein Manager'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _loadSuggestions,
                  child: _suggestions.isEmpty
                      ? const Center(
                          child: Text('Keine Textbausteine vorhanden.'))
                      : ListView.builder(
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            return _buildSuggestionTile(
                                _suggestions[index], _suggestions, index);
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(), // Add a new root-level suggestion.
        tooltip: 'Neuen Textbaustein hinzufügen',
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

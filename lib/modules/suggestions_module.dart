// suggestions_module.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A model that represents a node in the predefined texts tree.
class PredefinedTextNode {
  final String id;
  final String title;
  final String? text; // Optional text for leaf nodes
  final List<PredefinedTextNode> children;

  PredefinedTextNode({
    required this.id,
    required this.title,
    this.text,
    this.children = const [],
  });

  factory PredefinedTextNode.fromJson(Map<String, dynamic> json) {
    return PredefinedTextNode(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      text: json['text'],
      children: json['children'] != null
          ? (json['children'] as List)
              .map((child) => PredefinedTextNode.fromJson(child))
              .toList()
          : [],
    );
  }
}

/// Change this URL to your actual backend endpoint.
/// Make sure your backend sorts root nodes by sort_order
/// and children by sort_order as well.
const String suggestionsApiUrl =
    'http://wim-solution.sip.local:3006/suggestions';

/// Fetches the predefined texts tree from your backend.
Future<List<PredefinedTextNode>> fetchPredefinedTexts() async {
  final response = await http.get(Uri.parse(suggestionsApiUrl));
  if (response.statusCode == 200) {
    final List<dynamic> jsonData = json.decode(response.body);
    // Each node is already sorted by `sort_order` from the backend.
    return jsonData.map((node) => PredefinedTextNode.fromJson(node)).toList();
  } else {
    throw Exception('Failed to load predefined texts: '
        '${response.statusCode} - ${response.reasonPhrase}');
  }
}

/// A modal widget that allows the user to either enter custom text
/// or navigate a sorted tree of suggestions. Tapping a leaf will
/// build a chain from the root (e.g., "Extrusion\n//Heizbänder\n//Heizband defekt\nBuchse abgerissen")
/// and prepend it to the comment text.
class PredefinedTextsModal extends StatefulWidget {
  /// An optional initial text for the comment.
  final String initialText;

  const PredefinedTextsModal({super.key, this.initialText = ''});

  @override
  // ignore: library_private_types_in_public_api
  _PredefinedTextsModalState createState() => _PredefinedTextsModalState();
}

class _PredefinedTextsModalState extends State<PredefinedTextsModal> {
  late TextEditingController _textController;
  late Future<List<PredefinedTextNode>> _futureNodes;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _futureNodes = fetchPredefinedTexts();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Builds a hierarchical widget for a [PredefinedTextNode].
  /// If the node has children, it displays an [ExpansionTile]; otherwise, a [ListTile].
  Widget _buildNodeWidget(
      PredefinedTextNode node, List<PredefinedTextNode> allNodes) {
    if (node.children.isEmpty) {
      // Leaf node: tapping it will build the comment chain from root to here.
      return ListTile(
        title: Text(node.title),
        subtitle: node.text != null ? Text(node.text!) : null,
        onTap: () {
          // Find the path from root to this leaf.
          final path = _findPathToNode(allNodes, node.id);
          // Build the comment string from the path.
          final structuredComment = _buildStructuredComment(path);

          setState(() {
            // Prepend it to the top of the existing comment.
            final existingText = _textController.text;
            _textController.text = '$structuredComment\n$existingText';
          });
        },
      );
    } else {
      // Parent node: show an expansion tile with sorted children.
      return ExpansionTile(
        title: Text(node.title),
        children: node.children
            .map((child) => _buildNodeWidget(child, allNodes))
            .toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Add some padding around the content.
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Vordefinierte Texte',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // A text field that allows the user to preview or edit their comment.
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Kommentar',
                hintText:
                    'Wählen Sie einen Vorschlag aus oder geben Sie einen Kommentar ein',
              ),
            ),
            const SizedBox(height: 16),
            // Display the tree of predefined texts.
            Expanded(
              child: FutureBuilder<List<PredefinedTextNode>>(
                future: _futureNodes,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text('Fehler: ${snapshot.error}'),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('Keine vordefinierten Texte verfügbar.'),
                    );
                  } else {
                    final nodes = snapshot.data!;
                    return ListView.builder(
                      itemCount: nodes.length,
                      itemBuilder: (context, index) {
                        return _buildNodeWidget(nodes[index], nodes);
                      },
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Close the modal without returning a value.
                    Navigator.of(context).pop();
                  },
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Return the final comment.
                    Navigator.of(context).pop(_textController.text);
                  },
                  child: const Text('Auswählen'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// Builds a structured comment from the root path to the tapped leaf.
  /// Example:
  ///   If path = [Extrusion, Heizbänder, Heizband defekt] and
  ///   text = 'Buchse abgerissen'
  /// We produce:
  ///   Extrusion
  ///   //Heizbänder
  ///   //Heizband defekt
  ///   Buchse abgerissen
  /// Builds a structured comment from the root path to the tapped leaf.
  ///
  /// Example:
  ///   If path = [Extrusion, Heizbänder, Heizband defekt] and
  ///       leaf.text = 'Buchse abgerissen'
  ///   We produce:
  ///       Extrusion
  ///       // Heizbänder
  ///       // Heizband defekt.
  ///       Buchse abgerissen.
  String _buildStructuredComment(List<PredefinedTextNode> path) {
    if (path.isEmpty) return '';

    final buffer = StringBuffer();

    // Print the root node's title (without any prefix).
    buffer.writeln(path.first.title);

    // Print all nodes except the leaf node.
    for (int i = 1; i < path.length - 1; i++) {
      buffer.writeln('// ${path[i].title}');
    }

    // Process the leaf node.
    final leaf = path.last;
    // Always add a dot after the leaf's title.
    final leafTitleWithDot = '${leaf.title.trim()}.';
    buffer.writeln('// $leafTitleWithDot');

    // If the leaf node has text, print it on its own line,
    // appending a period if not already present.
    if (leaf.text != null && leaf.text!.trim().isNotEmpty) {
      final leafText = leaf.text!.trim();
      buffer.writeln(leafText.endsWith('.') ? leafText : '$leafText.');
    }

    return buffer.toString();
  }

  /// Finds the path from any top-level node to the specified nodeId.
  /// If not found, returns an empty list.
  /// The returned list is [root, child, ..., leaf].
  List<PredefinedTextNode> _findPathToNode(
      List<PredefinedTextNode> roots, String nodeId) {
    for (final root in roots) {
      final path = _searchPath(root, nodeId);
      if (path.isNotEmpty) return path;
    }
    return [];
  }

  /// Recursively searches for nodeId starting at current node.
  /// Returns the path if found, or empty list if not found.
  List<PredefinedTextNode> _searchPath(
      PredefinedTextNode current, String nodeId) {
    if (current.id == nodeId) {
      return [current];
    }
    for (final child in current.children) {
      final path = _searchPath(child, nodeId);
      if (path.isNotEmpty) {
        return [current, ...path];
      }
    }
    return [];
  }
}

/// A helper function to show the predefined texts modal.
/// Returns the comment (a [String]) that the user selected or typed,
/// or null if the user cancelled.
Future<String?> showPredefinedTextsModal(BuildContext context,
    {String initialText = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: PredefinedTextsModal(initialText: initialText),
    ),
  );
}

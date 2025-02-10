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

/// A simple model to hold both versions of a structured comment.
class StructuredComment {
  final String plain;
  final String html;
  StructuredComment({required this.plain, required this.html});
}

/// Change this URL to your actual backend endpoint.
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
/// build a chain from the root (e.g., "Extrusion\nHeizbänder\nHeizband defekt\nBuchse abgerissen")
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
  // Holds the HTML-formatted version of the suggestion.
  String? _latestHtmlComment;
  // Holds the plain text version.
  String? _latestPlainComment;

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
          // Build the plain text comment (for display in the text field).
          final plainComment = _buildPlainStructuredComment(path);
          // Build the HTML formatted comment (to send to the API).
          final htmlComment = _buildHtmlStructuredComment(path);

          setState(() {
            // Prepend the plain text comment to the existing comment.
            final existingText = _textController.text;
            _textController.text = plainComment.isNotEmpty
                ? '$plainComment\n$existingText'
                : existingText;
            // Store both versions.
            _latestPlainComment = plainComment.isNotEmpty
                ? '$plainComment\n${_latestPlainComment ?? ''}'
                : _latestPlainComment;
            _latestHtmlComment = htmlComment.isNotEmpty
                ? '$htmlComment\n${_latestHtmlComment ?? ''}'
                : _latestHtmlComment;
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
                    // Return a StructuredComment with both plain and HTML versions.
                    Navigator.of(context).pop(StructuredComment(
                      plain: _latestPlainComment ?? _textController.text,
                      html: _latestHtmlComment ?? _textController.text,
                    ));
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

  /// Builds a plain-text structured comment from the root path to the tapped leaf.
  /// No separators are added and no extra break appears at the end.
  String _buildPlainStructuredComment(List<PredefinedTextNode> path) {
    if (path.isEmpty) return '';

    final List<String> lines = [];

    // Add the root node's title.
    lines.add(path.first.title);

    // Add all intermediate nodes.
    for (int i = 1; i < path.length - 1; i++) {
      lines.add(path[i].title);
    }

    // Process the leaf node.
    final leaf = path.last;
    final leafTitle = leaf.title.trim();
    final leafTitleWithDot =
        leafTitle.endsWith('.') ? leafTitle : '$leafTitle.';
    lines.add(leafTitleWithDot);

    // If the leaf node has associated text, add it as a separate line.
    if (leaf.text != null && leaf.text!.trim().isNotEmpty) {
      final leafText = leaf.text!.trim();
      final leafTextWithDot = leafText.endsWith('.') ? leafText : '$leafText.';
      lines.add(leafTextWithDot);
    }

    return lines.join('\n');
  }

  /// Builds an HTML formatted structured comment from the root path to the tapped leaf.
  /// No "//" separator is used and no trailing <br/> is added.
  String _buildHtmlStructuredComment(List<PredefinedTextNode> path) {
    if (path.isEmpty) return '';

    final List<String> lines = [];

    // Add the root node's title wrapped in <b> tags.
    lines.add('<b>${path.first.title}</b>');

    // Add all intermediate nodes wrapped in <b> tags.
    for (int i = 1; i < path.length - 1; i++) {
      lines.add('<b>${path[i].title}</b>');
    }

    // Process the leaf node.
    final leaf = path.last;
    final leafTitle = leaf.title.trim();
    final leafTitleWithDot =
        leafTitle.endsWith('.') ? leafTitle : '$leafTitle.';
    lines.add('<b>$leafTitleWithDot</b>');

    // If the leaf node has associated text, add it as plain text.
    if (leaf.text != null && leaf.text!.trim().isNotEmpty) {
      final leafText = leaf.text!.trim();
      final leafTextWithDot = leafText.endsWith('.') ? leafText : '$leafText.';
      lines.add(leafTextWithDot);
    }

    return lines.join('<br/>');
  }

  /// Finds the path from any top-level node to the specified nodeId.
  List<PredefinedTextNode> _findPathToNode(
      List<PredefinedTextNode> roots, String nodeId) {
    for (final root in roots) {
      final path = _searchPath(root, nodeId);
      if (path.isNotEmpty) return path;
    }
    return [];
  }

  /// Recursively searches for nodeId starting at the current node.
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
/// Returns a [StructuredComment] (both plain and HTML) that the user selected or typed,
/// or null if the user cancelled.
Future<StructuredComment?> showPredefinedTextsModal(BuildContext context,
    {String initialText = ''}) {
  return showModalBottomSheet<StructuredComment>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: PredefinedTextsModal(initialText: initialText),
    ),
  );
}

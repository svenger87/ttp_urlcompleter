// suggestions_module.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A model that represents a node in the predefined texts tree.
class PredefinedTextNode {
  final String id;
  final String title;
  final String? text;

  // No more ‘childrenIds’ from the server—just store direct children or note that we don’t have them yet.
  // We can store a boolean or something that says “are we expanded?”

  PredefinedTextNode({
    required this.id,
    required this.title,
    this.text,
  });

  factory PredefinedTextNode.fromJson(Map<String, dynamic> json) {
    return PredefinedTextNode(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      text: json['text'],
    );
  }
}

/// Change this URL to your actual backend endpoint.
const String suggestionsApiUrl =
    'http://wim-solution.sip.local:3006/suggestions';

/// Cache for already fetched nodes to minimize redundant API calls.
Map<String, List<PredefinedTextNode>> _cache = {};

/// Fetches predefined texts tree but only loads the necessary parts.
Future<List<PredefinedTextNode>> fetchPredefinedTexts(
    {String? parentId}) async {
  // (Optionally check cache first)

  final url = parentId == null
      ? suggestionsApiUrl // no param => root
      : '$suggestionsApiUrl?parent_id=$parentId';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final List<dynamic> jsonData = json.decode(response.body);
    // Each item in jsonData is just a direct child with no nested children.
    final nodes =
        jsonData.map((node) => PredefinedTextNode.fromJson(node)).toList();
    // Cache it
    _cache[parentId ?? 'root'] = nodes;
    return nodes;
  } else {
    throw Exception('Failed to load suggestions');
  }
}

/// A modal widget that allows the user to either enter custom text
/// or navigate a sorted tree of suggestions.
class PredefinedTextsModal extends StatefulWidget {
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
    _futureNodes = fetchPredefinedTexts(); // Load only root nodes
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Builds a hierarchical widget for a [PredefinedTextNode].
  /// Loads child nodes only when expanded.
  Widget _buildNodeWidget(PredefinedTextNode node) {
    return FutureBuilder<List<PredefinedTextNode>>(
      // pass node.id to fetch the direct children
      future: fetchPredefinedTexts(parentId: node.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            title: Text(node.title),
            trailing: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          return ListTile(
            title: Text('${node.title} (Error: ${snapshot.error})'),
          );
        } else {
          final children = snapshot.data ?? [];
          if (children.isEmpty) {
            // If leaf node, just return a simple ListTile that inserts node.text into your text field
            return ListTile(
              title: Text(node.title),
              onTap: () {
                // E.g. add this text to the _textController
                if (node.text != null) {
                  setState(() {
                    _textController.text += node.text!;
                  });
                }
              },
            );
          } else {
            // Non-leaf node => show ExpansionTile
            return ExpansionTile(
              title: Text(node.title),
              children: children.map(_buildNodeWidget).toList(),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Vordefinierte Texte',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
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
            Expanded(
              child: FutureBuilder<List<PredefinedTextNode>>(
                future: _futureNodes,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Fehler: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('Keine vordefinierten Texte verfügbar.'));
                  } else {
                    final nodes = snapshot.data!;
                    return ListView.builder(
                      itemCount: nodes.length,
                      itemBuilder: (context, index) {
                        return _buildNodeWidget(nodes[index]);
                      },
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_textController.text),
                  child: const Text('Auswählen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A helper function to show the predefined texts modal.
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

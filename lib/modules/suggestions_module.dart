// suggestions_module.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A model that represents a node in the predefined texts tree.
class PredefinedTextNode {
  final String id;
  final String title;
  final String? text; // Optional text for leaf nodes
  final List<String>
      childrenIds; // Store only IDs of children, not full objects

  PredefinedTextNode({
    required this.id,
    required this.title,
    this.text,
    this.childrenIds = const [],
  });

  factory PredefinedTextNode.fromJson(Map<String, dynamic> json) {
    return PredefinedTextNode(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      text: json['text'],
      childrenIds: (json['children'] as List<dynamic>?)
              ?.map((child) => child['id'].toString())
              .toList() ??
          [],
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
  if (_cache.containsKey(parentId ?? "")) {
    return _cache[parentId]!;
  }

  final response = await http
      .get(Uri.parse('$suggestionsApiUrl?parent_id=${parentId ?? ""}'));
  if (response.statusCode == 200) {
    final List<dynamic> jsonData = json.decode(response.body);
    final nodes =
        jsonData.map((node) => PredefinedTextNode.fromJson(node)).toList();
    _cache[parentId ?? ""] = nodes; // Store in cache
    return nodes;
  } else {
    throw Exception(
        'Failed to load predefined texts: ${response.statusCode} - ${response.reasonPhrase}');
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
      future:
          fetchPredefinedTexts(parentId: node.id), // Load children dynamically
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
              title: Text(node.title), trailing: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return ListTile(title: Text("${node.title} (Fehler beim Laden)"));
        } else {
          final children = snapshot.data ?? [];
          return ExpansionTile(
            title: Text(node.title),
            children: children.map((child) => _buildNodeWidget(child)).toList(),
          );
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

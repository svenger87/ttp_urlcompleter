// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/loading_indicator.dart';
import '../screens/project_detail_screen.dart';

class ToolPlanningScreen extends StatefulWidget {
  const ToolPlanningScreen({super.key});

  @override
  _ToolPlanningScreenState createState() => _ToolPlanningScreenState();
}

class _ToolPlanningScreenState extends State<ToolPlanningScreen> {
  Map<String, List<Map<String, dynamic>>> categorizedProjects = {
    'Neuwerkzeuge': [],
    'Optimierungen': [],
    'Wartungen': [],
    'Einfahren': []
  };

  Map<String, String> categoryTranslationMap = {
    'New Tool': 'Neuwerkzeuge',
    'Tool Optimization': 'Optimierungen',
    'Maintenance': 'Wartungen',
    'Run In': 'Einfahren'
  };

  Map<String, String> reverseCategoryTranslationMap = {
    'Neuwerkzeuge': 'New Tool',
    'Optimierungen': 'Tool Optimization',
    'Wartungen': 'Maintenance',
    'Einfahren': 'Run In'
  };

  bool isLoading = true;
  Map<String, dynamic>? draggedItem;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    fetchProjects();
  }

  Future<void> fetchProjects() async {
    setState(() {
      isLoading = true;
    });

    try {
      final primaryData = await ApiService.fetchPrimaryProjects();
      final secondaryData = await ApiService.fetchSecondaryProjects();

      final List<Map<String, dynamic>> mergedData =
          primaryData.map<Map<String, dynamic>>((primaryProject) {
        final matchingSecondary = secondaryData.firstWhere(
          (secondaryProject) =>
              secondaryProject['id'] == primaryProject['project_id'],
          orElse: () => <String, dynamic>{}, // Return empty map if not found
        );

        // Translate category to German
        String category = primaryProject['category'] ?? 'New Tool';
        String germanCategory =
            categoryTranslationMap[category] ?? 'Neuwerkzeuge';

        return matchingSecondary.isNotEmpty
            ? {
                ...primaryProject,
                'name': matchingSecondary['name'],
                'number': matchingSecondary['number'],
                'priority': primaryProject['priority_order'],
                'description': matchingSecondary['description'],
                'internalstatus': matchingSecondary['internalstatus'],
                'category': germanCategory,
              }
            : primaryProject;
      }).toList();

      setState(() {
        categorizedProjects = {
          'Neuwerkzeuge': mergedData
              .where((project) => project['category'] == 'Neuwerkzeuge')
              .toList(),
          'Optimierungen': mergedData
              .where((project) => project['category'] == 'Optimierungen')
              .toList(),
          'Wartungen': mergedData
              .where((project) => project['category'] == 'Wartungen')
              .toList(),
          'Einfahren': mergedData
              .where((project) => project['category'] == 'Einfahren')
              .toList(),
        };
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching projects: $e');
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  // Enhanced auto-scroll with faster speed and acceleration based on proximity
  void _onDragUpdate(DragUpdateDetails details) {
    const edgePadding = 100.0;
    const maxScrollSpeed = 40.0;

    double scrollSpeed = 0;
    if (details.globalPosition.dx < edgePadding) {
      scrollSpeed =
          -maxScrollSpeed * (1 - (details.globalPosition.dx / edgePadding));
    } else if (details.globalPosition.dx >
        MediaQuery.of(context).size.width - edgePadding) {
      scrollSpeed = maxScrollSpeed *
          (1 -
              ((MediaQuery.of(context).size.width - details.globalPosition.dx) /
                  edgePadding));
    }

    if (scrollSpeed != 0) {
      _autoScrollTimer ??=
          Timer.periodic(const Duration(milliseconds: 10), (_) {
        _scrollController.jumpTo(
          _scrollController.offset + scrollSpeed,
        );
      });
    }
  }

  void _onDragEnd(DraggableDetails details) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Werkzeugplanung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchProjects,
          ),
        ],
      ),
      body: isLoading
          ? const LoadingIndicator()
          : SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categorizedProjects.entries
                    .map(
                        (entry) => _buildCategoryColumn(entry.key, entry.value))
                    .toList(),
              ),
            ),
    );
  }

  Widget _buildCategoryColumn(
      String category, List<Map<String, dynamic>> projects) {
    return Container(
      width: 300,
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header and Add Button
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.blueAccent,
            child: Center(
              child: Text(
                category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final tools = await ApiService.fetchSecondaryProjects();
              if (!mounted) return;

              final selectedTool = await _selectTool(context, tools);
              if (selectedTool != null) {
                selectedTool['category'] = category;
                _addToolToProjects(selectedTool);
              }
            },
          ),
          Expanded(
            child: projects.isEmpty
                ? DragTarget<Map<String, dynamic>>(
                    onWillAccept: (data) => true,
                    onAccept: (data) {
                      setState(() {
                        String oldCategory = data['category'];
                        categorizedProjects[oldCategory]?.remove(data);
                        data['category'] = category;
                        projects.add(data);
                      });
                      updatePriorities();
                    },
                    builder: (context, candidateData, rejectedData) {
                      bool isActive = candidateData.isNotEmpty;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        color: isActive
                            ? Colors.blue.withOpacity(0.5)
                            : Colors.transparent,
                        child: Center(
                          child: Text(
                            isActive ? 'Hier ablegen' : 'Keine Projekte',
                            style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : Colors.blueAccent),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: projects.length +
                        2, // +1 for top dropzone, +1 for end placeholder
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Top Dropzone
                        return DragTarget<Map<String, dynamic>>(
                          onWillAccept: (data) => true,
                          onAccept: (data) {
                            setState(() {
                              String oldCategory = data['category'];
                              categorizedProjects[oldCategory]?.remove(data);
                              data['category'] = category;
                              projects.insert(0, data);
                            });
                            updatePriorities();
                          },
                          builder: (context, candidateData, rejectedData) {
                            bool isActive = candidateData.isNotEmpty;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: isActive ? 60 : 20,
                              color: isActive
                                  ? Colors.blue.withOpacity(0.5)
                                  : Colors.transparent,
                              child: isActive
                                  ? const Center(
                                      child: Text('Hier ablegen',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    )
                                  : null,
                            );
                          },
                        );
                      } else if (index == projects.length + 1) {
                        // Placeholder at the end of the list
                        return DragTarget<Map<String, dynamic>>(
                          onWillAccept: (data) => true,
                          onAccept: (data) {
                            setState(() {
                              String oldCategory = data['category'];
                              categorizedProjects[oldCategory]?.remove(data);
                              data['category'] = category;
                              projects.add(data);
                            });
                            updatePriorities();
                          },
                          builder: (context, candidateData, rejectedData) {
                            bool isActive = candidateData.isNotEmpty;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: isActive ? 60 : 20,
                              color: isActive
                                  ? Colors.blue.withOpacity(0.5)
                                  : Colors.transparent,
                              child: isActive
                                  ? const Center(
                                      child: Text('Hier ablegen',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    )
                                  : null,
                            );
                          },
                        );
                      } else {
                        final project = projects[index - 1]; // Adjust index

                        return Column(
                          children: [
                            // Dropzone above the item
                            DragTarget<Map<String, dynamic>>(
                              onWillAccept: (data) => data != project,
                              onAccept: (data) {
                                setState(() {
                                  String oldCategory = data['category'];
                                  categorizedProjects[oldCategory]
                                      ?.remove(data);
                                  data['category'] = category;
                                  int newIndex = index - 1;
                                  projects.insert(newIndex, data);
                                });
                                updatePriorities();
                              },
                              builder: (context, candidateData, rejectedData) {
                                bool isActive = candidateData.isNotEmpty;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: isActive ? 60 : 20,
                                  color: isActive
                                      ? Colors.blue.withOpacity(0.5)
                                      : Colors.transparent,
                                  child: isActive
                                      ? const Center(
                                          child: Text('Hier ablegen',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        )
                                      : null,
                                );
                              },
                            ),
                            // The draggable item
                            LongPressDraggable<Map<String, dynamic>>(
                              data: project,
                              feedback: Material(
                                child: _buildProjectCard(project,
                                    isDragging: true),
                              ),
                              childWhenDragging: Container(),
                              onDragUpdate: _onDragUpdate,
                              onDragEnd: _onDragEnd,
                              child: _buildProjectCard(project),
                            ),
                          ],
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project,
      {bool isDragging = false}) {
    return SizedBox(
      width: 250, // Set a fixed width to avoid infinite width error
      child: Card(
        elevation: isDragging ? 6 : 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            title: Text(project['number'] ?? 'Unbekanntes Werkzeug'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${project['name'] ?? 'N/A'}'),
                Text('Priorität: ${project['priority'] ?? 'Nicht gesetzt'}'),
                Text('Werkzeugstatus: ${project['internalstatus'] ?? 'N/A'}'),
              ],
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProjectDetailScreen(
                      projectId: project['id'] ?? project['project_id']),
                ),
              );
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () =>
                  _deleteProject(project['id'] ?? project['project_id']),
            ),
          ),
        ),
      ),
    );
  }

  void _addToolToProjects(Map<String, dynamic> selectedTool) {
    setState(() {
      categorizedProjects[selectedTool['category']]!.add(selectedTool);
    });
    updatePriorities();
  }

  Future<void> _deleteProject(int projectId) async {
    try {
      await ApiService.deleteProjectById(projectId);
      setState(() {
        categorizedProjects.forEach((category, projects) {
          projects.removeWhere((project) =>
              project['id'] == projectId || project['project_id'] == projectId);
        });
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting project: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> _selectTool(
      BuildContext context, List<Map<String, dynamic>> tools) async {
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredTools = tools;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Werkzeug auswählen'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Suchen',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filteredTools = tools
                              .where((tool) =>
                                  (tool['name'] ?? '')
                                      .toString()
                                      .toLowerCase()
                                      .contains(value.toLowerCase()) ||
                                  (tool['number'] ?? '')
                                      .toString()
                                      .toLowerCase()
                                      .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredTools.length,
                        itemBuilder: (context, index) {
                          final tool = filteredTools[index];
                          return ListTile(
                            title:
                                Text(tool['number'] ?? 'Unbenanntes Werkzeug'),
                            subtitle: Text('${tool['name'] ?? 'N/A'}'),
                            onTap: () {
                              Navigator.of(context).pop(tool);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> updatePriorities() async {
    final priorities = categorizedProjects.entries.expand((entry) {
      final category = entry.key;
      final englishCategory =
          reverseCategoryTranslationMap[category] ?? 'New Tool';
      return entry.value.asMap().entries.map((e) => {
            'project_id': e.value['id'] ?? e.value['project_id'],
            'priority_order': e.key + 1,
            'category': englishCategory,
          });
    }).toList();

    try {
      await ApiService.updatePriorities(priorities);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating priorities: $e');
      }
    }
  }
}

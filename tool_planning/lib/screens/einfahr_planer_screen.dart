// lib/screens/einfahr_planer_screen.dart

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../modals/fahrversuche.dart';
import '../services/api_service.dart';

class EinfahrPlanerScreen extends StatefulWidget {
  const EinfahrPlanerScreen({super.key});

  @override
  State<EinfahrPlanerScreen> createState() => _EinfahrPlanerScreenState();
}

class _EinfahrPlanerScreenState extends State<EinfahrPlanerScreen> {
  // Days = rows
  final List<String> days = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag'
  ];

  // Tryouts = columns
  final List<String> tryouts = ['Try #1', 'Try #2', 'Try #3', 'Try #4'];

  // We store a map from day -> List<List<FahrversuchItem>>
  Map<String, List<List<FahrversuchItem>>> schedule = {};

  bool isLoading = true;
  final ScrollController _horizontalScrollCtrl = ScrollController();
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _initializeEmptySchedule();
    _fetchData();
  }

  void _initializeEmptySchedule() {
    for (var day in days) {
      schedule[day] = List.generate(
        tryouts.length,
        (_) => <FahrversuchItem>[],
      );
    }
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);

    try {
      final result = await ApiService.fetchEinfahrPlan();
      // result is a List<Map<String, dynamic>> from your own table
      _initializeEmptySchedule(); // Reset to all empty

      for (var row in result) {
        // Convert each DB row to FahrversuchItem
        final item = FahrversuchItem(
          id: row['id'],
          projectName: row['project_name'],
          toolNumber: row['tool_number'],
          dayName: row['day_name'],
          tryoutIndex: row['tryout_index'] ?? 0,
          status: row['status'] ?? 'in_progress',
        );

        if (!schedule.containsKey(item.dayName)) {
          // fallback if unknown day
          item.dayName = days.first;
        }
        final validTryIndex =
            (item.tryoutIndex >= 0 && item.tryoutIndex < tryouts.length)
                ? item.tryoutIndex
                : 0;

        schedule[item.dayName]![validTryIndex].add(item);
      }
    } catch (err) {
      if (kDebugMode) print('Error: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $err')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Move item from old cell to new cell
  Future<void> _moveItem(
    FahrversuchItem item,
    String newDay,
    int newTryIndex,
  ) async {
    final oldDay = item.dayName;
    final oldTryIndex = item.tryoutIndex;

    setState(() {
      schedule[oldDay]![oldTryIndex].remove(item);
      item.dayName = newDay;
      item.tryoutIndex = newTryIndex;
      schedule[newDay]![newTryIndex].add(item);
    });

    try {
      await ApiService.updateEinfahrPlan(
        id: item.id,
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
      );
    } catch (err) {
      // revert if server fails
      setState(() {
        schedule[newDay]![newTryIndex].remove(item);
        item.dayName = oldDay;
        item.tryoutIndex = oldTryIndex;
        schedule[oldDay]![oldTryIndex].add(item);
      });
      if (kDebugMode) print('Error updating: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Verschieben: $err')),
      );
    }
  }

  // Mark item done
  Future<void> _markDone(FahrversuchItem item) async {
    final oldStatus = item.status;
    setState(() => item.status = 'done');
    try {
      await ApiService.updateEinfahrPlan(
        id: item.id,
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: 'done',
      );
    } catch (err) {
      setState(() => item.status = oldStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Setzen auf done: $err')),
      );
    }
  }

  /// Instead of prompting for projectName or toolNumber,
  /// let's pick from existing secondary projects
  Future<void> _selectToolForCell(String day, int tryIndex) async {
    // 1. Fetch the list of available "secondary projects"
    setState(() => isLoading = true);
    List<Map<String, dynamic>> allTools = [];
    try {
      allTools = await ApiService.fetchSecondaryProjects();
    } catch (e) {
      if (kDebugMode) print('Error fetching secondary: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden der Tools: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }

    if (allTools.isEmpty) return;

    // 2. Show a dialog to pick one tool (like your _selectTool logic)
    final selectedTool = await _showToolSelectionDialog(context, allTools);
    if (selectedTool == null) return; // user canceled or no selection

    // 3. We have a selected tool from the list
    //    Let's call updateEinfahrPlan with id=null to create a new row
    final projectName = selectedTool['name'] ?? 'Unbenannt';
    final toolNumber = selectedTool['number'] ?? '';

    // Insert new row on server
    setState(() => isLoading = true);
    try {
      final response = await ApiService.updateEinfahrPlan(
        id: null, // means "insert"
        projectName: projectName,
        toolNumber: toolNumber,
        dayName: day,
        tryoutIndex: tryIndex,
        status: 'in_progress',
      );
      final newId = response['newId'];

      // Add item locally
      final newItem = FahrversuchItem(
        id: newId,
        projectName: projectName,
        toolNumber: toolNumber,
        dayName: day,
        tryoutIndex: tryIndex,
        status: 'in_progress',
      );
      schedule[day]![tryIndex].add(newItem);
    } catch (e) {
      if (kDebugMode) print('Error adding new tool row: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Hinzufügen: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Show a dialog with a search bar and a list of tools from `allTools`,
  /// letting the user pick one. Returns the chosen Map or null if canceled.
  Future<Map<String, dynamic>?> _showToolSelectionDialog(
    BuildContext context,
    List<Map<String, dynamic>> allTools,
  ) async {
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredTools = allTools;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
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
                      setStateDialog(() {
                        filteredTools = allTools
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
                        final toolTitle = tool['number'] ?? 'Unbenannt';
                        final toolSubtitle = tool['name'] ?? 'N/A';

                        return ListTile(
                          title: Text(toolTitle),
                          subtitle: Text(toolSubtitle),
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
        });
      },
    );
  }

  // Handle auto-scroll if user drags near edges horizontally
  void _onDragUpdate(DragUpdateDetails details) {
    const edgePadding = 50.0;
    const scrollSpeed = 8.0;

    if (details.globalPosition.dx < edgePadding) {
      _startScrolling(-scrollSpeed);
    } else if (details.globalPosition.dx >
        MediaQuery.of(context).size.width - edgePadding) {
      _startScrolling(scrollSpeed);
    } else {
      _stopScrolling();
    }
  }

  void _startScrolling(double speed) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _horizontalScrollCtrl.jumpTo(_horizontalScrollCtrl.offset + speed);
    });
  }

  void _stopScrolling() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _onDragEnd(DraggableDetails details) => _stopScrolling();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einfahr Planer: Days vs. Tryouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _horizontalScrollCtrl,
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    _buildTryoutsHeader(),
                    _buildDaysRows(),
                  ],
                ),
              ),
            ),
    );
  }

  // The top row (header) with an empty corner for the day label
  Widget _buildTryoutsHeader() {
    return Row(
      children: [
        // Empty corner cell
        Container(
          width: 150,
          height: 50,
          color: Colors.grey.shade300,
          alignment: Alignment.center,
          child: const Text('Tage\\Tryouts'),
        ),
        // Each tryout in the top
        for (int i = 0; i < tryouts.length; i++)
          Container(
            width: 200,
            height: 50,
            color: Colors.blueAccent,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(left: 2),
            child: Text(
              tryouts[i],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  // Build each day row
  Widget _buildDaysRows() {
    return Column(
      children: List.generate(days.length, (rowIndex) {
        final day = days[rowIndex];
        return Row(
          children: [
            // Left cell for day label
            Container(
              width: 150,
              height: 150,
              margin: const EdgeInsets.only(top: 2),
              color: Colors.blueGrey.shade100,
              alignment: Alignment.center,
              child: Text(day,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            // Each tryout cell
            for (int colIndex = 0; colIndex < tryouts.length; colIndex++)
              _buildGridCell(day, colIndex),
          ],
        );
      }),
    );
  }

  Widget _buildGridCell(String day, int colIndex) {
    final items = schedule[day]![colIndex];
    return Container(
      width: 200,
      height: 150,
      margin: const EdgeInsets.only(left: 2, top: 2),
      color: Colors.grey.shade100,
      child: Stack(
        children: [
          DragTarget<FahrversuchItem>(
            onWillAccept: (data) => true,
            onAccept: (data) => _moveItem(data, day, colIndex),
            builder: (context, candidateData, rejectedData) {
              final isActive = candidateData.isNotEmpty;
              return Container(
                color: isActive
                    ? Colors.blueAccent.withOpacity(0.2)
                    : Colors.transparent,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildDraggableItem(item);
                  },
                ),
              );
            },
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () => _selectToolForCell(day, colIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableItem(FahrversuchItem item) {
    return LongPressDraggable<FahrversuchItem>(
      data: item,
      onDragUpdate: _onDragUpdate,
      onDragEnd: _onDragEnd,
      childWhenDragging: const SizedBox.shrink(),
      feedback: Material(
        elevation: 4,
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(8),
          color: item.color,
          child: Text('${item.projectName} (${item.toolNumber})'),
        ),
      ),
      child: Card(
        color: item.color,
        margin: const EdgeInsets.all(4),
        child: ListTile(
          title: Text(item.projectName),
          subtitle: Text('Tool: ${item.toolNumber}, Status: ${item.status}'),
          trailing: IconButton(
            icon: const Icon(Icons.done, color: Colors.green),
            onPressed: () => _markDone(item),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }
}

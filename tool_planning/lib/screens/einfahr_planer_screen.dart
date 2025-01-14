// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:flutter/material.dart';
import '../modals/fahrversuche.dart'; // Contains color mapping for statuses
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
  final List<String> tryouts = [
    'Fahrversuch #1',
    'Fahrversuch #2',
    'Fahrversuch #3',
    'Fahrversuch #4'
  ];

  // Weeks to choose from (1..53).
  final List<int> weekNumbers = List.generate(53, (i) => i + 1);

  late int _selectedWeek;
  bool isLoading = true;

  // The schedule for the selected week: day -> list-of-lists
  Map<String, List<List<FahrversuchItem>>> schedule = {};

  // This map will hold "toolNumber" -> full secondary project record
  // Example: { 'WKZP14226W01': { 'id': 17514, 'number': 'WKZP14226W01', ... }, ... }
  Map<String, Map<String, dynamic>> _secondaryProjectsMap = {};

  final ScrollController _horizontalScrollCtrl = ScrollController();
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final currentWeek = _isoWeekNumber(now);
    final safeWeek = currentWeek.clamp(1, 53);
    _selectedWeek = safeWeek;

    if (kDebugMode) {
      print(
          '++ initState: Current ISO week is $currentWeek, clamped to $safeWeek');
    }

    _initializeEmptySchedule();

    // First fetch secondary data to build the lookup map, then fetch the plan
    _fetchAndBuildSecondaryMap().then((_) {
      _fetchDataForWeek(_selectedWeek);
    });
  }

  /// Returns the ISO-8601 week number (1..53).
  int _isoWeekNumber(DateTime date) {
    // Move date to the Thursday of the same week
    final thursday = date.add(Duration(days: 4 - (date.weekday % 7)));
    // Find the first Thursday of that year
    DateTime firstThursday = DateTime(thursday.year, 1, 1);
    while (firstThursday.weekday != DateTime.thursday) {
      firstThursday = firstThursday.add(const Duration(days: 1));
    }
    // The difference in days / 7 => week
    final diff = thursday.difference(firstThursday).inDays;
    return (diff ~/ 7) + 1;
  }

  void _initializeEmptySchedule() {
    schedule.clear();
    for (var day in days) {
      schedule[day] = List.generate(
        tryouts.length,
        (_) => <FahrversuchItem>[],
      );
    }
    if (kDebugMode) {
      print(
          '++ _initializeEmptySchedule: Cleared and created empty lists for each day.');
    }
  }

  /// Build our local map from "number" -> entire secondary record
  Future<void> _fetchAndBuildSecondaryMap() async {
    try {
      setState(() => isLoading = true);
      final allTools = await ApiService.fetchSecondaryProjects();

      _secondaryProjectsMap.clear();
      for (var tool in allTools) {
        final number = tool['number'];
        if (number != null) {
          _secondaryProjectsMap[number] = tool;
        }
      }

      if (kDebugMode) {
        print(
            '++ _fetchAndBuildSecondaryMap: loaded ${_secondaryProjectsMap.length} tools.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('!! _fetchAndBuildSecondaryMap: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden der Tools: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Convert "ikoffice:/docustore/3/Project/17514/..." to "docustore/download/Project/17514/..."
  String? _parseIkOfficeUri(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    // Example raw: "ikoffice:/docustore/3/Project/17514/Bild%20aus%20Zwischenablage.png"
    const prefix = 'ikoffice:/docustore/3/';
    if (!raw.startsWith(prefix)) {
      // If format isn't as expected, either return null or handle differently
      return null;
    }
    // everything after "ikoffice:/docustore/3/" -> "Project/17514/Bild%20aus%20Zwischenablage.png"
    final partial = raw.substring(prefix.length);

    // final path -> "docustore/download/Project/17514/Bild%20aus%20Zwischenablage.png"
    return 'docustore/download/$partial';
  }

  Future<void> _fetchDataForWeek(int weekNumber) async {
    setState(() => isLoading = true);
    if (kDebugMode) {
      print('++ _fetchDataForWeek: Fetching data for week=$weekNumber...');
    }

    try {
      final result = await ApiService.fetchEinfahrPlan(week: weekNumber);
      if (kDebugMode) {
        print('++ _fetchDataForWeek: Received ${result.length} items from API');
      }

      _initializeEmptySchedule();

      for (var row in result) {
        // Check if we have an imageUri from the plan itself
        String? rowImageUri = row['imageuri'] as String?;
        final toolNumber = row['tool_number'];

        // If there's no image or it's empty, do a reverse lookup in our map
        if ((rowImageUri == null || rowImageUri.isEmpty) &&
            toolNumber != null &&
            _secondaryProjectsMap.containsKey(toolNumber)) {
          final secondaryRec = _secondaryProjectsMap[toolNumber]!;
          if (secondaryRec['imageuri'] != null) {
            rowImageUri = secondaryRec['imageuri'];
          }
        }

        // Convert "ikoffice:/docustore/3/..." to "docustore/download/..."
        final finalImageUri = _parseIkOfficeUri(rowImageUri);

        final item = FahrversuchItem(
          id: row['id'],
          projectName: row['project_name'],
          toolNumber: toolNumber,
          dayName: row['day_name'] ?? 'Montag',
          tryoutIndex: row['tryout_index'] ?? 0,
          status: row['status'] ?? 'In Arbeit',
          weekNumber: row['week_number'] ?? weekNumber,
          imageUri: finalImageUri, // docustore/download/Project/...
        );

        if (!schedule.containsKey(item.dayName)) {
          if (kDebugMode) {
            print(
                '!! Found invalid dayName ${item.dayName}, defaulting to Montag.');
          }
          item.dayName = days.first;
        }

        final validTryIndex =
            (item.tryoutIndex >= 0 && item.tryoutIndex < tryouts.length)
                ? item.tryoutIndex
                : 0;

        schedule[item.dayName]![validTryIndex].add(item);
      }

      if (kDebugMode) {
        print(
            '++ _fetchDataForWeek: Placed all items in schedule for week=$weekNumber');
      }
    } catch (err) {
      if (kDebugMode) {
        print('!! _fetchDataForWeek: Error fetching: $err');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $err')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Move item within the same week (drag-and-drop)
  Future<void> _moveItem(
    FahrversuchItem item,
    String newDay,
    int newTryIndex,
  ) async {
    final oldDay = item.dayName;
    final oldTryIndex = item.tryoutIndex;

    if (kDebugMode) {
      print(
          '++ _moveItem: Moving ${item.projectName} from $oldDay/$oldTryIndex to $newDay/$newTryIndex');
    }

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
        weekNumber: item.weekNumber,
      );
      if (kDebugMode) {
        print('++ _moveItem: Update success on server for ${item.projectName}');
      }
    } catch (err) {
      if (kDebugMode) {
        print('!! _moveItem: Error updating: $err. Reverting local state.');
      }
      setState(() {
        schedule[newDay]![newTryIndex].remove(item);
        item.dayName = oldDay;
        item.tryoutIndex = oldTryIndex;
        schedule[oldDay]![oldTryIndex].add(item);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Verschieben: $err')),
      );
    }
  }

  // Show the edit dialog: status or shift item to next KW
  Future<void> _editItemDialog(FahrversuchItem item) async {
    if (kDebugMode) {
      print(
          '++ _editItemDialog: Editing item ${item.projectName} with status=${item.status}');
    }

    final oldStatus = item.status;
    final statuses = ["In Arbeit", "In Änderung", "Erledigt"];
    String selectedStatus = oldStatus;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${item.projectName} bearbeiten'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Radio statuses
                  for (var st in statuses)
                    RadioListTile<String>(
                      title: Text(st),
                      value: st,
                      groupValue: selectedStatus,
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => selectedStatus = val);
                        }
                      },
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Schiebe in nächste Kalenderwoche'),
                    onPressed: () => Navigator.pop(context, 'nextWeek'),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedStatus),
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      if (kDebugMode) {
        print('++ _editItemDialog: User canceled for ${item.projectName}');
      }
      return;
    } else if (result == 'nextWeek') {
      // move item to next KW
      if (kDebugMode) {
        print('++ _editItemDialog: Move ${item.projectName} to next week');
      }
      await _moveToNextWeek(item);
    } else {
      // user changed status
      final newStatus = result;
      if (kDebugMode) {
        print(
            '++ _editItemDialog: Setting status of ${item.projectName} from $oldStatus to $newStatus');
      }
      if (newStatus != oldStatus) {
        setState(() => item.status = newStatus);
        try {
          await ApiService.updateEinfahrPlan(
            id: item.id,
            projectName: item.projectName,
            toolNumber: item.toolNumber,
            dayName: item.dayName,
            tryoutIndex: item.tryoutIndex,
            status: newStatus,
            weekNumber: item.weekNumber,
          );
          if (kDebugMode) {
            print(
                '++ _editItemDialog: Status updated on server for ${item.projectName}');
          }
        } catch (err) {
          if (kDebugMode) {
            print(
                '!! _editItemDialog: Error setting newStatus for ${item.projectName}: $err');
          }
          setState(() => item.status = oldStatus);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Setzen von $newStatus: $err')),
          );
        }
      }
    }
  }

  Future<void> _moveToNextWeek(FahrversuchItem item) async {
    final oldWeek = item.weekNumber;
    setState(() => item.weekNumber = oldWeek + 1);

    if (kDebugMode) {
      print(
          '++ _moveToNextWeek: ${item.projectName} from $oldWeek -> ${item.weekNumber}');
    }

    try {
      await ApiService.updateEinfahrPlan(
        id: item.id,
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
        weekNumber: item.weekNumber,
      );
      if (kDebugMode) {
        print(
            '++ _moveToNextWeek: Server update OK. Removing from local schedule now');
      }
      setState(() {
        schedule[item.dayName]![item.tryoutIndex].remove(item);
      });
    } catch (err) {
      if (kDebugMode) {
        print(
            '!! _moveToNextWeek: Error shifting ${item.projectName} into next week: $err');
      }
      setState(() => item.weekNumber = oldWeek);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Verschieben in nächste KW: $err')),
      );
    }
  }

  // Insert new item from secondaryProjects
  Future<void> _selectToolForCell(String day, int tryIndex) async {
    setState(() => isLoading = true);
    if (kDebugMode) {
      print(
          '++ _selectToolForCell: Loading secondary projects for day=$day, tryIndex=$tryIndex');
    }

    List<Map<String, dynamic>> allTools = [];
    try {
      allTools = await ApiService.fetchSecondaryProjects();
      if (kDebugMode) {
        print(
            '++ _selectToolForCell: Received ${allTools.length} tools from secondary API');
      }
    } catch (e) {
      if (kDebugMode) {
        print('!! _selectToolForCell: Error fetching secondary: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden der Tools: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }

    if (allTools.isEmpty) return;

    final selectedTool = await _showToolSelectionDialog(context, allTools);
    if (selectedTool == null) {
      if (kDebugMode) {
        print('++ _selectToolForCell: User canceled picking a tool');
      }
      return;
    }

    final projectName = selectedTool['name'] ?? 'Unbenannt';
    final toolNumber = selectedTool['number'] ?? '';
    // Convert the "ikoffice:/docustore..." to "docustore/download/...":
    final finalImageUri =
        _parseIkOfficeUri(selectedTool['imageuri'] as String?);

    if (kDebugMode) {
      print(
          '++ _selectToolForCell: Creating new item => name:$projectName, number:$toolNumber, imageUri:$finalImageUri');
    }

    setState(() => isLoading = true);
    try {
      final response = await ApiService.updateEinfahrPlan(
        id: null,
        projectName: projectName,
        toolNumber: toolNumber,
        dayName: day,
        tryoutIndex: tryIndex,
        status: 'In Arbeit',
        weekNumber: _selectedWeek,
      );
      final newId = response['newId'];
      if (kDebugMode) {
        print(
            '++ _selectToolForCell: Server assigned ID $newId to new item $projectName');
      }

      final newItem = FahrversuchItem(
        id: newId,
        projectName: projectName,
        toolNumber: toolNumber,
        dayName: day,
        tryoutIndex: tryIndex,
        status: 'In Arbeit',
        weekNumber: _selectedWeek,
        imageUri: finalImageUri,
      );

      setState(() {
        schedule[day]![tryIndex].add(newItem);
      });
      if (kDebugMode) {
        print(
            '++ _selectToolForCell: Added $projectName locally => day=$day, col=$tryIndex');
      }
    } catch (err) {
      if (kDebugMode) {
        print('!! _selectToolForCell: Error adding new item: $err');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Hinzufügen: $err')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Download image from docustore
  Future<File?> _downloadItemImage(FahrversuchItem item) async {
    final uri = item.imageUri;
    if (uri == null || uri.isEmpty) {
      if (kDebugMode) {
        print(
            '!! _downloadItemImage: No imageUri for ${item.projectName}, skipping...');
      }
      return null;
    }

    if (kDebugMode) {
      print(
          '++ _downloadItemImage: Attempting to download for ${item.projectName}, path="$uri"');
    }

    try {
      final file = await ApiService.downloadIkofficeFile(uri);
      if (file != null) {
        if (kDebugMode) {
          print(
              '++ _downloadItemImage: Download succeeded for ${item.projectName}, local path: ${file.path}');
        }
        setState(() => item.localImagePath = file.path);
      } else {
        if (kDebugMode) {
          print(
              '!! _downloadItemImage: Download failed or returned null for ${item.projectName}.');
        }
      }
      return file;
    } catch (e) {
      if (kDebugMode) {
        print(
            '!! _downloadItemImage: Error downloading image for ${item.projectName}: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _showToolSelectionDialog(
    BuildContext context,
    List<Map<String, dynamic>> allTools,
  ) async {
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredTools = allTools;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                                      .toLowerCase()
                                      .contains(value.toLowerCase()) ||
                                  (tool['number'] ?? '')
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
                            onTap: () => Navigator.of(context).pop(tool),
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

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('++ build: isLoading=$isLoading, _selectedWeek=$_selectedWeek');
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einfahr Planer'),
        actions: [
          // Dropdown for selecting week
          DropdownButton<int>(
            value: _selectedWeek,
            dropdownColor: Colors.blueGrey[50],
            items: weekNumbers.map((w) {
              return DropdownMenuItem<int>(
                value: w,
                child: Text('KW $w'),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedWeek = value);
              _fetchDataForWeek(value);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchDataForWeek(_selectedWeek),
          ),
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

  Widget _buildTryoutsHeader() {
    return Row(
      children: [
        Container(
          width: 150,
          height: 50,
          color: Colors.blueAccent,
          alignment: Alignment.center,
          child: const Text(
            'Tage\\Tryouts',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        for (int i = 0; i < tryouts.length; i++)
          Container(
            width: 200,
            height: 50,
            margin: const EdgeInsets.only(left: 2),
            alignment: Alignment.center,
            color: Colors.blueAccent,
            child: Text(
              tryouts[i],
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildDaysRows() {
    return Column(
      children: days.map((day) {
        return Row(
          children: [
            Container(
              width: 150,
              height: 150,
              margin: const EdgeInsets.only(top: 2),
              color: Colors.blueAccent,
              alignment: Alignment.center,
              child: Text(
                day,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            for (int colIndex = 0; colIndex < tryouts.length; colIndex++)
              _buildGridCell(day, colIndex),
          ],
        );
      }).toList(),
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
        clipBehavior: Clip.none,
        children: [
          DragTarget<FahrversuchItem>(
            onWillAccept: (data) {
              if (kDebugMode) {
                print(
                    '++ onWillAccept: Hovering over $day col $colIndex with item: ${data?.projectName}');
              }
              return true;
            },
            onAccept: (data) => _moveItem(data, day, colIndex),
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isHovering
                      ? Colors.blueAccent.withOpacity(0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: isHovering ? Colors.blue : Colors.grey.shade300,
                    width: isHovering ? 3 : 1,
                  ),
                ),
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
          // Button to add a new item
          Positioned(
            right: -4,
            bottom: -4,
            child: IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
              tooltip: 'Neues Projekt hinzufügen',
              onPressed: () => _selectToolForCell(day, colIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableItem(FahrversuchItem item) {
    // If we haven't downloaded the image yet, do so:
    if (item.imageUri != null && item.localImagePath == null) {
      if (kDebugMode) {
        print(
            '++ _buildDraggableItem: Triggering _downloadItemImage for ${item.projectName}, uri=${item.imageUri}');
      }

      // Kick off the async download
      _downloadItemImage(item).then((file) {
        if (!mounted) return; // Ensure widget still in tree
        if (file != null) {
          setState(() {
            item.localImagePath = file.path;
          });
          if (kDebugMode) {
            print('++ _buildDraggableItem: Download success => ${file.path}');
          }
        } else {
          if (kDebugMode) {
            print('!! _buildDraggableItem: Download returned null');
          }
        }
      }).catchError((error) {
        if (kDebugMode) {
          print('!! _buildDraggableItem: Error downloading: $error');
        }
      });
    }

    return LongPressDraggable<FahrversuchItem>(
      data: item,
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
        margin: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
          height: 120,
          child: ListTile(
            leading: (item.localImagePath != null)
                ? Image.file(
                    File(item.localImagePath!),
                    width: 50,
                    fit: BoxFit.cover,
                  )
                : null,
            title: Text(
              item.projectName,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Tool: ${item.toolNumber}\nStatus: ${item.status}',
              style: const TextStyle(color: Colors.white),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Status/Mehr',
              onPressed: () => _editItemDialog(item),
            ),
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

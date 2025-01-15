// lib/screens/einfahr_planer_screen.dart

// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:flutter/material.dart';
import '../modals/fahrversuche.dart'; // Contains FahrversuchItem class
import '../services/api_service.dart';

class EinfahrPlanerScreen extends StatefulWidget {
  const EinfahrPlanerScreen({super.key});

  @override
  State<EinfahrPlanerScreen> createState() => _EinfahrPlanerScreenState();
}

class _EinfahrPlanerScreenState extends State<EinfahrPlanerScreen> {
  // === Existing State Variables ===
  final List<String> days = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag'
  ];

  final List<String> tryouts = [
    'Fahrversuch #1',
    'Fahrversuch #2',
    'Fahrversuch #3',
    'Fahrversuch #4',
  ];

  final List<int> weekNumbers = List.generate(53, (i) => i + 1);

  late int _selectedWeek;
  bool isLoading = true;

  final Map<int, String> _machineNumberMap = {};
  Map<String, List<List<FahrversuchItem>>> schedule = {};

  final Map<String, Map<String, dynamic>> _secondaryProjectsMap = {};

  final ScrollController _horizontalScrollCtrl = ScrollController();
  Timer? _autoScrollTimer;

  // === New State Variable for Edit Mode ===
  bool _editModeEnabled = false;

  // === PIN Configuration ===
  final String _correctPIN = '1234'; // Replace with your desired PIN

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
      print('++ tryouts.length: ${tryouts.length}');
    }

    _initializeEmptySchedule();

    // First fetch secondary data to build the lookup map, then fetch the plan
    _fetchAndBuildMaps().then((_) {
      _fetchDataForWeek(_selectedWeek);
    });
  }

  /// === New Method: Prompt for PIN ===
  Future<void> _promptForPIN() async {
    String enteredPIN = '';
    bool isError = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must enter PIN
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('PIN eingeben'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    onChanged: (value) {
                      setStateDialog(() {
                        enteredPIN = value;
                        isError = false; // Reset error state on input change
                      });
                    },
                  ),
                  if (isError)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Falscher PIN. Bitte versuchen Sie es erneut.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (enteredPIN == _correctPIN) {
                      Navigator.of(context).pop(true);
                    } else {
                      setStateDialog(() {
                        isError = true;
                      });
                    }
                  },
                  child: const Text('Entsperren'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        _editModeEnabled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Editiermodus aktiviert')),
      );
    }
  }

  /// === Existing Methods ===

  /// Fetch both secondary projects and machines, building their respective maps
  Future<void> _fetchAndBuildMaps() async {
    try {
      setState(() => isLoading = true);

      // Fetch secondary projects
      final allTools = await ApiService.fetchSecondaryProjects();
      if (kDebugMode) {
        print(
            '++ _fetchAndBuildMaps: Fetched ${allTools.length} secondary projects.');
      }

      _secondaryProjectsMap.clear();
      for (var tool in allTools) {
        final number = tool['number'];
        final extrudermainId = tool['extrudermain_id'];
        if (number != null) {
          _secondaryProjectsMap[number] = tool;
          // Add extrudermain_id for easier lookup later
          _secondaryProjectsMap[number]?['extrudermain_id'] = extrudermainId;
        }
      }

      // Fetch machines
      final machines = await ApiService.fetchMachines();
      if (kDebugMode) {
        print('++ _fetchAndBuildMaps: Fetched ${machines.length} machines.');
      }

      _machineNumberMap.clear();
      for (var machine in machines) {
        final id = machine['id'];
        final number = machine['salamandermachinepitch'];
        if (id != null && number != null) {
          _machineNumberMap[id] = number;
        }
      }

      if (kDebugMode) {
        print(
            '++ _fetchAndBuildMaps: _machineNumberMap populated with ${_machineNumberMap.length} entries.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('!! _fetchAndBuildMaps: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Fehler beim Laden der Tools oder Maschinen: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
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
      // Initialize grid tryouts (0 to tryouts.length - 1)
      schedule[day] = List.generate(
        tryouts.length,
        (_) => <FahrversuchItem>[],
      );

      // Add extra slots for independent drop boxes (tryoutIndex 4 and 5)
      schedule[day]!.add([]); // For tryout index 4
      schedule[day]!.add([]); // For tryout index 5

      if (kDebugMode) {
        print('++ schedule[$day].length = ${schedule[day]!.length}');
      }
    }
    if (kDebugMode) {
      print(
          '++ _initializeEmptySchedule: Cleared and created empty lists for each day.');
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
        if (kDebugMode) {
          print('++ _fetchDataForWeek: Row data: $row');
        }

        // Extract or lookup extrudermain_id
        int? extrudermainId = row['extrudermain_id'];
        final toolNumber = row['tool_number'];

        if (extrudermainId == null && toolNumber != null) {
          extrudermainId =
              _secondaryProjectsMap[toolNumber]?['extrudermain_id'];
          if (kDebugMode) {
            print(
                '++ _fetchDataForWeek: Fetched extrudermain_id=$extrudermainId for tool=$toolNumber');
          }
        }

        // Lookup machineNumber
        String? machineNumber;
        if (extrudermainId != null) {
          machineNumber = _machineNumberMap[extrudermainId];
        }

        // Process image URI
        String? rowImageUri = row['imageuri'] as String?;
        if ((rowImageUri == null || rowImageUri.isEmpty) &&
            toolNumber != null) {
          rowImageUri = _secondaryProjectsMap[toolNumber]?['imageuri'];
        }
        final finalImageUri = _parseIkOfficeUri(rowImageUri);

        // Build FahrversuchItem
        final item = FahrversuchItem(
          id: row['id'],
          projectName: row['project_name'],
          toolNumber: toolNumber,
          dayName: row['day_name'] ?? 'Montag',
          tryoutIndex: row['tryout_index'] ?? 0,
          status: row['status'] ?? 'In Arbeit',
          weekNumber: row['week_number'] ?? weekNumber,
          imageUri: finalImageUri,
          hasBeenMoved: row['has_been_moved'] == 1,
          extrudermainId: extrudermainId,
          machineNumber: machineNumber,
        );

        final validDay =
            days.contains(item.dayName) ? item.dayName : days.first;
        item.dayName = validDay;

        final validTryIndex = (item.tryoutIndex >= 0 &&
                item.tryoutIndex < schedule[validDay]!.length)
            ? item.tryoutIndex
            : 0;

        schedule[validDay]![validTryIndex].add(item);
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
      print('++ schedule[$oldDay].length = ${schedule[oldDay]?.length}');
    }

    if (newTryIndex >= tryouts.length || newTryIndex < 0) {
      if (kDebugMode) {
        print(
            '!! _moveItem: Invalid newTryIndex $newTryIndex for tryouts.length ${tryouts.length}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ungültiger Versuch-Index: $newTryIndex')),
      );
      return;
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
        hasBeenMoved: false,
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

  // Move item to a specific tryout index (for the new drop targets)
  Future<void> _moveItemToTryout(
      FahrversuchItem item, int targetTryoutIndex) async {
    final oldDay = item.dayName;
    final oldTryIndex = item.tryoutIndex;

    if (kDebugMode) {
      print(
          '++ _moveItemToTryout: Moving ${item.projectName} from $oldDay/$oldTryIndex to tryoutIndex $targetTryoutIndex');
      print('++ schedule[$oldDay].length = ${schedule[oldDay]?.length}');
    }

    // Check if the target index is valid in the schedule
    if (targetTryoutIndex >= schedule[oldDay]!.length ||
        targetTryoutIndex < 0) {
      if (kDebugMode) {
        print(
            '!! _moveItemToTryout: Invalid targetTryoutIndex $targetTryoutIndex for schedule[$oldDay].length ${schedule[oldDay]!.length}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Ungültiger Zielversuch-Index: $targetTryoutIndex')),
      );
      return;
    }

    setState(() {
      // Remove item from its old location
      schedule[oldDay]![oldTryIndex].remove(item);
      // Update item's index
      item.tryoutIndex = targetTryoutIndex;
      // Add item to the new location
      schedule[oldDay]![targetTryoutIndex].add(item);
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
        hasBeenMoved: false,
      );
      if (kDebugMode) {
        print(
            '++ _moveItemToTryout: Update success on server for ${item.projectName}');
      }
    } catch (err) {
      if (kDebugMode) {
        print(
            '!! _moveItemToTryout: Error updating: $err. Reverting local state.');
      }
      setState(() {
        // Revert changes if the server update fails
        schedule[oldDay]![targetTryoutIndex].remove(item);
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
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Löschen'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                    onPressed: () => Navigator.pop(context, 'delete'),
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
    }

    if (result == 'delete') {
      await _deleteItem(item);
      return;
    }

    if (result == 'nextWeek') {
      await _moveToNextWeek(item);
      return;
    }

    // Update the status if changed
    if (result != oldStatus) {
      setState(() => item.status = result);
      try {
        await ApiService.updateEinfahrPlan(
          id: item.id,
          projectName: item.projectName,
          toolNumber: item.toolNumber,
          dayName: item.dayName,
          tryoutIndex: item.tryoutIndex,
          status: result,
          weekNumber: item.weekNumber,
          hasBeenMoved: false,
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
          SnackBar(content: Text('Fehler beim Setzen von $result: $err')),
        );
      }
    }
  }

  Future<void> _deleteItem(FahrversuchItem item) async {
    try {
      // Call the backend to mark the item as deleted
      await ApiService.deleteEinfahrPlan(item.id);

      // Remove the item from the local schedule
      setState(() {
        schedule[item.dayName]![item.tryoutIndex].remove(item);
      });

      if (kDebugMode) {
        print(
            '++ _deleteItem: Successfully marked as deleted ${item.projectName}');
      }
    } catch (err) {
      if (kDebugMode) {
        print('!! _deleteItem: Error marking item as deleted: $err');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Löschen: $err')),
      );
    }
  }

  Future<void> _moveToNextWeek(FahrversuchItem item) async {
    final oldWeek = item.weekNumber;
    final newWeek = oldWeek + 1;

    try {
      // Step 1: Update the old item to mark it as moved
      await ApiService.updateEinfahrPlan(
        id: item.id,
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
        weekNumber: item.weekNumber,
        hasBeenMoved: true, // Set the flag to true
      );

      // Update the local item
      setState(() {
        item.hasBeenMoved = true;
      });

      // Step 2: Save a new copy in the database for the next week
      final response = await ApiService.updateEinfahrPlan(
        id: null, // Let the backend create a new ID
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
        weekNumber: newWeek,
        hasBeenMoved: false,
      );

      final newId = response['newId'];

      // Step 3: Create and add the new item locally
      final newItem = FahrversuchItem(
        id: newId,
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
        weekNumber: newWeek,
        imageUri: item.imageUri,
        hasBeenMoved: false, // New item hasn't been moved yet
      );

      setState(() {
        schedule[item.dayName]![item.tryoutIndex].add(newItem);
      });

      if (kDebugMode) {
        print('++ _moveToNextWeek: Successfully copied to week $newWeek');
      }
    } catch (err) {
      if (kDebugMode) {
        print('!! _moveToNextWeek: Error copying to next week: $err');
      }
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
        hasBeenMoved: false,
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
      print(
          '++ build: isLoading=$isLoading, _selectedWeek=$_selectedWeek, _editModeEnabled=$_editModeEnabled');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einfahr Planer'),
        actions: [
          // === New IconButton for Unlocking Edit Mode ===
          IconButton(
            icon: Icon(
              _editModeEnabled ? Icons.lock_open : Icons.lock,
              color: _editModeEnabled ? Colors.greenAccent : Colors.white,
            ),
            tooltip: _editModeEnabled
                ? 'Editiermodus aktiv'
                : 'Editiermodus entsperren',
            onPressed: () {
              if (!_editModeEnabled) {
                _promptForPIN();
              } else {
                // Optionally, allow locking again
                setState(() {
                  _editModeEnabled = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Editiermodus deaktiviert')),
                );
              }
            },
          ),
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
              // Provide a default value in case value is null
              final int selectedWeek = value ?? 1;
              setState(() => _selectedWeek = selectedWeek);
              _fetchDataForWeek(selectedWeek);
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === LEFT: Main Grid ===
                  SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      children: [
                        _buildTryoutsHeader(),
                        _buildDaysRows(),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14), // Some horizontal spacing

                  // === RIGHT: Side-by-side boxes ===
                  Column(
                    children: [
                      Row(
                        children: [
                          // Box 1: Werkzeuge in Änderung
                          Container(
                            width: 300, // Adjust width as needed
                            height: (days.length * 180).toDouble() +
                                50, // Grid height
                            padding: const EdgeInsets.all(0),
                            color: Colors.blueGrey[50],
                            child: Column(
                              children: [
                                // Header
                                Container(
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                  child: const Text(
                                    'Werkzeuge in Änderung',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // DragTarget Box
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      borderRadius: BorderRadius.circular(0),
                                      border: Border.all(color: Colors.red),
                                    ),
                                    child: DragTarget<FahrversuchItem>(
                                      builder: (context, candidateData,
                                          rejectedData) {
                                        final items = schedule.entries
                                            .expand((entry) => entry.value[4])
                                            .toList(); // Tryout index 4
                                        return ListView.builder(
                                          itemCount: items.length,
                                          itemBuilder: (context, index) {
                                            final item = items[index];
                                            return _buildDraggableItem(item);
                                          },
                                        );
                                      },
                                      onWillAccept: (data) => _editModeEnabled,
                                      onAccept: (item) {
                                        if (_editModeEnabled) {
                                          _moveItemToTryout(
                                              item, 4); // TryoutIndex 4
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 14), // Some horizontal spacing

                          // Box 2: Bereit für Einfahrversuch
                          Container(
                            width: 300, // Adjust width as needed
                            height: (days.length * 180).toDouble() +
                                50, // Grid height
                            padding: const EdgeInsets.all(0),
                            color: Colors.blueGrey[50],
                            child: Column(
                              children: [
                                // Header
                                Container(
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                  child: const Text(
                                    'Bereit für Einfahrversuch',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // DragTarget Box
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(0),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: DragTarget<FahrversuchItem>(
                                      builder: (context, candidateData,
                                          rejectedData) {
                                        final items = schedule.entries
                                            .expand((entry) => entry.value[5])
                                            .toList(); // Tryout index 5
                                        return ListView.builder(
                                          itemCount: items.length,
                                          itemBuilder: (context, index) {
                                            final item = items[index];
                                            return _buildDraggableItem(item);
                                          },
                                        );
                                      },
                                      onWillAccept: (data) => _editModeEnabled,
                                      onAccept: (item) {
                                        if (_editModeEnabled) {
                                          _moveItemToTryout(
                                              item, 5); // TryoutIndex 5
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
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
            width: 260,
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
              height: 190,
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
      width: 260,
      height: 190,
      margin: const EdgeInsets.only(left: 2, top: 2),
      color: Colors.grey.shade100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DragTarget<FahrversuchItem>(
            onWillAccept: (data) => _editModeEnabled,
            onAccept: (data) {
              if (_editModeEnabled) {
                _moveItem(data, day, colIndex);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty && _editModeEnabled;
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
          // === Conditionally Show Add Button ===
          if (_editModeEnabled)
            Positioned(
              right: 220,
              bottom: -4,
              child: IconButton(
                icon:
                    const Icon(Icons.add_circle, color: Colors.green, size: 28),
                tooltip: 'Neues Projekt hinzufügen',
                onPressed: () => _selectToolForCell(day, colIndex),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDraggableItem(FahrversuchItem item) {
    // Trigger download if needed (same logic as before):
    if (item.imageUri != null && item.localImagePath == null) {
      _downloadItemImage(item);
    }

    return LongPressDraggable<FahrversuchItem>(
      data: item,
      feedback: Material(
        elevation: 4,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(8),
          color: item.color,
          child: Text('${item.projectName} (${item.toolNumber})'),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: Card(
          color: item.color,
          margin: const EdgeInsets.only(bottom: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            height: 160,
            width: 220,
            child: _buildCardContent(item),
          ),
        ),
      ),
      child: Card(
        color: item.color,
        margin: const EdgeInsets.only(bottom: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SizedBox(
          height: 170,
          width: 220,
          child: _buildCardContent(item),
        ),
      ),
    );
  }

  Widget _buildCardContent(FahrversuchItem item) {
    if (kDebugMode) {
      print(
          '++ _buildCardContent: Building card for ${item.projectName} with extrudermain_id=${item.extrudermainId} and machineNumber=${item.machineNumber}');
    }

    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Image container with restricted height
            if (item.localImagePath != null)
              Container(
                height: 55, // Restrict image height
                margin: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(item.localImagePath!),
                    fit: BoxFit
                        .contain, // Ensure the image fits within the container
                  ),
                ),
              ),

            // Spacing
            const SizedBox(height: 6),

            // Project/Tool info
            Expanded(
              child: Column(
                children: [
                  Text(
                    item.projectName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2, // Prevent overflow
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Tool: ${item.toolNumber}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  // Display machine number if available
                  if (item.machineNumber != null)
                    Text(
                      'Maschine: ${item.machineNumber}',
                      style: const TextStyle(
                        color: Colors.yellow, // Temporary color for visibility
                        fontWeight: FontWeight.bold, // Temporary bold styling
                      ),
                      textAlign: TextAlign.center,
                    )
                  else
                    const Text(
                      'Maschine: Unbekannt', // Placeholder for missing machine numbers
                      style: TextStyle(
                        color: Colors.grey, // Grey color for placeholder
                      ),
                      textAlign: TextAlign.center,
                    ),
                  Text(
                    'Status: ${item.status}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // === Conditionally Show Edit Button ===
            if (_editModeEnabled)
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Status/Mehr',
                  onPressed: () => _editItemDialog(item),
                ),
              ),
          ],
        ),

        // Cross icon for moved items
        if (item.hasBeenMoved)
          Positioned(
            top: -24,
            right: 24,
            child: Icon(
              Icons.close,
              color: Colors.redAccent.withOpacity(0.8),
              size: 200,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }
}

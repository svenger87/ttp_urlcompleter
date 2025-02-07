// lib/screens/einfahr_planer_screen.dart

// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For persisting preferences
import 'package:window_manager/window_manager.dart'; // Import window_manager
import '../models/schedule_action.dart';
import '../models/fahrversuche.dart'; // Contains FahrversuchItem class
import '../services/api_service.dart';

class EinfahrPlanerScreen extends StatefulWidget {
  const EinfahrPlanerScreen(
      {super.key, required bool isStandalone, required bool isFullscreen});

  @override
  State<EinfahrPlanerScreen> createState() => _EinfahrPlanerScreenState();
}

class _EinfahrPlanerScreenState extends State<EinfahrPlanerScreen>
    with WindowListener {
  // === Days, Tryouts, and Week-Year handling ===
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
    'Einfahrunterstützung #1',
    'Einfahrunterstützung #2',
  ];
  final List<int> weekNumbers = List.generate(53, (i) => i + 1);

  late int _selectedWeek;
  late int _selectedYear;
  bool isLoading = true;

  // === Schedule data ===
  /// The schedule map: schedule[day][tryoutIndex] => List<FahrversuchItem>
  Map<String, List<List<FahrversuchItem>>> schedule = {};

  // === Maps for secondary projects and machines ===
  final Map<int, String> _machineNumberMap = {};
  final Map<String, Map<String, dynamic>> _secondaryProjectsMap = {};

  // === Scroll controllers & timers for auto-scroll ===
  final ScrollController _horizontalScrollCtrl = ScrollController();
  final ScrollController _verticalScrollCtrl = ScrollController();

  Timer? _autoScrollVerticalTimer;
  Timer? _autoScrollHorizontalTimer;
  final double _autoScrollThreshold = 75.0; // Distance from edge
  final double _autoScrollSpeed = 80.0; // Speed in pixels per tick

  // === Edit mode and PIN ===
  bool _editModeEnabled = false;
  final String _correctPIN = '3006'; // Replace with your desired PIN

  // === Action history for undo ===
  final List<ScheduleAction> _actionHistory = [];

  // === Fullscreen and Standalone Flags ===
  bool _isFullscreen = false;
  bool _isStandalone = false;

  // === NEW: Automatic Update Variables ===
  Timer? _autoUpdateTimer;
  int _autoUpdateInterval = 240; // default interval in seconds
  bool _autoUpdateEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _checkWindowState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    _autoUpdateTimer?.cancel();
    _autoScrollVerticalTimer?.cancel();
    _autoScrollHorizontalTimer?.cancel();
    _horizontalScrollCtrl.dispose();
    _verticalScrollCtrl.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  /// Checks if the application is in fullscreen and standalone mode
  Future<void> _checkWindowState() async {
    bool isFullscreen = await windowManager.isFullScreen();
    bool isStandalone =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (kDebugMode) {
      print(
          'Check Window State - Fullscreen: $isFullscreen, Standalone: $isStandalone');
    }
    setState(() {
      _isFullscreen = isFullscreen;
      _isStandalone = isStandalone;
    });
  }

  /// Listens to window events to update fullscreen status
  @override
  void onWindowEvent(String eventName) async {
    if (kDebugMode) {
      print('Window event: $eventName');
    }

    // Update fullscreen state
    if (eventName == 'enter-full-screen' || eventName == 'fullscreen') {
      setState(() {
        _isFullscreen = true;
      });
    } else if (eventName == 'leave-full-screen') {
      setState(() {
        _isFullscreen = false;
      });
    }

    // Ensure standalone state is always accurate
    bool isStandalone =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (_isStandalone != isStandalone) {
      setState(() {
        _isStandalone = isStandalone;
      });
    }
  }

  // --------------------------------------------
  //        PREFERENCES / INIT LOADING
  // --------------------------------------------
  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedWeek = prefs.getInt('selectedWeek') ??
            _isoWeekNumber(DateTime.now()).clamp(1, 53);
        _selectedYear = prefs.getInt('selectedYear') ?? DateTime.now().year;
        _autoUpdateInterval = prefs.getInt('autoUpdateInterval') ?? 60;
        _autoUpdateEnabled = prefs.getBool('autoUpdateEnabled') ?? false;
      });

      // Start auto update timer if enabled
      if (_autoUpdateEnabled) {
        _startAutoUpdateTimer();
      }

      _initializeEmptySchedule();
      await _fetchAndBuildMaps();
      await _fetchDataForWeek(_selectedWeek, _selectedYear);
    } catch (e) {
      if (kDebugMode) {
        print('!! _loadUserPreferences: Exception occurred: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden der Präferenzen: $e')),
      );
    }
  }

  Future<void> _saveUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selectedWeek', _selectedWeek);
      await prefs.setInt('selectedYear', _selectedYear);
      await prefs.setInt('autoUpdateInterval', _autoUpdateInterval);
      await prefs.setBool('autoUpdateEnabled', _autoUpdateEnabled);
    } catch (e) {
      if (kDebugMode) {
        print('!! _saveUserPreferences: Error saving preferences: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern der Präferenzen: $e')),
      );
    }
  }

  // --------------------------------------------
  //      AUTOMATIC UPDATE TIMER FUNCTIONS
  // --------------------------------------------

  /// Starts the periodic auto-update timer.
  void _startAutoUpdateTimer() {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer =
        Timer.periodic(Duration(seconds: _autoUpdateInterval), (timer) {
      if (!isLoading) {
        _fetchDataForWeek(_selectedWeek, _selectedYear);
      }
    });
  }

  /// Stops the periodic auto-update timer.
  void _stopAutoUpdateTimer() {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = null;
  }

  /// Prompts the user to configure the auto-update interval and enable/disable auto-update.
  Future<void> _promptAutoUpdateConfig() async {
    bool newAutoUpdateEnabled = _autoUpdateEnabled;
    TextEditingController intervalController =
        TextEditingController(text: _autoUpdateInterval.toString());

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Auto Update Konfiguration"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                          child: Text("Automatische Aktualisierung")),
                      Switch(
                        value: newAutoUpdateEnabled,
                        onChanged: (value) {
                          setStateDialog(() {
                            newAutoUpdateEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                  if (newAutoUpdateEnabled)
                    TextField(
                      controller: intervalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "Intervall (Sekunden)"),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Abbrechen"),
                ),
                ElevatedButton(
                  onPressed: () {
                    int? newInterval = int.tryParse(intervalController.text);
                    if (newInterval == null || newInterval <= 0) {
                      // You can optionally display an error message here.
                      return;
                    }
                    setState(() {
                      _autoUpdateEnabled = newAutoUpdateEnabled;
                      _autoUpdateInterval = newInterval;
                    });
                    _saveUserPreferences();
                    if (_autoUpdateEnabled) {
                      _startAutoUpdateTimer();
                    } else {
                      _stopAutoUpdateTimer();
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text("Speichern"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --------------------------------------------
  //        FETCH & PREP MAPS
  // --------------------------------------------
  Future<void> _fetchAndBuildMaps() async {
    try {
      setState(() => isLoading = true);

      // Fetch secondary projects
      final allTools = await ApiService.fetchSecondaryProjects();
      _secondaryProjectsMap.clear();
      for (var tool in allTools) {
        final number = tool['number'];
        int? extrudermainId;
        if (tool['extrudermain_id'] is int) {
          extrudermainId = tool['extrudermain_id'];
        } else if (tool['extrudermain_id'] is String) {
          extrudermainId = int.tryParse(tool['extrudermain_id']);
        }
        if (number != null && extrudermainId != null) {
          _secondaryProjectsMap[number] = Map<String, dynamic>.from(tool);
          _secondaryProjectsMap[number]!['extrudermain_id'] = extrudermainId;
        }
      }

      // Fetch machines
      final machines = await ApiService.fetchMachines();
      _machineNumberMap.clear();
      for (var machine in machines) {
        int? id;
        if (machine['id'] is int) {
          id = machine['id'];
        } else if (machine['id'] is String) {
          id = int.tryParse(machine['id']);
        }
        final number = machine['salamandermachinepitch'];
        if (id != null && number != null) {
          _machineNumberMap[id] = number;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('!! _fetchAndBuildMaps: Exception occurred: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Fehler beim Laden der Tools oder Maschinen: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --------------------------------------------
  //        FETCH SCHEDULE FOR WEEK/YEAR
  // --------------------------------------------
  Future<void> _fetchDataForWeek(int weekNumber, int year,
      {bool forceRedownload = false}) async {
    setState(() => isLoading = true);
    try {
      final result =
          await ApiService.fetchEinfahrPlan(week: weekNumber, year: year);
      _initializeEmptySchedule();

      for (var row in result) {
        int? extrudermainId = row['extrudermain_id'];
        final toolNumber = row['tool_number'];
        if (extrudermainId == null && toolNumber != null) {
          extrudermainId =
              _secondaryProjectsMap[toolNumber]?['extrudermain_id'];
        }

        // Machine
        String? machineNumber;
        if (extrudermainId != null) {
          machineNumber = _machineNumberMap[extrudermainId];
        }

        // Image
        String? rowImageUri = row['imageuri'] as String?;
        if ((rowImageUri == null || rowImageUri.isEmpty) &&
            toolNumber != null) {
          rowImageUri = _secondaryProjectsMap[toolNumber]?['imageuri'];
        }
        final finalImageUri = _parseIkOfficeUri(rowImageUri);

        final item = FahrversuchItem(
          id: row['id'],
          projectName: row['project_name'],
          toolNumber: toolNumber,
          dayName: row['day_name'] ?? 'Montag',
          tryoutIndex: row['tryout_index'] ?? 0,
          status: row['status'] ?? 'In Arbeit',
          weekNumber: row['week_number'] ?? weekNumber,
          year: (row['year'] is int)
              ? row['year']
              : int.tryParse('${row['year']}') ?? year,
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

        // Download image if present
        if (item.imageUri != null) {
          await _downloadItemImage(item, forceRedownload: forceRedownload);
        }
      }

      // Clear image cache after all downloads
      if (forceRedownload) {
        PaintingBinding.instance.imageCache.clear();
        if (kDebugMode) {
          print('Image cache cleared after force reload.');
        }
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

  void _initializeEmptySchedule() {
    schedule.clear();
    for (var day in days) {
      // +2 to accommodate the two special boxes if storing in same structure
      schedule[day] =
          List.generate(tryouts.length + 2, (_) => <FahrversuchItem>[]);
    }
  }

  // --------------------------------------------
  //        ITEM ACTIONS: MOVE / ADD / DELETE / STATUS CHANGE
  // --------------------------------------------
  Future<void> _moveItem(
      FahrversuchItem item, String newDay, int newTryIndex) async {
    final oldDay = item.dayName;
    final oldTryIndex = item.tryoutIndex;
    setState(() {
      schedule[oldDay]![oldTryIndex].remove(item);
      item.dayName = newDay;
      item.tryoutIndex = newTryIndex;
      schedule[newDay]![newTryIndex].add(item);
      _actionHistory.add(ScheduleAction.move(
        item: item,
        fromDay: oldDay,
        fromIndex: oldTryIndex,
        toDay: newDay,
        toIndex: newTryIndex,
      ));
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
        year: item.year,
        hasBeenMoved: false,
        extrudermainId: item.extrudermainId,
      );
    } catch (err) {
      // Revert on error
      setState(() {
        schedule[newDay]![newTryIndex].remove(item);
        item.dayName = oldDay;
        item.tryoutIndex = oldTryIndex;
        schedule[oldDay]![oldTryIndex].add(item);
        _actionHistory.removeLast();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Verschieben: $err')),
      );
    }
  }

  Future<void> _moveItemToTryout(
      FahrversuchItem item, int targetTryoutIndex) async {
    final day = item.dayName;
    final oldIndex = item.tryoutIndex;
    setState(() {
      schedule[day]![oldIndex].remove(item);
      item.tryoutIndex = targetTryoutIndex;
      schedule[day]![targetTryoutIndex].add(item);
      _actionHistory.add(ScheduleAction.move(
        item: item,
        fromDay: day,
        fromIndex: oldIndex,
        toDay: day,
        toIndex: targetTryoutIndex,
      ));
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
        year: item.year,
        hasBeenMoved: false,
        extrudermainId: item.extrudermainId,
      );
    } catch (err) {
      // Revert on error
      setState(() {
        schedule[day]![targetTryoutIndex].remove(item);
        item.tryoutIndex = oldIndex;
        schedule[day]![oldIndex].add(item);
        _actionHistory.removeLast();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Verschieben: $err')),
      );
    }
  }

  /// Insert new item from secondaryProjects directly into a day cell
  Future<void> _selectToolForCell(String day, int tryIndex) async {
    setState(() => isLoading = true);
    try {
      final allTools = await ApiService.fetchSecondaryProjects();
      if (allTools.isEmpty) return;

      final selectedTool = await _showToolSelectionDialog(context, allTools);
      if (selectedTool == null) return;

      final projectName = selectedTool['name'] ?? 'Unbenannt';
      final toolNumber = selectedTool['number'] ?? '';
      final finalImageUri =
          _parseIkOfficeUri(selectedTool['imageuri'] as String?);

      final response = await ApiService.updateEinfahrPlan(
        id: null,
        projectName: projectName,
        toolNumber: toolNumber,
        dayName: day,
        tryoutIndex: tryIndex,
        status: 'In Arbeit',
        weekNumber: _selectedWeek,
        year: _selectedYear,
        hasBeenMoved: false,
        extrudermainId: _secondaryProjectsMap[toolNumber]?['extrudermain_id'],
      );
      final newId = response['newId'];
      if (newId == null) throw Exception('No newId returned from server.');

      final newItem = FahrversuchItem(
        id: newId,
        projectName: projectName,
        toolNumber: toolNumber,
        dayName: day,
        tryoutIndex: tryIndex,
        status: 'In Arbeit',
        weekNumber: _selectedWeek,
        year: _selectedYear,
        imageUri: finalImageUri,
        hasBeenMoved: false,
        extrudermainId: _secondaryProjectsMap[toolNumber]?['extrudermain_id'],
        machineNumber:
            _secondaryProjectsMap[toolNumber]?['extrudermain_id'] != null
                ? _machineNumberMap[
                    _secondaryProjectsMap[toolNumber]!['extrudermain_id']]
                : null,
      );

      setState(() {
        schedule[day]![tryIndex].add(newItem);
        _actionHistory.add(ScheduleAction.add(
          item: newItem,
          toDay: day,
          toIndex: tryIndex,
        ));
      });

      if (newItem.imageUri != null) {
        await _downloadItemImage(newItem, forceRedownload: true);
      }
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Hinzufügen: $err')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Same logic as `_selectToolForCell` but used for the "boxes" on the right
  Future<void> _addToSeparateBox(int tryoutIndex) async {
    // We'll just store them in e.g. "Montag" at that index
    const day = 'Montag';
    await _selectToolForCell(day, tryoutIndex);
  }

  // --------------------------------------------
  //        EDIT (STATUS DIALOG, MOVE WEEK, ETC)
  // --------------------------------------------
  Future<void> _editItemDialog(FahrversuchItem item) async {
    final oldStatus = item.status;
    final statuses = ["In Arbeit", "In Änderung", "Erledigt"];
    String selectedStatus = oldStatus;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('${item.projectName} bearbeiten'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Fahrversuch nicht durchgeführt'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey),
                    onPressed: () => Navigator.pop(context, 'notConducted'),
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
      },
    );

    if (result == null) return;

    if (result == 'delete') {
      await _confirmDeleteItem(item);
      return;
    }
    if (result == 'nextWeek') {
      await _moveToNextWeek(item);
      return;
    }
    if (result == 'notConducted') {
      final oldHasBeenMoved = item.hasBeenMoved;
      final oldStatus = item.status; // Preserve old status
      setState(() {
        item.hasBeenMoved = true;
        item.status = 'Nicht durchgeführt';
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
          year: item.year,
          hasBeenMoved: true,
          extrudermainId: item.extrudermainId,
        );
        _actionHistory.add(ScheduleAction.statusChange(
          item: item,
          oldStatus: oldStatus,
          newStatus: item.status,
        ));
      } catch (err) {
        setState(() {
          item.hasBeenMoved = oldHasBeenMoved;
          item.status = oldStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Markieren: $err')),
        );
      }
      return;
    }

    // If user changed status
    if (result != oldStatus) {
      setState(() => item.status = result);
      if (kDebugMode) {
        print('Status changed for item ${item.id} from $oldStatus to $result');
      }
      try {
        await ApiService.updateEinfahrPlan(
          id: item.id,
          projectName: item.projectName,
          toolNumber: item.toolNumber,
          dayName: item.dayName,
          tryoutIndex: item.tryoutIndex,
          status: result,
          weekNumber: item.weekNumber,
          year: item.year,
          hasBeenMoved: false,
          extrudermainId: item.extrudermainId,
        );
        _actionHistory.add(ScheduleAction.statusChange(
          item: item,
          oldStatus: oldStatus,
          newStatus: result,
        ));
        if (kDebugMode) {
          print('API update successful for status change of item ${item.id}');
        }
      } catch (err) {
        setState(() => item.status = oldStatus);
        if (kDebugMode) {
          print('Error updating status for item ${item.id}: $err');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Setzen von $result: $err')),
        );
      }
    }
  }

  Future<void> _confirmDeleteItem(FahrversuchItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bestätigen'),
          content: Text('Möchten Sie ${item.projectName} wirklich löschen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await _deleteItem(item);
    }
  }

  Future<void> _deleteItem(FahrversuchItem item) async {
    try {
      await ApiService.deleteEinfahrPlan(item.id);
      setState(() {
        schedule[item.dayName]![item.tryoutIndex].remove(item);
        _actionHistory.add(ScheduleAction.delete(
          item: item,
          fromDay: item.dayName,
          fromIndex: item.tryoutIndex,
        ));
      });
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Löschen: $err')),
      );
    }
  }

  Future<void> _moveToNextWeek(FahrversuchItem item) async {
    final oldWeek = item.weekNumber;
    final oldYear = item.year;
    final newWeek = oldWeek + 1;
    final has53 = _has53Weeks(oldYear);
    final maxWeeks = has53 ? 53 : 52;
    final maybeNewYear = (newWeek > maxWeeks) ? oldYear + 1 : oldYear;
    final finalNewWeek = (newWeek > maxWeeks) ? 1 : newWeek;

    try {
      // 1) Mark old item as moved
      await ApiService.updateEinfahrPlan(
        id: item.id,
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
        weekNumber: item.weekNumber,
        year: item.year,
        hasBeenMoved: true,
        extrudermainId: item.extrudermainId,
      );
      setState(() => item.hasBeenMoved = true);
      _actionHistory.add(ScheduleAction.move(
        item: item,
        fromDay: item.dayName,
        fromIndex: item.tryoutIndex,
        toDay: item.dayName,
        toIndex: item.tryoutIndex,
      ));

      // 2) Insert a new copy for the next week
      final response = await ApiService.updateEinfahrPlan(
        id: null,
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
        weekNumber: finalNewWeek,
        year: maybeNewYear,
        hasBeenMoved: false,
        extrudermainId: item.extrudermainId,
      );
      final newId = response['newId'];
      if (newId == null) throw Exception('No newId returned from server.');

      final newItem = FahrversuchItem(
        id: newId,
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
        weekNumber: finalNewWeek,
        year: maybeNewYear,
        imageUri: item.imageUri,
        hasBeenMoved: false,
        extrudermainId: item.extrudermainId,
        machineNumber: item.machineNumber,
      );
      setState(() {
        schedule[item.dayName]![item.tryoutIndex].add(newItem);
      });
      if (newItem.imageUri != null) {
        await _downloadItemImage(newItem, forceRedownload: true);
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

  // --------------------------------------------
  //        UTILITY METHODS
  // --------------------------------------------
  bool _isLeapYear(int year) {
    if (year % 4 != 0) return false;
    if (year % 100 != 0) return true;
    if (year % 400 != 0) return false;
    return true;
  }

  bool _has53Weeks(int year) {
    final jan1 = DateTime(year, 1, 1);
    final thursday = jan1.weekday == DateTime.thursday;
    final wednesday = jan1.weekday == DateTime.wednesday;
    final leapYear = _isLeapYear(year);
    return thursday || (leapYear && wednesday);
  }

  int _isoWeekNumber(DateTime date) {
    // move to the thursday of this week
    final thursday = date.add(Duration(days: 4 - (date.weekday % 7)));
    // find first thursday of that year
    DateTime firstThursday = DateTime(thursday.year, 1, 1);
    while (firstThursday.weekday != DateTime.thursday) {
      firstThursday = firstThursday.add(const Duration(days: 1));
    }
    final diff = thursday.difference(firstThursday).inDays;
    return (diff ~/ 7) + 1;
  }

  /// Convert "ikoffice:/docustore/3/Project/1234/..." to "docustore/download/Project/1234/..."
  String? _parseIkOfficeUri(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    const prefix = 'ikoffice:/docustore/3/';
    if (!raw.startsWith(prefix)) {
      return null;
    }
    final partial = raw.substring(prefix.length);
    return 'docustore/download/$partial';
  }

  Future<File?> _downloadItemImage(FahrversuchItem item,
      {bool forceRedownload = false}) async {
    final uri = item.imageUri;
    if (uri == null || uri.isEmpty) return null;

    const int maxRetries = 3;
    int attempt = 0;
    File? downloadedFile;

    while (attempt < maxRetries && downloadedFile == null) {
      try {
        final imagePath = await item.getUniqueImagePath();
        final imageFile = File(imagePath);

        // If we do NOT want to force a new download, and we already have the file, just use it.
        if (!forceRedownload && await imageFile.exists()) {
          setState(() => item.localImagePath = imagePath);
          return imageFile;
        }

        // Optionally: If forcing a re-download, delete the old file:
        if (forceRedownload && await imageFile.exists()) {
          await imageFile.delete();
        }

        // Attempt the download from the API service
        downloadedFile = await ApiService.downloadIkofficeFile(uri, imagePath);
        if (downloadedFile != null) {
          setState(() => item.localImagePath = downloadedFile?.path);
          if (kDebugMode) {
            print(
                'Image downloaded for item ${item.id} at ${downloadedFile.path}');
          }
          return downloadedFile;
        } else {
          throw Exception('Downloaded file is null.');
        }
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          if (kDebugMode) {
            print(
                '!! _downloadItemImage: Failed to download image after $maxRetries attempts: $e');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Fehler beim Herunterladen des Bildes für ${item.projectName}: $e')),
          );
        } else {
          if (kDebugMode) {
            print('!! _downloadItemImage: Attempt $attempt failed: $e');
          }
          // Optionally, wait before retrying
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    return null;
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
                height: 400, // Adjust height as needed
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Suchen',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          filteredTools = allTools.where((tool) {
                            final name = (tool['name'] ?? '').toLowerCase();
                            final number = (tool['number'] ?? '').toLowerCase();
                            final query = value.toLowerCase();
                            return name.contains(query) ||
                                number.contains(query);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredTools.isNotEmpty
                          ? ListView.builder(
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
                            )
                          : const Center(
                              child: Text('Keine Werkzeuge gefunden'),
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

  // --------------------------------------------
  //        AUTO-SCROLL METHODS
  // --------------------------------------------
  void _handleDragUpdate(DragUpdateDetails details) {
    final position = details.globalPosition;
    final size = MediaQuery.of(context).size;
    final edgeMargin = _autoScrollThreshold;

    // Vertical
    if (position.dy < edgeMargin) {
      if (_autoScrollVerticalTimer == null ||
          !_autoScrollVerticalTimer!.isActive) {
        _autoScrollVerticalTimer =
            Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (_verticalScrollCtrl.hasClients) {
            final newOffset = _verticalScrollCtrl.offset - _autoScrollSpeed;
            _verticalScrollCtrl.animateTo(
              newOffset.clamp(
                _verticalScrollCtrl.position.minScrollExtent,
                _verticalScrollCtrl.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 100),
              curve: Curves.linear,
            );
          }
        });
      }
    } else if (position.dy > size.height - edgeMargin) {
      if (_autoScrollVerticalTimer == null ||
          !_autoScrollVerticalTimer!.isActive) {
        _autoScrollVerticalTimer =
            Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (_verticalScrollCtrl.hasClients) {
            final newOffset = _verticalScrollCtrl.offset + _autoScrollSpeed;
            _verticalScrollCtrl.animateTo(
              newOffset.clamp(
                _verticalScrollCtrl.position.minScrollExtent,
                _verticalScrollCtrl.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 100),
              curve: Curves.linear,
            );
          }
        });
      }
    } else {
      _autoScrollVerticalTimer?.cancel();
      _autoScrollVerticalTimer = null;
    }

    // Horizontal
    if (position.dx < edgeMargin) {
      if (_autoScrollHorizontalTimer == null ||
          !_autoScrollHorizontalTimer!.isActive) {
        _autoScrollHorizontalTimer =
            Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (_horizontalScrollCtrl.hasClients) {
            final newOffset = _horizontalScrollCtrl.offset - _autoScrollSpeed;
            _horizontalScrollCtrl.animateTo(
              newOffset.clamp(
                _horizontalScrollCtrl.position.minScrollExtent,
                _horizontalScrollCtrl.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 100),
              curve: Curves.linear,
            );
          }
        });
      }
    } else if (position.dx > size.width - edgeMargin) {
      if (_autoScrollHorizontalTimer == null ||
          !_autoScrollHorizontalTimer!.isActive) {
        _autoScrollHorizontalTimer =
            Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (_horizontalScrollCtrl.hasClients) {
            final newOffset = _horizontalScrollCtrl.offset + _autoScrollSpeed;
            _horizontalScrollCtrl.animateTo(
              newOffset.clamp(
                _horizontalScrollCtrl.position.minScrollExtent,
                _horizontalScrollCtrl.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 100),
              curve: Curves.linear,
            );
          }
        });
      }
    } else {
      _autoScrollHorizontalTimer?.cancel();
      _autoScrollHorizontalTimer = null;
    }
  }

  void _handleDraggableDragEnd(DraggableDetails details) {
    _autoScrollVerticalTimer?.cancel();
    _autoScrollHorizontalTimer?.cancel();
    _autoScrollVerticalTimer = null;
    _autoScrollHorizontalTimer = null;
  }

  void _handleGestureDragEnd(DragEndDetails details) {
    _autoScrollVerticalTimer?.cancel();
    _autoScrollHorizontalTimer?.cancel();
    _autoScrollVerticalTimer = null;
    _autoScrollHorizontalTimer = null;
  }

  // --------------------------------------------
  //        PIN / EDIT MODE
  // --------------------------------------------
  Future<void> _promptForPIN() async {
    String enteredPIN = '';
    bool isError = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    onChanged: (value) {
                      setStateDialog(() {
                        enteredPIN = value;
                        isError = false;
                      });
                    },
                    onSubmitted: (value) {
                      if (value == _correctPIN) {
                        Navigator.of(context).pop(true);
                      } else {
                        setStateDialog(() {
                          isError = true;
                        });
                      }
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
                      setStateDialog(() => isError = true);
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

  // --------------------------------------------
  //        UNDO LAST ACTION
  // --------------------------------------------
  Future<void> _undoLastAction() async {
    if (_actionHistory.isEmpty) return;
    final lastAction = _actionHistory.removeLast();

    switch (lastAction.type) {
      case ActionType.add:
        // Undo Add -> remove item + call delete
        setState(() {
          schedule[lastAction.toDay]![lastAction.toIndex]
              .remove(lastAction.item);
        });
        try {
          await ApiService.deleteEinfahrPlan(lastAction.item.id);
          if (kDebugMode) {
            print('Undo Add: Item ${lastAction.item.id} deleted.');
          }
        } catch (err) {
          if (kDebugMode) {
            print('!! _undoLastAction: error undoing add: $err');
          }
          // Can't do much more if that fails
        }
        break;

      case ActionType.delete:
        // Undo Delete -> re-insert item + undelete on server
        setState(() {
          schedule[lastAction.fromDay]![lastAction.fromIndex]
              .add(lastAction.item);
        });
        try {
          await ApiService.undeleteEinfahrPlan(lastAction.item.id);
          if (lastAction.item.imageUri != null) {
            await _downloadItemImage(lastAction.item, forceRedownload: true);
          }
          if (kDebugMode) {
            print('Undo Delete: Item ${lastAction.item.id} undeleted.');
          }
        } catch (err) {
          setState(() {
            schedule[lastAction.fromDay]![lastAction.fromIndex]
                .remove(lastAction.item);
          });
        }
        break;

      case ActionType.move:
        // Undo Move -> move the item back
        setState(() {
          schedule[lastAction.toDay]![lastAction.toIndex]
              .remove(lastAction.item);
          schedule[lastAction.fromDay]![lastAction.fromIndex]
              .add(lastAction.item);
          lastAction.item.dayName = lastAction.fromDay;
          lastAction.item.tryoutIndex = lastAction.fromIndex;
        });
        try {
          await ApiService.updateEinfahrPlan(
            id: lastAction.item.id,
            projectName: lastAction.item.projectName,
            toolNumber: lastAction.item.toolNumber,
            dayName: lastAction.fromDay,
            tryoutIndex: lastAction.fromIndex,
            status: lastAction.item.status,
            weekNumber: lastAction.item.weekNumber,
            year: lastAction.item.year,
            hasBeenMoved: false,
            extrudermainId: lastAction.item.extrudermainId,
          );
          if (kDebugMode) {
            print('Undo Move: Item ${lastAction.item.id} moved back.');
          }
        } catch (err) {
          setState(() {
            schedule[lastAction.fromDay]![lastAction.fromIndex]
                .remove(lastAction.item);
            schedule[lastAction.toDay]![lastAction.toIndex]
                .add(lastAction.item);
            lastAction.item.dayName = lastAction.toDay;
            lastAction.item.tryoutIndex = lastAction.toIndex;
          });
        }
        break;

      case ActionType.statusChange:
        // Undo Status Change -> revert to old status
        final item = lastAction.item;
        final oldStatus = lastAction.oldStatus;
        final newStatus = lastAction.newStatus;

        setState(() {
          item.status = oldStatus;
        });

        try {
          await ApiService.updateEinfahrPlan(
            id: item.id,
            projectName: item.projectName,
            toolNumber: item.toolNumber,
            dayName: item.dayName,
            tryoutIndex: item.tryoutIndex,
            status: oldStatus,
            weekNumber: item.weekNumber,
            year: item.year,
            hasBeenMoved: item.hasBeenMoved,
            extrudermainId: item.extrudermainId,
          );
          if (kDebugMode) {
            print(
                'Undo Status Change: Item ${item.id} status reverted to $oldStatus.');
          }
        } catch (err) {
          setState(() {
            item.status = newStatus;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Fehler beim Rückgängigmachen des Status: $err')),
          );
          if (kDebugMode) {
            print('!! _undoLastAction: error undoing status change: $err');
          }
        }
        break;
    }
  }

  // --------------------------------------------
  //        BUILD
  // --------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('Fullscreen: $_isFullscreen, Standalone: $_isStandalone');
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einfahr Planer'),
        actions: [
          // Undo button
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Rückgängig',
            onPressed: _actionHistory.isNotEmpty ? _undoLastAction : null,
            color: _actionHistory.isNotEmpty ? Colors.white : Colors.grey,
          ),
          // Lock/unlock
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
                setState(() => _editModeEnabled = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Editiermodus deaktiviert')),
                );
              }
            },
          ),
          // Year dropdown
          DropdownButton<int>(
            value: _selectedYear,
            dropdownColor: Colors.black,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            iconEnabledColor: Colors.white,
            items: List.generate(5, (index) => DateTime.now().year - 2 + index)
                .map((year) => DropdownMenuItem<int>(
                      value: year,
                      child: Text('Jahr $year',
                          style: const TextStyle(color: Colors.white)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedYear = value);
                _saveUserPreferences();
                _fetchDataForWeek(_selectedWeek, _selectedYear);
              }
            },
          ),
          // Week dropdown
          DropdownButton<int>(
            value: _selectedWeek,
            dropdownColor: Colors.black,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            iconEnabledColor: Colors.white,
            items: weekNumbers.map((w) {
              return DropdownMenuItem<int>(
                value: w,
                child:
                    Text('KW $w', style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedWeek = value);
                _saveUserPreferences();
                _fetchDataForWeek(_selectedWeek, _selectedYear);
              }
            },
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchDataForWeek(_selectedWeek, _selectedYear,
                forceRedownload: true),
          ),
          // NEW: Auto Update Config Button
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: 'Auto Update Konfiguration',
            onPressed: _promptAutoUpdateConfig,
          ),
          // === Power Button Integration ===
          if (_isFullscreen && _isStandalone)
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              tooltip: 'Beenden',
              onPressed: () async {
                bool shouldQuit = await _confirmExit();
                if (shouldQuit) {
                  if (Platform.isWindows ||
                      Platform.isMacOS ||
                      Platform.isLinux) {
                    await windowManager.close(); // Close gracefully
                  } else {
                    Navigator.of(context).pop(); // Exit for other platforms
                  }
                }
              },
              color: Colors.white,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onPanUpdate: _editModeEnabled ? _handleDragUpdate : null,
              onPanEnd: _editModeEnabled ? _handleGestureDragEnd : null,
              child: SingleChildScrollView(
                controller: _horizontalScrollCtrl,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === Left: The main grid ===
                    SingleChildScrollView(
                      controller: _verticalScrollCtrl,
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: [
                          _buildTryoutsHeader(),
                          // Each row: one day
                          for (var day in days)
                            Row(
                              children: [
                                // Day label
                                Container(
                                  width: 90,
                                  height: 170,
                                  margin: const EdgeInsets.only(top: 2),
                                  color: Colors.blueAccent,
                                  alignment: Alignment.center,
                                  child: Text(
                                    day,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Build each tryout cell for that day
                                for (int colIndex = 0;
                                    colIndex < tryouts.length;
                                    colIndex++)
                                  _buildTryoutCell(
                                    tryoutIndex: colIndex,
                                    width: 170,
                                    height: 170,
                                    bgColor: Colors.grey.shade100,
                                    dayName: day,
                                    title:
                                        null, // No special title for normal cells
                                    onAdd: _editModeEnabled
                                        ? () =>
                                            _selectToolForCell(day, colIndex)
                                        : null,
                                    itemsSupplier: () =>
                                        schedule[day]![colIndex],
                                    moveItemHandler: (item) =>
                                        _moveItem(item, day, colIndex),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // === Right: Box 1 "Werkzeuge in Änderung" ===
                    _buildTryoutCell(
                      tryoutIndex: 5, // Index for "Werkzeuge in Änderung"
                      width: 210,
                      height: (days.length * 172).toDouble() + 35,
                      bgColor: Colors.red[100],
                      dayName: null, // indicates "no specific day"
                      title: '     Werkzeuge in Änderung',
                      onAdd:
                          _editModeEnabled ? () => _addToSeparateBox(5) : null,
                      itemsSupplier: () => schedule.entries
                          .expand((entry) => entry.value[5])
                          .toList(),
                      moveItemHandler: (item) => _moveItemToTryout(item, 5),
                    ),

                    // === Right: Box 2 "Bereit für Einfahrversuch" ===
                    _buildTryoutCell(
                      tryoutIndex: 6, // Index for "Bereit für Einfahrversuch"
                      width: 210,
                      height: (days.length * 172).toDouble() + 35,
                      bgColor: Colors.green[100],
                      dayName: null,
                      title: '     Bereit für Einfahrversuch',
                      onAdd:
                          _editModeEnabled ? () => _addToSeparateBox(6) : null,
                      itemsSupplier: () => schedule.entries
                          .expand((entry) => entry.value[6])
                          .toList(),
                      moveItemHandler: (item) => _moveItemToTryout(item, 6),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --------------------------------------------
  //        HEADER ROW
  // --------------------------------------------
  Widget _buildTryoutsHeader() {
    return Row(
      children: [
        Container(
          width: 90, // Matches the day column width in the grid
          height: 35,
          decoration: const BoxDecoration(
            color: Colors.blueAccent, // Background color
            border: Border(
              bottom: BorderSide(
                color: Colors.blueAccent, // Line color
              ),
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            '',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        for (int i = 0; i < tryouts.length; i++)
          Container(
            width: 170, // Matches the tryout column width in the grid
            height: 35,
            margin: const EdgeInsets.only(left: 2),
            decoration: const BoxDecoration(
              color: Colors.blueAccent, // Background color
              border: Border(
                bottom: BorderSide(
                  color: Colors.black, // Line color
                ),
              ),
            ),
            alignment: Alignment.center,
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

  // --------------------------------------------
  //        REUSABLE CELL WIDGET
  // --------------------------------------------
  Widget _buildTryoutCell({
    required int tryoutIndex,
    required double width,
    required double height,
    required Function(FahrversuchItem) moveItemHandler,
    Color? bgColor,
    String? dayName,
    String? title,
    VoidCallback? onAdd,
    List<FahrversuchItem> Function()? itemsSupplier,
  }) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(left: 2),
      color: Colors.blueGrey[50],
      child: Stack(
        children: [
          Column(
            children: [
              // Optional title/header (for the separate boxes)
              if (title != null)
                Container(
                  height: 37,
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2.0),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor ?? Colors.grey[100],
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: DragTarget<FahrversuchItem>(
                    builder: (context, candidateData, rejectedData) {
                      final items = (itemsSupplier != null)
                          ? itemsSupplier()
                          : (dayName != null
                              ? schedule[dayName]![tryoutIndex]
                              : <FahrversuchItem>[]);

                      if (items.isEmpty) {
                        return const Center(
                          child: Text(
                            'Keine Einträge',
                            style: TextStyle(color: Colors.black),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _buildDraggableItem(item);
                        },
                      );
                    },
                    onWillAcceptWithDetails: (data) => _editModeEnabled,
                    onAcceptWithDetails: (details) {
                      if (_editModeEnabled) {
                        final item = details.data;
                        moveItemHandler(item);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          // "Add" button if edit mode
          if (_editModeEnabled && onAdd != null)
            Positioned(
              top: 4,
              left: 4,
              child: SizedBox(
                width: 24,
                height: 24,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.green,
                  tooltip: 'Neues Projekt hinzufügen',
                  onPressed: onAdd,
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------
  //        DRAGGABLE ITEM CARD
  // --------------------------------------------
  Widget _buildDraggableItem(FahrversuchItem item) {
    if (item.imageUri != null && item.localImagePath == null) {
      // Trigger async download if not yet done
      _downloadItemImage(item, forceRedownload: true);
    }

    return LongPressDraggable<FahrversuchItem>(
      data: item,
      onDragUpdate: (details) => _handleDragUpdate(details),
      onDragEnd: (details) => _handleDraggableDragEnd(details),
      feedback: Material(
        elevation: 4,
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(8),
          color: item.color,
          child: Text(
            '${item.projectName} (${item.toolNumber})',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: Card(
          color: item.color,
          margin: const EdgeInsets.only(bottom: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 180,
            height: 168,
            child: _buildCardContent(item),
          ),
        ),
      ),
      child: Card(
        color: item.color,
        margin: const EdgeInsets.only(bottom: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SizedBox(
          width: 180,
          height: 168,
          child: _buildCardContent(item),
        ),
      ),
    );
  }

  Widget _buildCardContent(FahrversuchItem item) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image
            if (item.localImagePath != null)
              Container(
                height: 40,
                margin: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(item.localImagePath!),
                    key:
                        ValueKey(File(item.localImagePath!).lastModifiedSync()),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, color: Colors.red),
                  ),
                ),
              )
            else if (item.imageUri != null)
              Container(
                height: 40,
                margin: const EdgeInsets.only(top: 4),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              )
            else
              Container(
                height: 40,
                margin: const EdgeInsets.only(top: 4),
                alignment: Alignment.center,
                child:
                    const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            const SizedBox(height: 2),
            // Project info
            Text(
              item.projectName,
              style: const TextStyle(color: Colors.black),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Werkzeug: ${item.toolNumber}',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
            if (item.machineNumber != null)
              Text(
                'Maschine: ${item.machineNumber}',
                style: const TextStyle(
                    color: Colors.yellowAccent, fontWeight: FontWeight.bold),
              )
            else
              const Text(
                'Maschine: Unbekannt',
                style: TextStyle(color: Colors.black),
              ),
            Text('Status: ${item.status}',
                style: const TextStyle(color: Colors.black)),
          ],
        ),

        // Edit button if in edit mode
        if (_editModeEnabled)
          Positioned(
            bottom: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => _editItemDialog(item),
            ),
          ),

        // Cross-out if item hasBeenMoved
        if (item.hasBeenMoved)
          Positioned(
            top: 0,
            right: 10,
            child: Icon(
              Icons.close,
              color: Colors.redAccent.withOpacity(0.8),
              size: 140,
            ),
          ),
      ],
    );
  }

  // --------------------------------------------
  //        CONFIRM EXIT DIALOG
  // --------------------------------------------
  // Ensure this method is defined only once
  Future<bool> _confirmExit() async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false, // Prevent dismissing by tapping outside
          builder: (context) => AlertDialog(
            title: const Text('Beenden bestätigen'),
            content: const Text('Möchten Sie die Anwendung wirklich beenden?'),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(false), // Return false
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true), // Return true
                child: const Text('Beenden'),
              ),
            ],
          ),
        )) ??
        false; // Default to false if dialog is dismissed unexpectedly
  }
}

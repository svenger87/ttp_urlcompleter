// lib/screens/einfahr_planer_screen.dart

// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For persisting preferences
import '../models/fahrversuche.dart'; // Contains FahrversuchItem class
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
    'Fahrversuch #5',
  ];

  final List<int> weekNumbers = List.generate(53, (i) => i + 1);

  late int _selectedWeek;
  bool isLoading = true;

  late int _selectedYear;

  final Map<int, String> _machineNumberMap = {};
  Map<String, List<List<FahrversuchItem>>> schedule = {};

  final Map<String, Map<String, dynamic>> _secondaryProjectsMap = {};

  // Existing horizontal ScrollController
  final ScrollController _horizontalScrollCtrl = ScrollController();

  // === New ScrollController for Vertical Scrolling ===
  final ScrollController _verticalScrollCtrl = ScrollController();

  // === Timers for Auto-Scrolling ===
  Timer? _autoScrollVerticalTimer;
  Timer? _autoScrollHorizontalTimer;

  // === Auto-Scroll Configuration ===
  final double _autoScrollThreshold =
      75.0; // Distance from edge to trigger scroll
  final double _autoScrollSpeed = 80.0; // Pixels per scroll interval

  // === New State Variable for Edit Mode ===
  bool _editModeEnabled = false;

  // === PIN Configuration ===
  final String _correctPIN = '3006'; // Replace with your desired PIN

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  /// === New Method: Load User Preferences ===
  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedWeek = prefs.getInt('selectedWeek') ??
            _isoWeekNumber(DateTime.now()).clamp(1, 53);
        _selectedYear = prefs.getInt('selectedYear') ?? DateTime.now().year;
      });

      if (kDebugMode) {
        print(
            '++ initState: Loaded preferences - Week: $_selectedWeek, Year: $_selectedYear');
      }

      _initializeEmptySchedule();

      // Ensure _fetchAndBuildMaps is awaited before proceeding
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

  /// === New Method: Add to Separate Box ===
  Future<void> _addToSeparateBox(int tryoutIndex) async {
    // Define a default day
    const String defaultDay =
        'Montag'; // You can change this to any day you prefer

    // Proceed to select and add the tool without prompting for a day
    await _selectToolForSeparateBox(defaultDay, tryoutIndex);
  }

  /// === New Method: Select Tool for Separate Box ===
  Future<void> _selectToolForSeparateBox(String day, int tryoutIndex) async {
    setState(() => isLoading = true);
    if (kDebugMode) {
      print(
          '++ _selectToolForSeparateBox: Loading secondary projects for day=$day, tryoutIndex=$tryoutIndex');
    }

    List<Map<String, dynamic>> allTools = [];
    try {
      allTools = await ApiService.fetchSecondaryProjects();
      if (kDebugMode) {
        print(
            '++ _selectToolForSeparateBox: Received ${allTools.length} tools from secondary API');
      }
    } catch (e) {
      if (kDebugMode) {
        print('!! _selectToolForSeparateBox: Error fetching secondary: $e');
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
        print('++ _selectToolForSeparateBox: User canceled picking a tool');
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
          '++ _selectToolForSeparateBox: Creating new item => name:$projectName, number:$toolNumber, imageUri:$finalImageUri');
    }

    setState(() => isLoading = true);
    try {
      final response = await ApiService.updateEinfahrPlan(
        id: null,
        projectName: projectName,
        toolNumber: toolNumber,
        dayName: day, // Set to default day
        tryoutIndex: tryoutIndex,
        status: 'In Arbeit',
        weekNumber: _selectedWeek,
        year: _selectedYear, // Include year
        hasBeenMoved: false,
        extrudermainId: _secondaryProjectsMap[toolNumber]?['extrudermain_id'],
      );

      final newId = response['newId'];
      if (newId == null) {
        throw Exception('No newId returned from server.');
      }
      if (kDebugMode) {
        print(
            '++ _selectToolForSeparateBox: Server assigned ID $newId to new item $projectName');
      }

      final newItem = FahrversuchItem(
        id: newId,
        projectName: projectName,
        toolNumber: toolNumber,
        dayName: day, // Set to default day
        tryoutIndex: tryoutIndex,
        status: 'In Arbeit',
        weekNumber: _selectedWeek,
        year: _selectedYear, // Include year
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
        schedule[day]![tryoutIndex].add(newItem);
      });
      if (kDebugMode) {
        print(
            '++ _selectToolForSeparateBox: Added $projectName locally => day=$day, tryoutIndex=$tryoutIndex');
      }
    } catch (err) {
      if (kDebugMode) {
        print('!! _selectToolForSeparateBox: Error adding new item: $err');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Hinzufügen: $err')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// === New Method: Save User Preferences ===
  Future<void> _saveUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selectedWeek', _selectedWeek);
      await prefs.setInt('selectedYear', _selectedYear);
      if (kDebugMode) {
        print(
            '++ _saveUserPreferences: Preferences saved - Week: $_selectedWeek, Year: $_selectedYear');
      }
    } catch (e) {
      if (kDebugMode) {
        print('!! _saveUserPreferences: Error saving preferences: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern der Präferenzen: $e')),
      );
    }
  }

  /// === New Method: Handle Drag Updates for Auto-Scroll ===
  void _handleDragUpdate(DragUpdateDetails details) {
    final position = details.globalPosition;
    final size = MediaQuery.of(context).size;

    // Define the edges threshold
    final double edgeMargin = _autoScrollThreshold;

    // === Vertical Auto-Scroll ===
    if (position.dy < edgeMargin) {
      // Near top, scroll up
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
      // Near bottom, scroll down
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
      // Not near vertical edges, cancel vertical scrolling
      _autoScrollVerticalTimer?.cancel();
      _autoScrollVerticalTimer = null;
    }

    // === Horizontal Auto-Scroll ===
    if (position.dx < edgeMargin) {
      // Near left, scroll left
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
      // Near right, scroll right
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
      // Not near horizontal edges, cancel horizontal scrolling
      _autoScrollHorizontalTimer?.cancel();
      _autoScrollHorizontalTimer = null;
    }
  }

  /// === New Method: Handle Drag End to Cancel Auto-Scroll ===
  void _handleDraggableDragEnd(DraggableDetails details) {
    // Cancel auto-scroll timers
    _autoScrollVerticalTimer?.cancel();
    _autoScrollHorizontalTimer?.cancel();
    _autoScrollVerticalTimer = null;
    _autoScrollHorizontalTimer = null;

    if (kDebugMode) {
      print('++ _handleDraggableDragEnd: Drag ended for item.');
    }
  }

  /// === New Method: Handle Gesture Drag End to Cancel Auto-Scroll ===
  void _handleGestureDragEnd(DragEndDetails details) {
    // Cancel auto-scroll timers
    _autoScrollVerticalTimer?.cancel();
    _autoScrollHorizontalTimer?.cancel();
    _autoScrollVerticalTimer = null;
    _autoScrollHorizontalTimer = null;

    if (kDebugMode) {
      print('++ _handleGestureDragEnd: Pan drag ended.');
    }
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
        final extrudermainIdRaw = tool['extrudermain_id'];
        int? extrudermainId;

        // Ensure extrudermain_id is an integer
        if (extrudermainIdRaw is int) {
          extrudermainId = extrudermainIdRaw;
        } else if (extrudermainIdRaw is String) {
          extrudermainId = int.tryParse(extrudermainIdRaw);
        } else {
          extrudermainId = null;
        }

        if (number != null && extrudermainId != null) {
          _secondaryProjectsMap[number] = Map<String, dynamic>.from(tool);
          _secondaryProjectsMap[number]!['extrudermain_id'] = extrudermainId;
        } else {
          if (kDebugMode) {
            print(
                '!! _fetchAndBuildMaps: Tool missing number or extrudermain_id: $tool');
          }
        }
      }

      // Fetch machines
      final machines = await ApiService.fetchMachines();
      if (kDebugMode) {
        print('++ _fetchAndBuildMaps: Fetched ${machines.length} machines.');
      }

      _machineNumberMap.clear();
      for (var machine in machines) {
        final idRaw = machine['id'];
        final number = machine['salamandermachinepitch'];

        int? id;
        if (idRaw is int) {
          id = idRaw;
        } else if (idRaw is String) {
          id = int.tryParse(idRaw);
        } else {
          id = null;
        }

        if (id != null && number != null) {
          if (_machineNumberMap.containsKey(id)) {
            if (kDebugMode) {
              print(
                  '!! _fetchAndBuildMaps: Duplicate machine id detected: $id. Overwriting previous entry.');
            }
          }
          _machineNumberMap[id] = number;
        } else {
          if (kDebugMode) {
            print(
                '!! _fetchAndBuildMaps: Machine missing id or number: $machine');
          }
        }
      }

      if (kDebugMode) {
        print(
            '++ _fetchAndBuildMaps: _machineNumberMap populated with ${_machineNumberMap.length} entries.');
        print(
            '++ _secondaryProjectsMap populated with ${_secondaryProjectsMap.length} entries.');
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

  /// Checks if a given year has 53 weeks based on ISO-8601 standards.
  bool _has53Weeks(int year) {
    // ISO week date system: a year has 53 weeks if:
    // - January 1st is a Thursday, or
    // - It's a leap year and January 1st is a Wednesday
    final jan1 = DateTime(year, 1, 1);
    final thursday = jan1.weekday == DateTime.thursday;
    final wednesday = jan1.weekday == DateTime.wednesday;
    final leapYear = _isLeapYear(year);

    return thursday || (leapYear && wednesday);
  }

  /// Determines if a given year is a leap year.
  bool _isLeapYear(int year) {
    if (year % 4 != 0) return false;
    if (year % 100 != 0) return true;
    if (year % 400 != 0) return false;
    return true;
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

      // Add extra slots for independent drop boxes (tryoutIndex 5 and 6)
      schedule[day]!.add([]); // For tryout index 5: Werkzeuge in Änderung
      schedule[day]!.add([]); // For tryout index 6: Bereit für Einfahrversuch

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
      if (kDebugMode) {
        print(
            '!! _parseIkOfficeUri: URI does not start with expected prefix: $raw');
      }
      return null;
    }
    // everything after "ikoffice:/docustore/3/" -> "Project/17514/Bild%20aus%20Zwischenablage.png"
    final partial = raw.substring(prefix.length);

    // final path -> "docustore/download/Project/17514/Bild%20aus%20Zwischenablage.png"
    return 'docustore/download/$partial';
  }

  Future<void> _fetchDataForWeek(int weekNumber, int year) async {
    setState(() => isLoading = true);
    if (kDebugMode) {
      print(
          '++ _fetchDataForWeek: Fetching data for week=$weekNumber, year=$year...');
    }

    try {
      final result =
          await ApiService.fetchEinfahrPlan(week: weekNumber, year: year);
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
          if (machineNumber == null && kDebugMode) {
            if (kDebugMode) {
              print(
                  '!! _fetchDataForWeek: extrudermain_id $extrudermainId not found in _machineNumberMap');
            }
          }
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
          toolNumber: row['tool_number'],
          dayName: row['day_name'] ?? 'Montag',
          tryoutIndex: row['tryout_index'] ?? 0,
          status: row['status'] ?? 'In Arbeit',
          weekNumber: row['week_number'] ?? weekNumber,
          year: row['year'] is int
              ? row['year']
              : int.tryParse(row['year'].toString()) ?? year, // Ensure integer
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

        if (extrudermainId != null && machineNumber == null) {
          if (kDebugMode) {
            print(
                '!! _fetchDataForWeek: extrudermain_id $extrudermainId has no corresponding machineNumber.');
          }
          // Optionally, handle this case by assigning a default machine number or flagging the item
        }

        schedule[validDay]![validTryIndex].add(item);
      }

      if (kDebugMode) {
        print(
            '++ _fetchDataForWeek: Placed all items in schedule for week=$weekNumber, year=$year');
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
    final oldWeek = item.weekNumber;
    final oldYear = item.year;

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
        weekNumber: oldWeek,
        year: oldYear, // Include year
        hasBeenMoved: false,
        extrudermainId: item.extrudermainId, // Pass extrudermainId
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
        year: item.year,
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

    if (result == 'notConducted') {
      // Mark as not conducted by setting hasBeenMoved to true and status accordingly
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
          hasBeenMoved: true, // Mark as moved to indicate it's been handled
        );
        if (kDebugMode) {
          print(
              '++ _editItemDialog: Marked as not conducted on server for ${item.projectName}');
        }
      } catch (err) {
        if (kDebugMode) {
          print(
              '!! _editItemDialog: Error marking as not conducted for ${item.projectName}: $err');
        }
        setState(() {
          // Revert changes if the server update fails
          item.hasBeenMoved = false;
          item.status = oldStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Markieren: $err')),
        );
      }
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
          year: item.year,
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
    final oldYear = item.year;
    final newWeek = oldWeek + 1;
    final has53Weeks = _has53Weeks(oldYear);
    final maxWeeks = has53Weeks ? 53 : 52;
    final newYear = (newWeek > maxWeeks) ? oldYear + 1 : oldYear;
    final finalNewWeek = (newWeek > maxWeeks) ? 1 : newWeek;

    try {
      // Step 1: Update the old item to mark it as moved on the server
      await ApiService.updateEinfahrPlan(
        id: item.id,
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
        weekNumber: oldWeek,
        year: oldYear, // Include year
        hasBeenMoved: true, // Set the flag to true
        extrudermainId: item.extrudermainId, // Pass extrudermainId
      );

      // Step 2: Update the local item's hasBeenMoved flag
      setState(() {
        item.hasBeenMoved = true;
      });

      // Step 3: Insert a new copy in the database for the next week
      final response = await ApiService.updateEinfahrPlan(
        id: null, // Correct: No id to trigger insert
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
        weekNumber: finalNewWeek, // Correct: New week
        year: newYear, // Correct: New year
        hasBeenMoved: false,
        extrudermainId: item.extrudermainId,
      );

      final newId = response['newId'];
      if (newId == null) {
        throw Exception('No newId returned from server.');
      }

      // Step 4: Create and add the new item locally
      final newItem = FahrversuchItem(
        id: newId,
        projectName: item.projectName,
        toolNumber: item.toolNumber,
        dayName: item.dayName,
        tryoutIndex: item.tryoutIndex,
        status: item.status,
        weekNumber: finalNewWeek,
        year: newYear, // New year
        imageUri: item.imageUri,
        hasBeenMoved: false,
        extrudermainId: item.extrudermainId,
        machineNumber: item.machineNumber,
      );

      setState(() {
        schedule[item.dayName]![item.tryoutIndex].add(newItem);
      });

      if (kDebugMode) {
        print(
            '++ _moveToNextWeek: Successfully copied to week $finalNewWeek, year $newYear');
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
        year: _selectedYear, // Include year
        hasBeenMoved: false,
        extrudermainId: _secondaryProjectsMap[toolNumber]?['extrudermain_id'],
      );

      final newId = response['newId'];
      if (newId == null) {
        throw Exception('No newId returned from server.');
      }
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
        year: _selectedYear, // Include year
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
                      child: filteredTools.isNotEmpty
                          ? ListView.builder(
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
          // Dropdown for Year Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<int>(
              value: _selectedYear,
              dropdownColor: Colors.blueGrey[50],
              items:
                  List.generate(5, (index) => DateTime.now().year - 2 + index)
                      .map((year) {
                return DropdownMenuItem<int>(
                  value: year,
                  child: Text('Jahr $year'),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedYear = value;
                });
                _saveUserPreferences(); // Save preference
                _fetchDataForWeek(_selectedWeek, _selectedYear);
                if (kDebugMode) {
                  print('Selected Year: $_selectedYear');
                }
              },
              hint: const Text('Wähle ein Jahr'),
            ),
          ),

          // Dropdown for Week Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<int>(
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
                setState(() {
                  _selectedWeek = value;
                });
                _saveUserPreferences(); // Save preference
                _fetchDataForWeek(_selectedWeek, _selectedYear); // Pass `year`
                if (kDebugMode) {
                  print('Selected Week: $_selectedWeek');
                }
              },
              hint: const Text('Wähle eine KW'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                _fetchDataForWeek(_selectedWeek, _selectedYear), // Pass `year`
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onPanUpdate: _editModeEnabled
                  ? _handleDragUpdate
                  : null, // Only handle drag updates in edit mode
              onPanEnd: _editModeEnabled
                  ? _handleGestureDragEnd // Use the correct handler
                  : null, // Only handle drag end in edit mode
              child: SingleChildScrollView(
                controller:
                    _horizontalScrollCtrl, // Horizontal ScrollController
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === LEFT: Main Grid ===
                    SingleChildScrollView(
                      controller:
                          _verticalScrollCtrl, // Assigned Vertical ScrollController
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: [
                          _buildTryoutsHeader(),
                          _buildDaysRows(),
                        ],
                      ),
                    ),

                    const SizedBox(width: 7), // Some horizontal spacing

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
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      // Header
                                      Container(
                                        height: 50,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent,
                                          borderRadius:
                                              BorderRadius.circular(0),
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
                                            borderRadius:
                                                BorderRadius.circular(0),
                                            border:
                                                Border.all(color: Colors.red),
                                          ),
                                          child: DragTarget<FahrversuchItem>(
                                            builder: (context, candidateData,
                                                rejectedData) {
                                              final items = schedule.entries
                                                  .expand(
                                                      (entry) => entry.value[5])
                                                  .toList(); // Tryout index 5
                                              return items.isNotEmpty
                                                  ? ListView.builder(
                                                      itemCount: items.length,
                                                      itemBuilder:
                                                          (context, index) {
                                                        final item =
                                                            items[index];
                                                        return _buildDraggableItem(
                                                            item);
                                                      },
                                                    )
                                                  : const Center(
                                                      child: Text(
                                                          'Keine Einträge'),
                                                    );
                                            },
                                            onWillAccept: (data) =>
                                                _editModeEnabled,
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
                                  // Add Button Positioned at Bottom Right
                                  if (_editModeEnabled)
                                    Positioned(
                                      top: 4,
                                      left: 8,
                                      child: FloatingActionButton(
                                        mini: true,
                                        backgroundColor: Colors.green,
                                        tooltip: 'Neues Projekt hinzufügen',
                                        onPressed: () => _addToSeparateBox(5),
                                        child: const Icon(Icons.add,
                                            color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 7), // Some horizontal spacing

                            // Box 2: Bereit für Einfahrversuch
                            Container(
                              width: 300, // Adjust width as needed
                              height: (days.length * 180).toDouble() +
                                  50, // Grid height
                              padding: const EdgeInsets.all(0),
                              color: Colors.blueGrey[50],
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      // Header
                                      Container(
                                        height: 50,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent,
                                          borderRadius:
                                              BorderRadius.circular(0),
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
                                            borderRadius:
                                                BorderRadius.circular(0),
                                            border:
                                                Border.all(color: Colors.green),
                                          ),
                                          child: DragTarget<FahrversuchItem>(
                                            builder: (context, candidateData,
                                                rejectedData) {
                                              final items = schedule.entries
                                                  .expand(
                                                      (entry) => entry.value[6])
                                                  .toList(); // Tryout index 6
                                              return items.isNotEmpty
                                                  ? ListView.builder(
                                                      itemCount: items.length,
                                                      itemBuilder:
                                                          (context, index) {
                                                        final item =
                                                            items[index];
                                                        return _buildDraggableItem(
                                                            item);
                                                      },
                                                    )
                                                  : const Center(
                                                      child: Text(
                                                          'Keine Einträge'),
                                                    );
                                            },
                                            onWillAccept: (data) =>
                                                _editModeEnabled,
                                            onAccept: (item) {
                                              if (_editModeEnabled) {
                                                _moveItemToTryout(
                                                    item, 6); // TryoutIndex 6
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Add Button Positioned at Bottom Right
                                  if (_editModeEnabled)
                                    Positioned(
                                      top: 4,
                                      left: 8,
                                      child: FloatingActionButton(
                                        mini: true,
                                        backgroundColor: Colors.green,
                                        tooltip: 'Neues Projekt hinzufügen',
                                        onPressed: () => _addToSeparateBox(6),
                                        child: const Icon(Icons.add,
                                            color: Colors.white),
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
            ),
    );
  }

  /// === Helper Methods ===

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
                child: items.isNotEmpty
                    ? ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _buildDraggableItem(item);
                        },
                      )
                    : const Center(child: Text('Keine Einträge')),
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
    // Trigger download if needed
    if (item.imageUri != null && item.localImagePath == null) {
      _downloadItemImage(item);
    }

    return LongPressDraggable<FahrversuchItem>(
      data: item,
      // === New Callbacks for Auto-Scroll ===
      onDragUpdate: (details) => _handleDragUpdate(details),
      onDragEnd: (details) =>
          _handleDraggableDragEnd(details), // Correct handler
      feedback: Material(
        elevation: 4,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(8),
          color: item.color, // Use item.color
          child: Text('${item.projectName} (${item.toolNumber})',
              style: const TextStyle(color: Colors.white)),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: Card(
          color: item.color, // Use item.color
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
        color: item.color, // Use item.color
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
      print('++ _buildCardContent: Building card for ${item.projectName}');
      print(
          '    Properties - imageUri: ${item.imageUri}, machineNumber: ${item.machineNumber}, hasBeenMoved: ${item.hasBeenMoved}');
    }

    return Stack(
      alignment: Alignment.center, // Center the main content
      children: [
        Column(
          mainAxisSize: MainAxisSize.min, // Wrap content vertically
          crossAxisAlignment:
              CrossAxisAlignment.center, // Center children horizontally
          mainAxisAlignment:
              MainAxisAlignment.center, // Center children vertically
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
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, color: Colors.red);
                    },
                  ),
                ),
              )
            else
              Container(
                height: 55,
                margin: const EdgeInsets.only(top: 8),
                alignment: Alignment.center,
                child:
                    const Icon(Icons.image_not_supported, color: Colors.grey),
              ),

            // Spacing
            const SizedBox(height: 6),

            // Project/Tool info
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.center, // Center text horizontally
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
                      color: Colors.yellow, // Highlight for visibility
                      fontWeight: FontWeight.bold,
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
          ],
        ),

        // === Conditionally Show Edit Button ===
        if (_editModeEnabled)
          Positioned(
            bottom: 4, // Position at the bottom right
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Status/Mehr',
              onPressed: () => _editItemDialog(item),
            ),
          ),

        // Cross icon for moved items
        if (item.hasBeenMoved)
          Positioned(
            top: -14, // Adjusted position to prevent overlap
            right: 24,
            child: Icon(
              Icons.close,
              color: Colors.redAccent.withOpacity(0.8),
              size: 200, // Reduced size for better aesthetics
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    // === Dispose Controllers and Timers ===
    _autoScrollVerticalTimer?.cancel();
    _autoScrollHorizontalTimer?.cancel();
    _horizontalScrollCtrl.dispose();
    _verticalScrollCtrl.dispose();
    super.dispose();
  }
}

// number_input_page.dart

// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:ttp_app/modules/torsteuerung_module.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import '../modules/webview_module.dart';
import 'package:ttp_app/constants.dart';
import 'package:ttp_app/widgets/drawer_widget.dart';
import '../modules/suggestions_module.dart';

// ----------------------------
// Model class for Machine
// ----------------------------
class Machine {
  final String number;
  final String salamandermachinepitch;
  final String? salamanderlineNumber;
  final String productionworkplaceNumber;

  Machine({
    required this.number,
    required this.salamandermachinepitch,
    this.salamanderlineNumber,
    required this.productionworkplaceNumber,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      number: json['number'] ?? '',
      salamandermachinepitch: json['salamandermachinepitch'] ?? '',
      salamanderlineNumber: json['salamanderline_number'],
      productionworkplaceNumber: json['productionworkplace_number'] ?? '',
    );
  }
}

// ----------------------------
// Parsing Functions
// ----------------------------
List<String> parseAreaCenters(String responseBody) {
  final data = json.decode(responseBody) as List<dynamic>;
  return data.map((e) => e['name'].toString()).toList();
}

List<String> parseLines(String responseBody) {
  final data = json.decode(responseBody) as List<dynamic>;
  return data.map((e) => e['number'].toString()).toList();
}

List<String> parseTools(String responseBody) {
  final data = json.decode(responseBody) as List<dynamic>;
  return data.map((e) => e['number'].toString()).toList();
}

List<Machine> parseMachines(String responseBody) {
  final data = json.decode(responseBody) as List<dynamic>;
  return data.map((json) => Machine.fromJson(json)).toList();
}

List<String> parseMaterials(String responseBody) {
  final data = json.decode(responseBody) as List<dynamic>;
  return data.map((m) => m['name'].toString()).toList();
}

List<String> parseEmployees(String responseBody) {
  final data = json.decode(responseBody) as List<dynamic>;
  return data
      .map((e) => '${e['employeenumber']} - ${e['firstname']} ${e['lastname']}')
      .toList();
}

// ----------------------------
// Updated API Fetch Functions (using compute)
// ----------------------------
Future<List<String>> _fetchAreaCenters() async {
  final response = await http.get(
    Uri.parse('http://wim-solution.sip.local:3006/salamanderareacenter'),
    headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
  );
  if (response.statusCode == 200) {
    return compute(parseAreaCenters, response.body);
  }
  throw Exception('Failed to fetch area centers');
}

Future<List<String>> _fetchLines() async {
  final response = await http.get(
    Uri.parse('http://wim-solution.sip.local:3006/salamanderline'),
    headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
  );
  if (response.statusCode == 200) {
    return compute(parseLines, response.body);
  }
  throw Exception('Failed to fetch lines');
}

Future<List<String>> _fetchTools() async {
  final response = await http.get(
    Uri.parse('http://wim-solution.sip.local:3006/projects'),
    headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
  );
  if (response.statusCode == 200) {
    return compute(parseTools, response.body);
  }
  throw Exception('Failed to fetch tools');
}

Future<List<Machine>> _fetchMachines() async {
  final response = await http.get(
    Uri.parse('http://wim-solution.sip.local:3006/machines'),
    headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
  );
  if (response.statusCode == 200) {
    return compute(parseMachines, response.body);
  }
  throw Exception('Failed to fetch machines');
}

Future<List<String>> _fetchMaterials() async {
  final response = await http.get(
    Uri.parse('http://wim-solution.sip.local:3006/material'),
    headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
  );
  if (response.statusCode == 200) {
    return compute(parseMaterials, response.body);
  }
  throw Exception('Failed to fetch materials');
}

Future<List<String>> _fetchEmployees() async {
  final response = await http.get(
    Uri.parse('http://wim-solution.sip.local:3006/employee'),
    headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
  );
  if (response.statusCode == 200) {
    return compute(parseEmployees, response.body);
  }
  throw Exception('Failed to fetch employees');
}

// ----------------------------
// Helper class for Favorites
// ----------------------------
class FavoriteModule {
  final String title;
  final Widget icon;
  final VoidCallback onTap;
  FavoriteModule({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

// ----------------------------
// Main Page: NumberInputPage
// ----------------------------
class NumberInputPage extends StatefulWidget {
  const NumberInputPage({super.key});

  @override
  _NumberInputPageState createState() => _NumberInputPageState();
}

class _NumberInputPageState extends State<NumberInputPage>
    with WidgetsBindingObserver {
  final TextEditingController _numberController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Scanner
  final MobileScannerController mobileScannerController =
      MobileScannerController();

  bool hasScanned = false;
  Timer? scanTimer;
  List<String> recentItems = [];
  List<String> profileSuggestions = [];

  // Data lists
  List<String> areaCenters = [];
  List<String> lines = [];
  List<String> tools = [];
  List<Machine> machines = [];
  List<String> materials = [];
  List<String> employees = [];
  bool isDataLoaded = false;

  // Mapping
  Map<String, String> machinePitchToLineMap = {};

  // ----------------------------
  // Favorites list (initially empty)
  final List<FavoriteModule> _favorites = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecentItems();
    _preloadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    mobileScannerController.dispose();
    _numberController.dispose();
    scanTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      mobileScannerController.stop();
    } else if (state == AppLifecycleState.resumed) {
      mobileScannerController.start();
    }
  }

  /// Preload all necessary data.
  void _preloadData() async {
    try {
      final fetchedAreaCenters = await _fetchAreaCenters();
      final fetchedLines = await _fetchLines();
      final fetchedTools = await _fetchTools();
      final fetchedMachines = await _fetchMachines();
      final fetchedEmployees = await _fetchEmployees();
      final fetchedMaterials = await _fetchMaterials();

      setState(() {
        areaCenters = fetchedAreaCenters;
        lines = fetchedLines;
        tools = fetchedTools;
        machines = fetchedMachines;
        employees = fetchedEmployees;
        materials = fetchedMaterials;
        isDataLoaded = true;

        // Build the machine->line map.
        machinePitchToLineMap = _buildMachineToLineMap(lines, machines);
        if (kDebugMode) {
          print('Machine to Line Map: $machinePitchToLineMap');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading data: $e');
      }
    }
  }

  /// Builds a mapping from machine number -> line.
  Map<String, String> _buildMachineToLineMap(
      List<String> lines, List<Machine> machines) {
    Map<String, String> map = {};
    final lineSet = lines.map((ln) => ln.trim().toUpperCase()).toSet();

    for (var machine in machines) {
      final machineNumber = machine.number.trim().toUpperCase();
      var lineNumber = machine.salamanderlineNumber?.trim().toUpperCase();

      if ((lineNumber == null || lineNumber.isEmpty) &&
          machine.productionworkplaceNumber.toUpperCase().startsWith('S0')) {
        lineNumber = 'TTP-${machine.productionworkplaceNumber.toUpperCase()}';
      }

      if (lineNumber != null && lineNumber.isNotEmpty) {
        if (lineSet.contains(lineNumber)) {
          map[machineNumber] = lineNumber;
        } else {
          if (kDebugMode) {
            print('No corresponding line in lines for $lineNumber');
          }
        }
      }
    }
    return map;
  }

  /// Load recent items.
  void _loadRecentItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedItems = prefs.getStringList('recentItems') ?? [];
      setState(() {
        recentItems = savedItems;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading recent items: $e');
      }
    }
  }

  void _clearRecentItems() async {
    setState(() => recentItems.clear());
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('recentItems', []);
  }

  Timer? _debounce;
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchProfileSuggestions(value);
    });
  }

  /// ----------------------------
  /// Favorites area widget.
  /// ----------------------------
  Widget _buildFavoritesArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and an add button.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Favoriten',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showAddFavoriteDialog,
              ),
            ],
          ),
        ),
        // Horizontal list of favorite modules.
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _favorites.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final fav = _favorites[index];
              return GestureDetector(
                onTap: fav.onTap,
                child: Container(
                  width: 80,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      fav.icon,
                      const SizedBox(height: 8),
                      Text(
                        fav.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Show a dialog to add a favorite.
  /// (For simplicity, we provide a fixed list of available modules.)
  void _showAddFavoriteDialog() {
    // A list of available modules.
    final availableModules = <FavoriteModule>[
      FavoriteModule(
        title: 'Störfall anlegen',
        icon: const Icon(Icons.add_alert, size: 32, color: Colors.red),
        onTap: _openIssueModal,
      ),
      FavoriteModule(
        title: 'Torsteuerung',
        icon: const Icon(Icons.door_sliding, size: 32),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const TorsteuerungModule(initialUrl: 'https://google.de'),
            ),
          );
        },
      ),
      // Add more available modules as needed…
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Favoriten hinzufügen'),
          children: availableModules.map((module) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() {
                  // Add if not already present.
                  if (!_favorites.any((fav) => fav.title == module.title)) {
                    _favorites.add(module);
                  }
                });
                Navigator.pop(ctx);
              },
              child: Row(
                children: [
                  module.icon,
                  const SizedBox(width: 12),
                  Text(module.title),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Open the Issue Modal directly (without scanning) using a dummy code.
  void _openIssueModal() {
    // Here we use an empty code or a placeholder.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: CreateIssueModal(
            scannedCode: '',
            selectedToolBreakdown: null,
            selectedMachineNumber: null,
            selectedMachinePitch: null,
            correspondingLine: null,
            areaCenters: areaCenters,
            lines: lines,
            tools: tools,
            machines: machines,
            materials: materials,
            employees: employees,
            machinePitchToLineMap: machinePitchToLineMap,
          ),
        );
      },
    );
  }

  // ----------------------------
  // Build method.
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    if (!isDataLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('ttp App')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final scannerHeight = MediaQuery.of(context).size.shortestSide * 0.4;
    final scannerWidth = MediaQuery.of(context).size.width;
    final scanWindow = Rect.fromCenter(
      center: Offset(scannerWidth / 2, scannerHeight / 2),
      width: 150,
      height: 150,
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/leuchtturm.png', height: 36, width: 36),
            const SizedBox(width: 2),
            const Text('ttp App'),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      drawer: const MainDrawer(),
      endDrawer: RecentItemsDrawer(
        recentItems: recentItems,
        clearRecentItems: _clearRecentItems,
        wim: wim,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (!Platform.isWindows)
              SizedBox(
                height: scannerHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: mobileScannerController,
                      scanWindow: scanWindow,
                      onDetect: (capture) {
                        if (!hasScanned && isDataLoaded) {
                          final code = capture.barcodes.first.rawValue;
                          if (code != null) {
                            setState(() => hasScanned = true);
                            Vibration.vibrate(duration: 50);
                            _processScannedData(code);
                          }
                        }
                      },
                    ),
                    ScanWindowOverlay(scanWindow: scanWindow),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: (hasScanned || _numberController.text.isNotEmpty)
                    ? _openUrlWithNumber
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text('Profilverzeichnis öffnen'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Autocomplete<String>(
                optionsBuilder: (value) {
                  return profileSuggestions.where((sug) =>
                      sug.toLowerCase().contains(value.text.toLowerCase()));
                },
                onSelected: (selectedProfile) {
                  _numberController.text = selectedProfile;
                  _openUrlWithNumber();
                },
                fieldViewBuilder:
                    (ctx, textEditingController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onSubmitted: (_) {
                      onFieldSubmitted();
                      _addRecentItem(textEditingController.text.trim());
                    },
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: 'Profilnummer eingeben',
                      hintText: 'Geben Sie eine Profilnummer ein',
                    ),
                  );
                },
              ),
            ),
            // Favorites area added here.
            _buildFavoritesArea(),
            // IKOffice link cards.
            _buildLinkCard('PZE', ikOfficePZE),
            _buildLinkCard('Linienkonfiguration', ikOfficeLineConfig),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkCard(String title, String url) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WebViewModule(url: url)),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/IKOffice.ico', width: 72, height: 72),
              const SizedBox(width: 16),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  void _processScannedData(String scannedData) {
    String fullUrl = scannedData;
    if (scannedData.length == 5) {
      fullUrl = 'https://wim-solution.sip.local:8081/$scannedData';
    }
    String codeToUse;
    try {
      final uri = Uri.parse(scannedData);
      codeToUse =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : scannedData;
    } catch (_) {
      codeToUse = scannedData;
    }
    _showOptionsModal(fullUrl, codeToUse);

    scanTimer = Timer(const Duration(seconds: 3), () {
      setState(() => hasScanned = false);
    });
  }

  void _showOptionsModal(String fullUrl, String codeToUse) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Wählen Sie eine Aktion aus',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Werkzeug- oder Maschinendetails öffnen'),
              onTap: () {
                Navigator.pop(context);
                _navigateToUrl(fullUrl);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_alert),
              title: const Text('Störfall anlegen'),
              onTap: () {
                Navigator.pop(context);
                _reportIssue(codeToUse);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToUrl(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WebViewModule(url: url)),
    );
  }

  void _openUrlWithNumber() async {
    final number = _numberController.text.trim().toUpperCase();
    if (number.isNotEmpty) {
      final url = '$wim/$number';
      if (await canLaunch(url)) {
        _navigateToUrl(url);
        _addRecentItem(url);
      } else {
        if (kDebugMode) print('Could not launch $url');
      }
    }
  }

  void _addRecentItem(String url) async {
    final uri = Uri.parse(url);
    final profileNum = uri.pathSegments.last;

    setState(() {
      if (!recentItems.contains(profileNum)) {
        recentItems.insert(0, profileNum);
        if (recentItems.length > 10) {
          recentItems.removeLast();
        }
      }
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('recentItems', recentItems);
  }

  /// Called when user chooses “Störfall anlegen” for a scanned code.
  void _reportIssue(String scannedCode) {
    if (kDebugMode) {
      print('Reporting issue for: $scannedCode');
      print(
          'Tools: ${tools.length}, Machines: ${machines.length}, Lines: ${lines.length}');
    }

    final normalized = scannedCode.trim().toUpperCase();

    String? selectedToolBreakdown;
    String? selectedMachineNumber;
    String? selectedMachinePitch;
    String? correspondingLine;

    // Match tool first.
    for (var t in tools) {
      if (t.trim().toUpperCase() == normalized) {
        selectedToolBreakdown = t;
        break;
      }
    }

    // If not a tool, check machines.
    if (selectedToolBreakdown == null) {
      for (var m in machines) {
        if (m.number.trim().toUpperCase() == normalized) {
          selectedMachineNumber = m.number;
          selectedMachinePitch = m.salamandermachinepitch;
          break;
        }
      }
    }

    // If machine found, find line via machinePitchToLineMap.
    if (selectedMachineNumber != null) {
      final key = selectedMachineNumber.trim().toUpperCase();
      correspondingLine = machinePitchToLineMap[key];
    }

    if (kDebugMode) {
      print('Matched tool: $selectedToolBreakdown');
      print(
          'Matched machine: $selectedMachineNumber (pitch: $selectedMachinePitch)');
      print('Line: $correspondingLine');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: CreateIssueModal(
            scannedCode: scannedCode,
            selectedToolBreakdown: selectedToolBreakdown,
            selectedMachineNumber: selectedMachineNumber,
            selectedMachinePitch: selectedMachinePitch,
            correspondingLine: correspondingLine,
            areaCenters: areaCenters,
            lines: lines,
            tools: tools,
            machines: machines,
            materials: materials,
            employees: employees,
            machinePitchToLineMap: machinePitchToLineMap,
          ),
        );
      },
    );

    scanTimer = Timer(const Duration(seconds: 3), () {
      setState(() => hasScanned = false);
    });
  }

  Future<void> _fetchProfileSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => profileSuggestions = []);
      return;
    }
    try {
      final ioClient = io_http.IOClient(
          HttpClient()..badCertificateCallback = (_, __, ___) => true);

      final response = await ioClient.get(
        Uri.parse('$apiUrl&q=$query'),
        headers: {
          'accept': 'application/json',
          'X-Api-Key': apiKey,
        },
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['shortUrls']['data'] as List<dynamic>;
        final userEnteredValue = query.trim();
        setState(() {
          profileSuggestions = [
            userEnteredValue,
            ...data
                .map<String>((item) => item['title']?.toString() ?? '')
                .where((s) => s.isNotEmpty),
          ];
        });
      }
      ioClient.close();
    } catch (e) {
      if (kDebugMode) print('Error fetching profile suggestions: $e');
    }
  }
}

/// ----------------------------
/// Modal for creating an issue.
/// ----------------------------
class CreateIssueModal extends StatefulWidget {
  final String scannedCode;
  final String? selectedToolBreakdown;
  final String? selectedMachineNumber;
  final String? selectedMachinePitch;
  final String? correspondingLine;

  final List<String> areaCenters;
  final List<String> lines;
  final List<String> tools;
  final List<Machine> machines;
  final List<String> materials;
  final List<String> employees;
  final Map<String, String> machinePitchToLineMap;

  const CreateIssueModal({
    super.key,
    required this.scannedCode,
    this.selectedToolBreakdown,
    this.selectedMachineNumber,
    this.selectedMachinePitch,
    this.correspondingLine,
    required this.areaCenters,
    required this.lines,
    required this.tools,
    required this.machines,
    required this.materials,
    required this.employees,
    required this.machinePitchToLineMap,
  });

  @override
  _CreateIssueModalState createState() => _CreateIssueModalState();
}

class _CreateIssueModalState extends State<CreateIssueModal> {
  bool operable = true;

  String? selectedAreaCenter;
  String? selectedLine;
  String? selectedToolBreakdown;
  String? selectedMachineNumber;
  String? selectedMachinePitch;
  String? selectedMaterialBreakdown;
  String? selectedEmployee;
  // This variable will hold the HTML version (to be submitted)
  String? workCardComment;
  String? imagePath;

  final TextEditingController employeeController = TextEditingController();
  final TextEditingController areaCenterController = TextEditingController();
  final TextEditingController lineController = TextEditingController();
  final TextEditingController toolController = TextEditingController();
  final TextEditingController machineController = TextEditingController();
  final TextEditingController materialController = TextEditingController();

  late TextEditingController _commentController;
  late FocusNode commentFocusNode;

  @override
  void initState() {
    super.initState();

    if (widget.selectedToolBreakdown?.isNotEmpty ?? false) {
      selectedToolBreakdown = widget.selectedToolBreakdown;
      toolController.text = selectedToolBreakdown!;
    }
    if (widget.selectedMachineNumber?.isNotEmpty ?? false) {
      selectedMachineNumber = widget.selectedMachineNumber;
      machineController.text = selectedMachineNumber!;
    }
    if (widget.correspondingLine?.isNotEmpty ?? false) {
      selectedLine = widget.correspondingLine;
      lineController.text = selectedLine!;
    }
    if (widget.selectedMachinePitch?.isNotEmpty ?? false) {
      selectedMachinePitch = widget.selectedMachinePitch;
    }

    _commentController = TextEditingController(text: '');
    commentFocusNode = FocusNode();
  }

  @override
  void dispose() {
    employeeController.dispose();
    areaCenterController.dispose();
    lineController.dispose();
    toolController.dispose();
    machineController.dispose();
    materialController.dispose();
    _commentController.dispose();
    commentFocusNode.dispose();
    super.dispose();
  }

  bool _validateForm({
    required bool operable,
    required String? areaCenter,
    required String? line,
    required String? employee,
    required String? toolBreakdown,
    required String? machineBreakdown,
    required String? materialBreakdown,
    required String? workCardComment,
  }) {
    bool hasBreakdown = ((toolBreakdown != null && toolBreakdown.isNotEmpty) ||
        (machineBreakdown != null && machineBreakdown.isNotEmpty) ||
        (materialBreakdown != null && materialBreakdown.isNotEmpty));

    return areaCenter != null &&
        areaCenter.isNotEmpty &&
        line != null &&
        line.isNotEmpty &&
        employee != null &&
        employee.isNotEmpty &&
        hasBreakdown &&
        workCardComment != null &&
        workCardComment.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Störfall anlegen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: operable,
                  onChanged: (val) => setState(() => operable = val ?? true),
                ),
                const Text('Betrieb möglich?'),
              ],
            ),
            TypeAheadField<String>(
              controller: employeeController,
              builder: (ctx, textCtrl, fn) {
                return TextField(
                  controller: textCtrl,
                  focusNode: fn,
                  decoration:
                      const InputDecoration(labelText: 'Ersteller Störfall'),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.employees
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (ctx, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSelected: (suggestion) {
                employeeController.text = suggestion;
                selectedEmployee = suggestion;
              },
            ),
            const SizedBox(height: 16),
            TypeAheadField<String>(
              controller: areaCenterController,
              builder: (ctx, textCtrl, fn) {
                return TextField(
                  controller: textCtrl,
                  focusNode: fn,
                  decoration:
                      const InputDecoration(labelText: 'Zuständige Stelle'),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.areaCenters
                    .where((ac) =>
                        ac.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (ctx, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSelected: (suggestion) {
                areaCenterController.text = suggestion;
                selectedAreaCenter = suggestion;
              },
            ),
            const SizedBox(height: 16),
            TypeAheadField<String>(
              controller: lineController,
              builder: (ctx, textCtrl, fn) {
                return TextField(
                  controller: textCtrl,
                  focusNode: fn,
                  decoration:
                      const InputDecoration(labelText: 'Linie oder Stellplatz'),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.lines
                    .where(
                        (l) => l.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (ctx, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSelected: (suggestion) {
                lineController.text = suggestion;
                selectedLine = suggestion;
              },
            ),
            const SizedBox(height: 16),
            TypeAheadField<String>(
              controller: toolController,
              builder: (ctx, textCtrl, fn) {
                return TextField(
                  controller: textCtrl,
                  focusNode: fn,
                  decoration: const InputDecoration(labelText: 'Werkzeug'),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.tools
                    .where(
                        (t) => t.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (ctx, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSelected: (suggestion) {
                toolController.text = suggestion;
                selectedToolBreakdown = suggestion;
              },
            ),
            const SizedBox(height: 16),
            TypeAheadField<String>(
              controller: machineController,
              builder: (ctx, textCtrl, fn) {
                return TextField(
                  controller: textCtrl,
                  focusNode: fn,
                  decoration:
                      const InputDecoration(labelText: 'Maschine / Anlage'),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.machines
                    .where((m) =>
                        m.number.toLowerCase().contains(pattern.toLowerCase()))
                    .map((m) => m.number)
                    .toList();
              },
              itemBuilder: (ctx, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSelected: (suggestion) {
                machineController.text = suggestion;
                selectedMachineNumber = suggestion;
                final found = widget.machines.firstWhere(
                  (m) => m.number == suggestion,
                  orElse: () => Machine(
                    number: '',
                    salamandermachinepitch: '',
                    salamanderlineNumber: null,
                    productionworkplaceNumber: '',
                  ),
                );
                String? machineCode;
                if ((found.salamanderlineNumber?.isNotEmpty ?? false)) {
                  machineCode =
                      found.salamanderlineNumber!.trim().toUpperCase();
                } else if (found.productionworkplaceNumber
                    .toUpperCase()
                    .startsWith('S0')) {
                  machineCode =
                      'TTP-${found.productionworkplaceNumber.toUpperCase()}';
                }
                if (machineCode != null && machineCode.isNotEmpty) {
                  final mappedLine = widget.machinePitchToLineMap[machineCode];
                  if (mappedLine != null && mappedLine.isNotEmpty) {
                    setState(() {
                      selectedLine = mappedLine;
                      lineController.text = mappedLine;
                    });
                  } else {
                    setState(() {
                      selectedLine = '';
                      lineController.text = '';
                    });
                  }
                } else {
                  setState(() {
                    selectedLine = '';
                    lineController.text = '';
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TypeAheadField<String>(
              controller: materialController,
              builder: (ctx, textCtrl, fn) {
                return TextField(
                  controller: textCtrl,
                  focusNode: fn,
                  decoration: const InputDecoration(labelText: 'Material'),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.materials
                    .where((mat) =>
                        mat.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (ctx, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSelected: (suggestion) {
                materialController.text = suggestion;
                selectedMaterialBreakdown = suggestion;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              focusNode: commentFocusNode,
              maxLines: 5,
              minLines: 5,
              decoration: InputDecoration(
                labelText: 'Fehlerbeschreibung',
                hintText: 'Kommentar eingeben oder Vorschlag wählen',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: () async {
                    final choice = await showDialog<String>(
                      context: context,
                      builder: (ctx) {
                        return SimpleDialog(
                          title: const Text('Kommentar Typ wählen'),
                          children: [
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, 'suggestion'),
                              child: const Text(
                                'Text auswählen',
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, 'free'),
                              child: const Text('Freier Text'),
                            ),
                          ],
                        );
                      },
                    );
                    if (choice == 'suggestion') {
                      final selectedComment = await showPredefinedTextsModal(
                        context,
                        initialText: _commentController.text,
                      );
                      if (selectedComment != null) {
                        setState(() {
                          _commentController.text = selectedComment.plain;
                          workCardComment = selectedComment.html;
                        });
                      }
                      commentFocusNode.requestFocus();
                    }
                  },
                ),
              ),
              onChanged: (val) {
                workCardComment = val;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickImage,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text('Bild auswählen\noder Foto aufnehmen',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (imagePath != null) Text('Ausgewählt: $imagePath'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onSubmitIssue,
                  child: const Text('An IKOffice senden'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bildquelle wählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_album),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) {
      if (kDebugMode) print('No image selected.');
      return;
    }

    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      if (kDebugMode) print('File is empty or invalid.');
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final savedFilePath =
        path.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
    final savedFile = await file.copy(savedFilePath);

    setState(() => imagePath = savedFile.path);
    if (kDebugMode) print('Image saved at: $imagePath');
  }

  void _onSubmitIssue() async {
    if (!_validateForm(
      operable: operable,
      areaCenter: selectedAreaCenter,
      line: selectedLine,
      employee: selectedEmployee,
      toolBreakdown: toolController.text,
      machineBreakdown: machineController.text,
      materialBreakdown: materialController.text,
      workCardComment: workCardComment,
    )) {
      _showOverlayMessage('Bitte alle erforderlichen Felder ausfüllen.');
      return;
    }

    if (imagePath != null) {
      final file = File(imagePath!);
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showOverlayMessage('Das Bild ist ungültig oder beschädigt.');
        return;
      }
    }

    final issueData = <String, String>{
      'operable': operable.toString(),
      'areaCenter': selectedAreaCenter ?? '',
      'line': selectedLine ?? '',
      'employee': selectedEmployee ?? '',
      'toolBreakdown': toolController.text,
      'machineBreakdown': machineController.text,
      'materialBreakdown': materialController.text,
      'workCardComment': workCardComment ?? '',
      'imageFile': imagePath ?? '',
    };

    await _submitIssue(issueData);

    Navigator.pop(context);
    _showOverlayMessage('Störfall angelegt!', backgroundColor: Colors.green);
    if (kDebugMode) print('Issue submitted successfully.');
  }

  Future<void> _submitIssue(Map<String, String> data) async {
    final uri = Uri.parse('http://wim-solution.sip.local:3006/report-issue');
    final request = http.MultipartRequest('POST', uri);

    data.forEach((key, value) {
      if (key != 'imageFile') {
        request.fields[key] = value;
      }
    });

    final imgPath = data['imageFile'];
    if (imgPath != null && imgPath.isNotEmpty) {
      final imageFile = File(imgPath);
      String mimeType = 'application/octet-stream';
      final ext = path.extension(imgPath).toLowerCase();
      if (ext == '.jpg' || ext == '.jpeg') {
        mimeType = 'image/jpeg';
      } else if (ext == '.png') {
        mimeType = 'image/png';
      } else if (ext == '.gif') {
        mimeType = 'image/gif';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ),
      );
    }

    try {
      final response = await request.send();
      if (response.statusCode != 201) {
        final errMsg = await response.stream.bytesToString();
        _showOverlayMessage('Fehler: $errMsg');
        if (kDebugMode) print('Failed: $errMsg');
      } else {
        if (kDebugMode) print('Issue successfully submitted.');
      }
    } catch (e) {
      _showOverlayMessage('Fehler beim Senden des Störfalls: $e');
      if (kDebugMode) print('Exception: $e');
    }
  }

  void _showOverlayMessage(String msg, {Color backgroundColor = Colors.red}) {
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(8),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              msg,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () => entry.remove());
  }
}

/// ----------------------------
/// Overlay for scan window.
/// ----------------------------
class ScanWindowOverlay extends StatelessWidget {
  final Rect scanWindow;
  const ScanWindowOverlay({super.key, required this.scanWindow});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScanWindowPainter(scanWindow),
      child: Container(),
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  final Rect scanWindow;
  _ScanWindowPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.lightBlue
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final corner = 30.0;

    // top-left
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.top),
      Offset(scanWindow.left + corner, scanWindow.top),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.top),
      Offset(scanWindow.left, scanWindow.top + corner),
      paint,
    );

    // top-right
    canvas.drawLine(
      Offset(scanWindow.right, scanWindow.top),
      Offset(scanWindow.right - corner, scanWindow.top),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindow.right, scanWindow.top),
      Offset(scanWindow.right, scanWindow.top + corner),
      paint,
    );

    // bottom-left
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.bottom),
      Offset(scanWindow.left + corner, scanWindow.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.bottom),
      Offset(scanWindow.left, scanWindow.bottom - corner),
      paint,
    );

    // bottom-right
    canvas.drawLine(
      Offset(scanWindow.right, scanWindow.bottom),
      Offset(scanWindow.right - corner, scanWindow.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindow.right, scanWindow.bottom),
      Offset(scanWindow.right, scanWindow.bottom - corner),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

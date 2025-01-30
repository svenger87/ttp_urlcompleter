// number_input_page.dart

// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ttp_app/constants.dart';
import 'package:ttp_app/widgets/drawer_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../modules/webview_module.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http/io_client.dart'
    as io_http; // Changed prefix to avoid conflict
import 'package:flutter_typeahead/flutter_typeahead.dart';

/// Model class for Machine
class Machine {
  final String number;
  final String salamandermachinepitch;

  Machine({required this.number, required this.salamandermachinepitch});

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      number: json['number'] ?? '',
      salamandermachinepitch: json['salamandermachinepitch'] ?? '',
    );
  }
}

class NumberInputPage extends StatefulWidget {
  const NumberInputPage({super.key});

  @override
  _NumberInputPageState createState() => _NumberInputPageState();
}

class _NumberInputPageState extends State<NumberInputPage>
    with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final TextEditingController _numberController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  QRViewController? controller;
  bool hasScanned = false;
  Timer? scanTimer;
  List<String> recentItems = [];
  List<String> profileSuggestions = [];

  // Data lists
  List<String> areaCenters = [];
  List<String> lines = [];
  List<String> tools = [];
  List<Machine> machines = []; // Changed to list of Machine objects
  List<String> materials = [];
  List<String> employees = [];
  bool isDataLoaded = false;

  // Mapping from salamandermachinepitch to corresponding line
  Map<String, String> machinePitchToLineMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecentItems();
    _preloadData();
  }

  /// Preload all necessary data and build the mapping
  void _preloadData() async {
    try {
      // Fetch each data type sequentially to preserve type information
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

        // Build the machine to line mapping
        machinePitchToLineMap = _buildMachineToLineMap(lines, machines);
        if (kDebugMode) {
          print('Machine to Line Map: $machinePitchToLineMap');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading data: $e');
      }
      // Optionally, you can show an error message to the user here
    }
  }

  /// Builds a mapping from salamandermachinepitch to corresponding lines
  Map<String, String> _buildMachineToLineMap(
      List<String> lines, List<Machine> machines) {
    Map<String, String> map = {};
    for (var machine in machines) {
      String machineCode = machine.salamandermachinepitch.trim().toUpperCase();
      // Find the first line that ends with the machine code
      String? correspondingLine = lines.firstWhere(
        (line) => line.toUpperCase().endsWith(machineCode),
        orElse: () => '',
      );
      if (correspondingLine.isNotEmpty) {
        map[machineCode] = correspondingLine;
      } else {
        if (kDebugMode) {
          print('No corresponding line found for machine code: $machineCode');
        }
      }
    }
    return map;
  }

  /// Load recent items from shared preferences
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    _numberController.dispose();
    scanTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller != null) {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused) {
        controller!.pauseCamera();
      } else if (state == AppLifecycleState.resumed) {
        controller!.resumeCamera();
      }
    }
  }

  Timer? _debounce;

  /// Debounce for search input
  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchProfileSuggestions(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isDataLoaded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ttp App'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
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
                height: MediaQuery.of(context).size.shortestSide * 0.4,
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderRadius: 10,
                    borderColor: Theme.of(context).primaryColor,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: MediaQuery.of(context).size.shortestSide * 0.4,
                  ),
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
                optionsBuilder: (TextEditingValue textEditingValue) {
                  return profileSuggestions
                      .where((String suggestion) => suggestion
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()))
                      .toList();
                },
                onSelected: (String selectedProfile) {
                  _numberController.text = selectedProfile;
                  _openUrlWithNumber();
                },
                fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
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
            _buildLinkCard('PZE', ikOfficePZE),
            _buildLinkCard('Linienkonfiguration', ikOfficeLineConfig),
          ],
        ),
      ),
    );
  }

  /// Builds a link card with an icon and title
  Widget _buildLinkCard(String title, String url) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewModule(url: url),
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/IKOffice.ico', width: 72, height: 72),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles reporting an issue based on the scanned code
  void _reportIssue(String scannedCode) {
    if (kDebugMode) {
      print('Reporting issue for scanned code: $scannedCode');
      print('Tools list loaded with ${tools.length} items');
      print('Machines list loaded with ${machines.length} items');
      print('Lines list loaded with ${lines.length} items');
    }

    String normalizedScannedCode = scannedCode.trim().toUpperCase();

    String? selectedToolBreakdown;
    String? selectedMachineBreakdown;
    String? correspondingLine;

    // Find if the scanned code matches any tool
    for (var tool in tools) {
      String normalizedTool = tool.trim().toUpperCase();
      if (normalizedTool.contains(normalizedScannedCode) ||
          normalizedScannedCode.contains(normalizedTool)) {
        selectedToolBreakdown = tool;
        break;
      }
    }

    // If not a tool, check if it's a machine
    if (selectedToolBreakdown == null) {
      for (var machine in machines) {
        String normalizedMachine =
            machine.salamandermachinepitch.trim().toUpperCase();
        if (normalizedMachine.contains(normalizedScannedCode) ||
            normalizedScannedCode.contains(normalizedMachine)) {
          selectedMachineBreakdown = machine.salamandermachinepitch;
          break;
        }
      }
    }

    // If a machine is found, find the corresponding line using the mapping
    if (selectedMachineBreakdown != null) {
      String machineCode = selectedMachineBreakdown.trim().toUpperCase();
      correspondingLine = machinePitchToLineMap[machineCode];
      if (correspondingLine == null && kDebugMode) {
        if (kDebugMode) {
          print('No corresponding line found for machine code: $machineCode');
        }
      }
    }

    if (kDebugMode) {
      print('Matched tool breakdown: $selectedToolBreakdown');
      print('Matched machine breakdown: $selectedMachineBreakdown');
      print('Corresponding line: $correspondingLine');
    }

    // Show the CreateIssueModal with the prefilled line if available
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: CreateIssueModal(
            scannedCode: scannedCode,
            selectedToolBreakdown: selectedToolBreakdown,
            selectedMachineBreakdown: selectedMachineBreakdown,
            correspondingLine: correspondingLine, // Pass the matching line
            areaCenters: areaCenters,
            lines: lines,
            tools: tools,
            machines: machines,
            materials: materials,
            employees: employees,
          ),
        );
      },
    );

    // Reset scan state after a delay
    scanTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        hasScanned = false;
      });
    });
  }

  /// Handles the QR view creation and scanning
  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) async {
      if (!hasScanned && isDataLoaded) {
        setState(() {
          hasScanned = true;
        });

        Vibration.vibrate(duration: 50);

        String scannedData = scanData.code!;
        if (kDebugMode) {
          print('Scanned QR Code: $scannedData');
        }

        String fullUrl = scannedData;

        // If the scanned QR code has exactly 5 characters, prepend the machine URL
        if (scannedData.length == 5) {
          fullUrl = 'https://wim-solution.sip.local:8081/$scannedData';
        }

        String codeToUse;
        try {
          Uri uri = Uri.parse(scannedData);
          codeToUse =
              uri.pathSegments.isNotEmpty ? uri.pathSegments.last : scannedData;
        } catch (e) {
          codeToUse = scannedData;
        }

        if (kDebugMode) {
          print('Processed URL: $fullUrl');
          print('Extracted code: $codeToUse');
        }

        _showOptionsModal(fullUrl, codeToUse);

        scanTimer = Timer(const Duration(seconds: 3), () {
          setState(() {
            hasScanned = false;
          });
        });
      }
    });
  }

  /// Displays the options modal after scanning
  void _showOptionsModal(String fullUrl, String codeToUse) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
        );
      },
    );
  }

  /// Navigates to the specified URL using WebViewModule
  void _navigateToUrl(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewModule(url: url),
      ),
    );
  }

  /// Opens the profile directory URL based on the entered number
  void _openUrlWithNumber() async {
    final String number = _numberController.text.trim().toUpperCase();

    if (number.isNotEmpty) {
      final url = '$wim/$number';

      if (await canLaunch(url)) {
        _navigateToUrl(url);
        _addRecentItem(url);
      } else {
        if (kDebugMode) {
          print('Could not launch $url');
        }
        // Optionally, show an error message to the user here
      }
    }
  }

  /// Adds an item to the recent items list and saves it
  void _addRecentItem(String item) async {
    final Uri uri = Uri.parse(item);
    final String profileNumber = uri.pathSegments.last;

    setState(() {
      if (!recentItems.contains(profileNumber)) {
        recentItems.insert(0, profileNumber);
        if (recentItems.length > 10) {
          recentItems.removeLast();
        }
      }
    });

    await _saveRecentItems();
  }

  /// Saves the recent items list to shared preferences
  Future<void> _saveRecentItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentItems', recentItems);
  }

  /// Clears the recent items list
  void _clearRecentItems() {
    setState(() {
      recentItems.clear();
    });
    _saveRecentItems();
  }

  /// Fetches area centers from the API
  Future<List<String>> _fetchAreaCenters() async {
    final response = await http.get(
        Uri.parse('http://wim-solution.sip.local:3006/salamanderareacenter'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => e['name'].toString()).toList();
    } else {
      throw Exception('Failed to fetch area centers');
    }
  }

  /// Fetches lines from the API
  Future<List<String>> _fetchLines() async {
    final response = await http
        .get(Uri.parse('http://wim-solution.sip.local:3006/salamanderline'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => e['number'].toString()).toList();
    } else {
      throw Exception('Failed to fetch lines');
    }
  }

  /// Fetches tools from the API
  Future<List<String>> _fetchTools() async {
    final response = await http
        .get(Uri.parse('http://wim-solution.sip.local:3006/projects'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => e['number'].toString()).toList();
    } else {
      throw Exception('Failed to fetch tools');
    }
  }

  /// Fetches machines from the API and parses them into Machine objects
  Future<List<Machine>> _fetchMachines() async {
    final response = await http
        .get(Uri.parse('http://wim-solution.sip.local:3006/machines'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Machine.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch machines');
    }
  }

  /// Fetches materials from the API
  Future<List<String>> _fetchMaterials() async {
    final response = await http
        .get(Uri.parse('http://wim-solution.sip.local:3006/material'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => e['name'].toString()).toList();
    } else {
      throw Exception('Failed to fetch materials');
    }
  }

  /// Fetches employees from the API
  Future<List<String>> _fetchEmployees() async {
    final response = await http
        .get(Uri.parse('http://wim-solution.sip.local:3006/employee'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) =>
              '${e['employeenumber']} - ${e['firstname']} ${e['lastname']}')
          .toList();
    } else {
      throw Exception('Failed to fetch employees');
    }
  }

  /// Fetches profile suggestions based on the search query
  Future<void> _fetchProfileSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        profileSuggestions = [];
      });
      return;
    }

    try {
      final ioClient = io_http.IOClient(
          HttpClient()..badCertificateCallback = ((_, __, ___) => true));
      final response = await ioClient.get(
        Uri.parse('$apiUrl&q=$query'),
        headers: {
          'accept': 'application/json',
          'X-Api-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['shortUrls']['data'];

        setState(() {
          final userEnteredValue = query.trim();
          profileSuggestions = [
            userEnteredValue,
            ...data
                .map<String>((item) => item['title']?.toString() ?? '')
                .where((suggestion) => suggestion.isNotEmpty),
          ];
        });
      } else {
        if (kDebugMode) {
          print(
              'Error fetching profile suggestions. Status code: ${response.statusCode}');
        }
      }

      ioClient.close();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching profile suggestions: $e');
      }
    }
  }
}

/// Modal for creating an issue
class CreateIssueModal extends StatefulWidget {
  final String scannedCode;
  final String? selectedToolBreakdown;
  final String? selectedMachineBreakdown;
  final String? correspondingLine; // New parameter
  final List<String> areaCenters;
  final List<String> lines;
  final List<String> tools;
  final List<Machine> machines;
  final List<String> materials;
  final List<String> employees;

  const CreateIssueModal({
    super.key,
    required this.scannedCode,
    this.selectedToolBreakdown,
    this.selectedMachineBreakdown,
    this.correspondingLine, // Initialize the new parameter
    required this.areaCenters,
    required this.lines,
    required this.tools,
    required this.machines,
    required this.materials,
    required this.employees,
  });

  @override
  _CreateIssueModalState createState() => _CreateIssueModalState();
}

class _CreateIssueModalState extends State<CreateIssueModal> {
  bool operable = true;
  String? selectedAreaCenter;
  String? selectedLine;
  String? selectedToolBreakdown;
  String? selectedMachineBreakdown;
  String? selectedMaterialBreakdown;
  String? selectedEmployee;
  String? workCardComment;
  String? imagePath;

  final TextEditingController employeeController = TextEditingController();
  final TextEditingController areaCenterController = TextEditingController();
  final TextEditingController lineController = TextEditingController();
  final TextEditingController toolController = TextEditingController();
  final TextEditingController machineController = TextEditingController();
  final TextEditingController materialController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.selectedToolBreakdown != null &&
        widget.selectedToolBreakdown!.isNotEmpty) {
      selectedToolBreakdown = widget.selectedToolBreakdown;
      toolController.text = selectedToolBreakdown!;
    }
    if (widget.selectedMachineBreakdown != null &&
        widget.selectedMachineBreakdown!.isNotEmpty) {
      selectedMachineBreakdown = widget.selectedMachineBreakdown;
      machineController.text = selectedMachineBreakdown!;
    }

    // Prefill the line field if a corresponding line is provided
    if (widget.correspondingLine != null &&
        widget.correspondingLine!.isNotEmpty) {
      selectedLine = widget.correspondingLine;
      lineController.text = selectedLine!;
    }
  }

  @override
  void dispose() {
    employeeController.dispose();
    areaCenterController.dispose();
    lineController.dispose();
    toolController.dispose();
    machineController.dispose();
    materialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Störfall anlegen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Checkbox(
                  value: operable,
                  onChanged: (value) {
                    setState(() {
                      operable = value!;
                    });
                  },
                ),
                const Text('Betrieb möglich?'),
              ],
            ),

            // Employee selection
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: employeeController,
                decoration: const InputDecoration(
                  labelText: 'Mitarbeiter auswählen',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.employees
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSuggestionSelected: (suggestion) {
                employeeController.text = suggestion;
                selectedEmployee = suggestion;
              },
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Bitte Mitarbeiter auswählen'
                  : null,
            ),

            // Area Center selection
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: areaCenterController,
                decoration: const InputDecoration(
                  labelText: 'Zuständige Stelle',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.areaCenters
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSuggestionSelected: (suggestion) {
                areaCenterController.text = suggestion;
                selectedAreaCenter = suggestion;
              },
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Bitte zuständige Stelle auswählen'
                  : null,
            ),

            // Line selection
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: lineController,
                decoration: const InputDecoration(
                  labelText: 'Linie oder Stellplatz',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.lines
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSuggestionSelected: (suggestion) {
                lineController.text = suggestion;
                selectedLine = suggestion;
              },
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Bitte Linie oder Stellplatz auswählen'
                  : null,
            ),

            // Tool selection
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: toolController,
                decoration: const InputDecoration(
                  labelText: 'Werkzeug',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.tools
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSuggestionSelected: (suggestion) {
                toolController.text = suggestion;
                selectedToolBreakdown = suggestion;
              },
            ),

            // Machine selection
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: machineController,
                decoration: const InputDecoration(
                  labelText: 'Maschine / Anlage',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.machines
                    .where((machine) => machine.salamandermachinepitch
                        .toLowerCase()
                        .contains(pattern.toLowerCase()))
                    .map((machine) => machine.salamandermachinepitch)
                    .toList();
              },
              itemBuilder: (context, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSuggestionSelected: (suggestion) {
                machineController.text = suggestion;
                selectedMachineBreakdown = suggestion;
                // Attempt to prefill the corresponding line
                String? mappedLine = widget.correspondingLine;

                if (mappedLine != null && mappedLine.isNotEmpty) {
                  setState(() {
                    selectedLine = mappedLine;
                    lineController.text = selectedLine!;
                  });
                }
              },
            ),

            // Material selection
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: materialController,
                decoration: const InputDecoration(
                  labelText: 'Material',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.materials
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) =>
                  ListTile(title: Text(suggestion)),
              onSuggestionSelected: (suggestion) {
                materialController.text = suggestion;
                selectedMaterialBreakdown = suggestion;
              },
            ),

            // Work card comment
            TextField(
              decoration: const InputDecoration(
                labelText: 'Fehlerbeschreibung',
              ),
              onChanged: (value) {
                workCardComment = value;
              },
            ),

            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () async {
                final pickedImage = await _pickImage();
                if (pickedImage != null) {
                  setState(() {
                    imagePath = pickedImage.path;
                  });
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt),
                  const SizedBox(width: 8.0),
                  const Text('Bild auswählen\noder Foto aufnehmen',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            if (imagePath != null) Text('Ausgewählt: $imagePath'),

            const SizedBox(height: 16.0),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_validateForm(
                      operable: operable,
                      areaCenter: selectedAreaCenter,
                      line: selectedLine,
                      employee: selectedEmployee,
                      toolBreakdown: toolController.text,
                      machineBreakdown: machineController.text,
                      materialBreakdown: materialController.text,
                      workCardComment: workCardComment,
                      imagePath: imagePath,
                    )) {
                      _submitIssue({
                        'operable': operable.toString(),
                        'areaCenter': selectedAreaCenter!,
                        'line': selectedLine!,
                        'employee': selectedEmployee!,
                        'toolBreakdown': toolController.text,
                        'machineBreakdown': machineController.text,
                        'materialBreakdown': materialController.text,
                        'workCardComment': workCardComment!,
                        'imageFile': imagePath!,
                      });
                      Navigator.pop(context);
                      showOverlayMessage(context, 'Störfall angelegt!');
                    } else {
                      showOverlayMessage(context,
                          'Bitte alle erforderlichen Felder ausfüllen.');
                    }
                  },
                  child: const Text('An IKOffice senden'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shows an overlay message at the top of the screen
  void showOverlayMessage(BuildContext context, String message) {
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) return;

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50.0,
        left: 20.0,
        right: 20.0,
        child: Material(
          elevation: 10.0,
          borderRadius: BorderRadius.circular(8.0),
          color: Colors.red,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16.0),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  /// Picks an image from the camera or gallery
  Future<File?> _pickImage() async {
    final picker = ImagePicker();

    ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
        );
      },
    );

    if (source == null) return null;

    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  /// Validates the form fields
  bool _validateForm({
    required bool operable,
    required String? areaCenter,
    required String? line,
    required String? employee,
    required String? toolBreakdown,
    required String? machineBreakdown,
    required String? materialBreakdown,
    required String? workCardComment,
    required String? imagePath,
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
        workCardComment.isNotEmpty &&
        imagePath != null;
  }

  /// Submits the issue to the server
  void _submitIssue(Map<String, String> issueData) async {
    final uri = Uri.parse('http://wim-solution.sip.local:3006/report-issue');
    final request = http.MultipartRequest('POST', uri);

    issueData.forEach((key, value) {
      if (key != 'imageFile') {
        request.fields[key] = value;
      }
    });

    final imageFile = File(issueData['imageFile']!);
    request.files
        .add(await http.MultipartFile.fromPath('imageFile', imageFile.path));

    final response = await request.send();
    if (response.statusCode == 201) {
      // Success handling if needed
      if (kDebugMode) {
        print('Issue successfully submitted.');
      }
    } else {
      final errorMessage = await response.stream.bytesToString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $errorMessage')),
      );
      if (kDebugMode) {
        print('Failed to submit issue. Status code: ${response.statusCode}');
        print('Error message: $errorMessage');
      }
    }
  }
}

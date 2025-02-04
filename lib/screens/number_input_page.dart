// number_input_page.dart

// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ttp_app/constants.dart';
import 'package:ttp_app/widgets/drawer_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';

/// Model class for Machine
class Machine {
  final String number;
  final String salamandermachinepitch;
  final String? salamanderlineNumber; // Nullable
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
      salamanderlineNumber: json['salamanderline_number'], // Nullable
      productionworkplaceNumber: json['productionworkplace_number'] ?? '',
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
  final TextEditingController _numberController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Create a MobileScannerController instance.
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
  List<Machine> machines = []; // Changed to list of Machine objects
  List<String> materials = [];
  List<String> employees = [];
  bool isDataLoaded = false;

  // Define the mapping as a member variable
  Map<String, String> machinePitchToLineMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Optional: Clear SharedPreferences on app start for testing purposes
    // Uncomment the following line to enable cache clearing
    // _clearSharedPreferencesForTesting();

    _loadRecentItems();
    _preloadData();
  }

  /// Optional: Clears SharedPreferences for testing purposes
  // ignore: unused_element
  void _clearSharedPreferencesForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (kDebugMode) {
      print('SharedPreferences: Cleared all preferences for testing.');
    }
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

  /// Builds a mapping from machine number to corresponding salamanderline_number
  Map<String, String> _buildMachineToLineMap(
      List<String> lines, List<Machine> machines) {
    Map<String, String> map = {};
    for (var machine in machines) {
      String machineNumber = machine.number.trim().toUpperCase();
      String? lineNumber = machine.salamanderlineNumber?.trim().toUpperCase();

      // If salamanderline_number is null or empty and productionworkplace_number starts with 'S0', generate it
      if ((lineNumber == null || lineNumber.isEmpty) &&
          machine.productionworkplaceNumber.toUpperCase().startsWith('S0')) {
        lineNumber = 'TTP-${machine.productionworkplaceNumber.toUpperCase()}';
      }

      // Proceed only if lineNumber is not null or empty
      if (lineNumber != null && lineNumber.isNotEmpty) {
        // Ensure that the line exists in the lines list
        if (lines.map((e) => e.toUpperCase()).contains(lineNumber)) {
          map[machineNumber] = lineNumber;
          if (kDebugMode) {
            print('Mapping: $machineNumber -> $lineNumber');
          }
        } else {
          if (kDebugMode) {
            print(
                'No corresponding line found in lines list for line number: $lineNumber');
          }
        }
      } else {
        if (kDebugMode) {
          print(
              'No salamanderline_number and productionworkplace_number does not start with S0 for machine: $machineNumber');
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
    mobileScannerController.dispose();
    _numberController.dispose();
    scanTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // mobile_scanner handles lifecycle changes automatically,
    // but you can pause/resume if needed:
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      mobileScannerController.stop();
    } else if (state == AppLifecycleState.resumed) {
      mobileScannerController.start();
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
            // Replace the QRView with MobileScanner.
            if (!Platform.isWindows)
              SizedBox(
                height: MediaQuery.of(context).size.shortestSide * 0.4,
                child: MobileScanner(
                  controller: mobileScannerController,
                  onDetect: (BarcodeCapture barcodeCapture) {
                    // Only process if we haven't scanned yet and data is loaded.
                    if (!hasScanned && isDataLoaded) {
                      final Barcode barcode = barcodeCapture.barcodes.first;
                      if (barcode.rawValue != null) {
                        setState(() {
                          hasScanned = true;
                        });
                        Vibration.vibrate(duration: 50);
                        String scannedData = barcode.rawValue!;
                        if (kDebugMode) {
                          print('Scanned QR Code: $scannedData');
                        }
                        _processScannedData(scannedData);
                      }
                    }
                  },
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
    String? selectedMachineNumber;
    String? selectedMachinePitch;
    String? correspondingLine;

    // Find if the scanned code matches any tool using exact match
    for (var tool in tools) {
      String normalizedTool = tool.trim().toUpperCase();
      if (normalizedTool == normalizedScannedCode) {
        // Exact match
        selectedToolBreakdown = tool;
        if (kDebugMode) {
          print('Matched Tool: $tool');
        }
        break;
      }
    }

    // If not a tool, check if it's a machine using exact match
    if (selectedToolBreakdown == null) {
      for (var machine in machines) {
        String normalizedMachine = machine.number.trim().toUpperCase();
        if (normalizedMachine == normalizedScannedCode) {
          // Exact match
          selectedMachineNumber = machine.number;
          selectedMachinePitch = machine.salamandermachinepitch;
          if (kDebugMode) {
            print(
                'Matched Machine: Number=${machine.number}, Pitch=${machine.salamandermachinepitch}');
          }
          break;
        }
      }
    }

    // If a machine is found, find the corresponding line using the mapping
    if (selectedMachineNumber != null) {
      String machineCode = selectedMachineNumber.trim().toUpperCase();
      correspondingLine = machinePitchToLineMap[machineCode];
      if (correspondingLine == null && kDebugMode) {
        if (kDebugMode) {
          print('No corresponding line found for machine code: $machineCode');
        }
      } else if (kDebugMode) {
        print('Corresponding Line: $correspondingLine');
      }
    }

    if (kDebugMode) {
      print('Matched tool breakdown: $selectedToolBreakdown');
      print('Matched machine number: $selectedMachineNumber');
      print('Matched machine pitch: $selectedMachinePitch');
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
            selectedMachineNumber: selectedMachineNumber,
            selectedMachinePitch: selectedMachinePitch,
            correspondingLine: correspondingLine, // Pass the matching line
            areaCenters: areaCenters,
            lines: lines,
            tools: tools,
            machines: machines,
            materials: materials,
            employees: employees,
            machinePitchToLineMap: machinePitchToLineMap, // Pass mapping
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

  /// Processes scanned QR code data using your existing logic.
  void _processScannedData(String scannedData) {
    String fullUrl = scannedData;
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
      Uri.parse('http://wim-solution.sip.local:3006/salamanderareacenter'),
      headers: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (kDebugMode) {
        print('Fetched Area Centers: $data');
      }
      return data.map((e) => e['name'].toString()).toList();
    } else {
      throw Exception('Failed to fetch area centers');
    }
  }

  /// Fetches lines from the API
  Future<List<String>> _fetchLines() async {
    final response = await http.get(
      Uri.parse('http://wim-solution.sip.local:3006/salamanderline'),
      headers: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (kDebugMode) {
        print('Fetched Lines: $data');
      }
      return data.map((e) => e['number'].toString()).toList();
    } else {
      throw Exception('Failed to fetch lines');
    }
  }

  /// Fetches tools from the API
  Future<List<String>> _fetchTools() async {
    final response = await http.get(
      Uri.parse('http://wim-solution.sip.local:3006/projects'),
      headers: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (kDebugMode) {
        print('Fetched Tools: $data');
      }
      return data.map((e) => e['number'].toString()).toList();
    } else {
      throw Exception('Failed to fetch tools');
    }
  }

  /// Fetches machines from the API and parses them into Machine objects
  Future<List<Machine>> _fetchMachines() async {
    final response = await http.get(
      Uri.parse('http://wim-solution.sip.local:3006/machines'),
      headers: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      List<Machine> fetchedMachines =
          data.map((e) => Machine.fromJson(e)).toList();
      if (kDebugMode) {
        print('Fetched Machines:');
        for (var machine in fetchedMachines) {
          print(
              'Number: ${machine.number}, Pitch: ${machine.salamandermachinepitch}, Line: ${machine.salamanderlineNumber}');
        }
      }
      return fetchedMachines;
    } else {
      throw Exception('Failed to fetch machines');
    }
  }

  /// Fetches materials from the API
  Future<List<String>> _fetchMaterials() async {
    final response = await http.get(
      Uri.parse('http://wim-solution.sip.local:3006/material'),
      headers: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (kDebugMode) {
        print('Fetched Materials: $data');
      }
      return data.map((e) => e['name'].toString()).toList();
    } else {
      throw Exception('Failed to fetch materials');
    }
  }

  /// Fetches employees from the API
  Future<List<String>> _fetchEmployees() async {
    final response = await http.get(
      Uri.parse('http://wim-solution.sip.local:3006/employee'),
      headers: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (kDebugMode) {
        print('Fetched Employees: $data');
      }
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
  final String? selectedMachineNumber;
  final String? selectedMachinePitch;
  final String? correspondingLine; // New parameter
  final List<String> areaCenters;
  final List<String> lines;
  final List<String> tools;
  final List<Machine> machines;
  final List<String> materials;
  final List<String> employees;
  final Map<String, String> machinePitchToLineMap; // Added mapping

  const CreateIssueModal({
    super.key,
    required this.scannedCode,
    this.selectedToolBreakdown,
    this.selectedMachineNumber, // New parameter
    this.selectedMachinePitch, // New parameter
    this.correspondingLine, // Initialize the new parameter
    required this.areaCenters,
    required this.lines,
    required this.tools,
    required this.machines,
    required this.materials,
    required this.employees,
    required this.machinePitchToLineMap, // Require mapping
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
      if (kDebugMode) {
        print('CreateIssueModal: Set tool breakdown to $selectedToolBreakdown');
      }
    }
    if (widget.selectedMachineNumber != null &&
        widget.selectedMachineNumber!.isNotEmpty) {
      selectedMachineNumber = widget.selectedMachineNumber;
      machineController.text = selectedMachineNumber!;
      if (kDebugMode) {
        print('CreateIssueModal: Set machine number to $selectedMachineNumber');
      }
    }

    // Prefill the line field if a corresponding line is provided
    if (widget.correspondingLine != null &&
        widget.correspondingLine!.isNotEmpty) {
      selectedLine = widget.correspondingLine;
      lineController.text = selectedLine!;
      if (kDebugMode) {
        print('CreateIssueModal: Set line to $selectedLine');
      }
    }

    if (widget.selectedMachinePitch != null &&
        widget.selectedMachinePitch!.isNotEmpty) {
      selectedMachinePitch = widget.selectedMachinePitch;
      if (kDebugMode) {
        print('CreateIssueModal: Set machine pitch to $selectedMachinePitch');
      }
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
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
            TypeAheadField<String>(
              controller: employeeController,
              builder: (context, textController, focusNode) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Mitarbeiter auswählen',
                  ),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.employees
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(title: Text(suggestion));
              },
              onSelected: (suggestion) {
                employeeController.text = suggestion;
                selectedEmployee = suggestion;
                if (kDebugMode) {
                  print('CreateIssueModal: Selected employee: $suggestion');
                }
              },
            ),
            const SizedBox(height: 16),
            // Area Center selection
            TypeAheadField<String>(
              controller: areaCenterController,
              builder: (context, textController, focusNode) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Zuständige Stelle',
                  ),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.areaCenters
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(title: Text(suggestion));
              },
              onSelected: (suggestion) {
                areaCenterController.text = suggestion;
                selectedAreaCenter = suggestion;
                if (kDebugMode) {
                  print('CreateIssueModal: Selected area center: $suggestion');
                }
              },
            ),
            const SizedBox(height: 16),
            // Line selection
            TypeAheadField<String>(
              controller: lineController,
              builder: (context, textController, focusNode) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Linie oder Stellplatz',
                  ),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.lines
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(title: Text(suggestion));
              },
              onSelected: (suggestion) {
                lineController.text = suggestion;
                selectedLine = suggestion;
                if (kDebugMode) {
                  print('CreateIssueModal: Selected line: $suggestion');
                }
              },
            ),
            const SizedBox(height: 16),
            // Tool selection
            TypeAheadField<String>(
              controller: toolController,
              builder: (context, textController, focusNode) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Werkzeug',
                  ),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.tools
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(title: Text(suggestion));
              },
              onSelected: (suggestion) {
                toolController.text = suggestion;
                selectedToolBreakdown = suggestion;
                if (kDebugMode) {
                  print('CreateIssueModal: Selected tool: $suggestion');
                }
              },
            ),
            const SizedBox(height: 16),
            // Machine selection
            TypeAheadField<String>(
              controller: machineController,
              builder: (context, textController, focusNode) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Maschine / Anlage',
                  ),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.machines
                    .where((machine) => machine.number
                        .toLowerCase()
                        .contains(pattern.toLowerCase()))
                    .map((machine) => machine.number)
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(title: Text(suggestion));
              },
              onSelected: (suggestion) {
                machineController.text = suggestion;
                selectedMachineNumber = suggestion;
                // Find the machine object based on the selected number
                Machine? selectedMachine = widget.machines.firstWhere(
                  (machine) => machine.number == suggestion,
                  orElse: () => Machine(
                    number: '',
                    salamandermachinepitch: '',
                    salamanderlineNumber: null,
                    productionworkplaceNumber: '',
                  ),
                );
                String? machineCode;
                if (selectedMachine.salamanderlineNumber != null &&
                    selectedMachine.salamanderlineNumber!.isNotEmpty) {
                  machineCode = selectedMachine.salamanderlineNumber!
                      .trim()
                      .toUpperCase();
                } else if (selectedMachine.productionworkplaceNumber
                    .toUpperCase()
                    .startsWith('S0')) {
                  machineCode =
                      'TTP-${selectedMachine.productionworkplaceNumber.toUpperCase()}';
                }
                if (machineCode != null && machineCode.isNotEmpty) {
                  String? mappedLine =
                      widget.machinePitchToLineMap[machineCode];
                  if (mappedLine != null && mappedLine.isNotEmpty) {
                    setState(() {
                      selectedLine = mappedLine;
                      lineController.text = selectedLine!;
                    });
                    if (kDebugMode) {
                      print(
                          'CreateIssueModal: Mapped machine code $machineCode to line $mappedLine');
                    }
                  } else {
                    setState(() {
                      selectedLine = '';
                      lineController.text = '';
                    });
                    if (kDebugMode) {
                      print(
                          'No corresponding line found for machine code: $machineCode');
                    }
                  }
                } else {
                  // Handle cases where no valid machineCode is found
                  setState(() {
                    selectedLine = '';
                    lineController.text = '';
                  });
                  if (kDebugMode) {
                    print(
                        'salamanderline_number is null or productionworkplace_number does not start with S0 for machine: $suggestion');
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            // Material selection
            TypeAheadField<String>(
              controller: materialController,
              builder: (context, textController, focusNode) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Material',
                  ),
                );
              },
              suggestionsCallback: (pattern) async {
                return widget.materials
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(title: Text(suggestion));
              },
              onSelected: (suggestion) {
                materialController.text = suggestion;
                selectedMaterialBreakdown = suggestion;
                if (kDebugMode) {
                  print('CreateIssueModal: Selected material: $suggestion');
                }
              },
            ),
            const SizedBox(height: 16),
            // Work card comment (simple TextField)
            TextField(
              decoration: const InputDecoration(
                labelText: 'Fehlerbeschreibung',
              ),
              onChanged: (value) {
                workCardComment = value;
                if (kDebugMode) {
                  print('CreateIssueModal: Work card comment updated.');
                }
              },
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () async {
                final pickedImage = await _pickImage();
                if (pickedImage != null) {
                  setState(() {
                    imagePath = pickedImage.path;
                    if (kDebugMode) {
                      print('CreateIssueModal: Image selected at $imagePath');
                    }
                  });
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8.0),
                  Text(
                    'Bild auswählen\noder Foto aufnehmen',
                    textAlign: TextAlign.center,
                  ),
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
                  onPressed: () async {
                    if (imagePath != null) {
                      File imageFile = File(imagePath!);
                      bool isValid = await _isImageFileValid(imageFile);
                      if (!isValid) {
                        showOverlayMessage(
                            context, 'Das Bild ist ungültig oder beschädigt.');
                        return;
                      }
                    }
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
                      if (kDebugMode) {
                        print(
                            'CreateIssueModal: Issue submitted successfully.');
                      }
                    } else {
                      showOverlayMessage(context,
                          'Bitte alle erforderlichen Felder ausfüllen.');
                      if (kDebugMode) {
                        print('CreateIssueModal: Form validation failed.');
                      }
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

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
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

    if (source == null) return null;

    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) {
      if (kDebugMode) print('No image selected.');
      return null;
    }

    // Convert XFile to File
    File imageFile = File(pickedFile.path);

    // Ensure the picked file is valid
    final isValid = await _isImageFileValid(imageFile);
    if (!isValid) {
      if (kDebugMode) print('Image file is invalid or corrupted.');
      return null;
    }

    // Optional: Save a copy before sending
    final tempDir = await getTemporaryDirectory();
    final savedFilePath =
        path.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
    final savedFile = await imageFile.copy(savedFilePath);

    if (kDebugMode) print('Image saved locally at: $savedFilePath');
    return savedFile;
  }

  /// Validates if the image file is valid
  Future<bool> _isImageFileValid(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return bytes.isNotEmpty;
    } catch (e) {
      if (kDebugMode) print('Error reading image file: $e');
      return false;
    }
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

    // Determine MIME type based on file extension
    String mimeType = 'application/octet-stream'; // Default MIME type
    String extension = imageFile.path.split('.').last.toLowerCase();
    if (extension == 'jpg' || extension == 'jpeg') {
      mimeType = 'image/jpeg';
    } else if (extension == 'png') {
      mimeType = 'image/png';
    } else if (extension == 'gif') {
      mimeType = 'image/gif';
    }

    request.files.add(await http.MultipartFile.fromPath(
      'imageFile',
      imageFile.path,
      contentType: MediaType.parse(mimeType),
    ));

    try {
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
    } catch (e) {
      if (kDebugMode) {
        print('Exception during issue submission: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Senden des Störfalls: $e')),
      );
    }
  }
}

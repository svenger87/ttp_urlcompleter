// number_input_page.dart
// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
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
import 'package:http/io_client.dart' as http;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecentItems();
    // Removed _preloadData to prevent memory hogging
  }

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

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchProfileSuggestions(value);
    });
  }

  @override
  Widget build(BuildContext context) {
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
            // --- Autocomplete for profile suggestions ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  return _filterProfileSuggestions(
                      profileSuggestions, textEditingValue.text);
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
            // --- IKOffice links ---
            _buildLinkCard('PZE', ikOfficePZE),
            _buildLinkCard('Linienkonfiguration', ikOfficeLineConfig),
          ],
        ),
      ),
    );
  }

  // Function to filter profile suggestions
  List<String> _filterProfileSuggestions(
      List<String> suggestions, String query) {
    if (query.isEmpty) {
      return [];
    }
    final lowerQuery = query.toLowerCase();
    return suggestions
        .where((suggestion) => suggestion.toLowerCase().contains(lowerQuery))
        .toList();
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

  void _reportIssue(String scannedCode) {
    if (kDebugMode) {
      print('Reporting issue for scanned code: $scannedCode');
    }

    String normalizedScannedCode = scannedCode.trim().toLowerCase();

    String? selectedToolBreakdown;
    String? selectedMachineBreakdown;

    // No preloaded data, so these variables are handled within the modal

    // Use showModalBottomSheet instead of showDialog
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
            fetchAreaCenters: _fetchAreaCenters,
            fetchLines: _fetchLines,
            fetchTools: _fetchTools,
            fetchMachines: _fetchMachines,
            fetchMaterials: _fetchMaterials,
            fetchEmployees: _fetchEmployees,
          ),
        );
      },
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (!hasScanned) {
        setState(() {
          hasScanned = true;
        });

        Vibration.vibrate(duration: 50);

        final scannedData = scanData.code!;
        if (kDebugMode) {
          print('Scanned QR Code: $scannedData');
        }

        String fullUrl = scannedData;

        String codeToUse;
        try {
          Uri uri = Uri.parse(scannedData);
          codeToUse =
              uri.pathSegments.isNotEmpty ? uri.pathSegments.last : scannedData;
        } catch (e) {
          codeToUse = scannedData;
        }

        if (kDebugMode) {
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
                title: const Text('Werkzeugdetails öffnen'),
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

  void _navigateToUrl(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewModule(url: url),
      ),
    );
  }

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
      }
    }
  }

  void _addRecentItem(String item) async {
    final Uri uri = Uri.parse(item);
    final String profileNumber = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : item; // Handle cases where pathSegments might be empty

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

  Future<void> _saveRecentItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentItems', recentItems);
  }

  void _clearRecentItems() {
    setState(() {
      recentItems.clear();
    });
    _saveRecentItems();
  }

  // ----------------------------------
  // Fetch Functions for On-Demand Data
  // ----------------------------------

  Future<List<String>> _fetchAreaCenters() async {
    try {
      final response = await http.get(
          Uri.parse('http://wim-solution.sip.local:3006/salamanderareacenter'),
          headers: {
            'accept': 'application/json',
            'X-Api-Key': apiKey,
          });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['name'].toString()).toList();
      } else {
        if (kDebugMode) {
          print(
              'Error fetching area centers. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching area centers: $e');
      }
      return [];
    }
  }

  Future<List<String>> _fetchLines() async {
    try {
      final response = await http.get(
          Uri.parse('http://wim-solution.sip.local:3006/salamanderline'),
          headers: {
            'accept': 'application/json',
            'X-Api-Key': apiKey,
          });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['number'].toString()).toList();
      } else {
        if (kDebugMode) {
          print('Error fetching lines. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching lines: $e');
      }
      return [];
    }
  }

  Future<List<String>> _fetchTools() async {
    try {
      final response = await http.get(
          Uri.parse('http://wim-solution.sip.local:3006/projects'),
          headers: {
            'accept': 'application/json',
            'X-Api-Key': apiKey,
          });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['number'].toString()).toList();
      } else {
        if (kDebugMode) {
          print('Error fetching tools. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching tools: $e');
      }
      return [];
    }
  }

  Future<List<String>> _fetchMachines() async {
    try {
      final response = await http.get(
          Uri.parse('http://wim-solution.sip.local:3006/machines'),
          headers: {
            'accept': 'application/json',
            'X-Api-Key': apiKey,
          });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['number'].toString()).toList();
      } else {
        if (kDebugMode) {
          print('Error fetching machines. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching machines: $e');
      }
      return [];
    }
  }

  Future<List<String>> _fetchMaterials() async {
    try {
      final response = await http.get(
          Uri.parse('http://wim-solution.sip.local:3006/material'),
          headers: {
            'accept': 'application/json',
            'X-Api-Key': apiKey,
          });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['name'].toString()).toList();
      } else {
        if (kDebugMode) {
          print(
              'Error fetching materials. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching materials: $e');
      }
      return [];
    }
  }

  Future<List<String>> _fetchEmployees() async {
    try {
      final response = await http.get(
          Uri.parse('http://wim-solution.sip.local:3006/employee'),
          headers: {
            'accept': 'application/json',
            'X-Api-Key': apiKey,
          });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map<String>((e) =>
                '${e['employeenumber']} - ${e['firstname']} ${e['lastname']}')
            .toList();
      } else {
        if (kDebugMode) {
          print(
              'Error fetching employees. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching employees: $e');
      }
      return [];
    }
  }

  // ----------------------------------
  // Profile Suggestions API
  // ----------------------------------

  List<String> profileSuggestions = [];

  Future<void> _fetchProfileSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        profileSuggestions = [];
      });
      return;
    }

    try {
      final httpClient = http.IOClient(
          HttpClient()..badCertificateCallback = ((_, __, ___) => true));
      final response = await httpClient.get(
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

      httpClient.close();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching profile suggestions: $e');
      }
    }
  }
}

// -----------------------------------------------------------------
// Modal for Creating an Issue (with TypeAheadFields for new API 5.x)
// -----------------------------------------------------------------
class CreateIssueModal extends StatefulWidget {
  final String scannedCode;
  final String? selectedToolBreakdown;
  final String? selectedMachineBreakdown;
  final Future<List<String>> Function() fetchAreaCenters;
  final Future<List<String>> Function() fetchLines;
  final Future<List<String>> Function() fetchTools;
  final Future<List<String>> Function() fetchMachines;
  final Future<List<String>> Function() fetchMaterials;
  final Future<List<String>> Function() fetchEmployees;

  const CreateIssueModal({
    super.key,
    required this.scannedCode,
    this.selectedToolBreakdown,
    this.selectedMachineBreakdown,
    required this.fetchAreaCenters,
    required this.fetchLines,
    required this.fetchTools,
    required this.fetchMachines,
    required this.fetchMaterials,
    required this.fetchEmployees,
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

  // Controllers
  final TextEditingController employeeController = TextEditingController();
  final TextEditingController areaCenterController = TextEditingController();
  final TextEditingController lineController = TextEditingController();
  final TextEditingController toolController = TextEditingController();
  final TextEditingController machineController = TextEditingController();
  final TextEditingController materialController = TextEditingController();

  // Fetched data lists
  List<String> areaCenters = [];
  List<String> lines = [];
  List<String> tools = [];
  List<String> machines = [];
  List<String> materials = [];
  List<String> employees = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // Pre-fill tool / machine if provided
    if (widget.selectedToolBreakdown?.isNotEmpty ?? false) {
      selectedToolBreakdown = widget.selectedToolBreakdown;
      toolController.text = selectedToolBreakdown!;
    }
    if (widget.selectedMachineBreakdown?.isNotEmpty ?? false) {
      selectedMachineBreakdown = widget.selectedMachineBreakdown;
      machineController.text = selectedMachineBreakdown!;
    }

    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    try {
      final results = await Future.wait([
        widget.fetchAreaCenters(),
        widget.fetchLines(),
        widget.fetchTools(),
        widget.fetchMachines(),
        widget.fetchMaterials(),
        widget.fetchEmployees(),
      ]);

      setState(() {
        areaCenters = results[0];
        lines = results[1];
        tools = results[2];
        machines = results[3];
        materials = results[4];
        employees = results[5];
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching data in modal: $e');
      }
      setState(() {
        isLoading = false;
      });
      // Optionally, show an error message to the user
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
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Störfall anlegen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Checkbox for operable
            Row(
              children: [
                Checkbox(
                  value: operable,
                  onChanged: (value) =>
                      setState(() => operable = value ?? true),
                ),
                const Text('Betrieb möglich?'),
              ],
            ),

            // (1) Employee
            _buildTypeAheadField(
              labelText: 'Mitarbeiter auswählen',
              controller: employeeController,
              fetchSuggestions: _fetchEmployeeSuggestions,
              onItemSelected: (val) {
                selectedEmployee = val;
              },
            ),
            const SizedBox(height: 8),

            // (2) Area Center
            _buildTypeAheadField(
              labelText: 'Zuständige Stelle',
              controller: areaCenterController,
              fetchSuggestions: _fetchAreaCenterSuggestions,
              onItemSelected: (val) {
                selectedAreaCenter = val;
              },
            ),
            const SizedBox(height: 8),

            // (3) Line
            _buildTypeAheadField(
              labelText: 'Linie',
              controller: lineController,
              fetchSuggestions: _fetchLineSuggestions,
              onItemSelected: (val) {
                selectedLine = val;
              },
            ),
            const SizedBox(height: 8),

            // (4) Tool
            _buildTypeAheadField(
              labelText: 'Werkzeug',
              controller: toolController,
              fetchSuggestions: _fetchToolSuggestions,
              onItemSelected: (val) {
                selectedToolBreakdown = val;
              },
            ),
            const SizedBox(height: 8),

            // (5) Machine
            _buildTypeAheadField(
              labelText: 'Maschine / Anlage',
              controller: machineController,
              fetchSuggestions: _fetchMachineSuggestions,
              onItemSelected: (val) {
                selectedMachineBreakdown = val;
              },
            ),
            const SizedBox(height: 8),

            // (6) Material
            _buildTypeAheadField(
              labelText: 'Material',
              controller: materialController,
              fetchSuggestions: _fetchMaterialSuggestions,
              onItemSelected: (val) {
                selectedMaterialBreakdown = val;
              },
            ),

            const SizedBox(height: 8),

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

            // Pick image
            ElevatedButton(
              onPressed: () async {
                final pickedImage = await _pickImage();
                if (pickedImage != null) {
                  setState(() => imagePath = pickedImage.path);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt),
                  const SizedBox(width: 8.0),
                  const Text(
                    'Bild auswählen\noder Foto aufnehmen',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            if (imagePath != null) Text('Ausgewählt: $imagePath'),
            const SizedBox(height: 16.0),

            // Action buttons
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
                        'imagePath': imagePath!,
                      });
                      Navigator.pop(context);
                      showOverlayMessage(context, 'Störfall angelegt!');
                    } else {
                      showOverlayMessage(
                        context,
                        'Bitte alle erforderlichen Felder ausfüllen.',
                      );
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

  /// A helper to build a TypeAheadField with the new flutter_typeahead 5.x API
  Widget _buildTypeAheadField({
    required String labelText,
    required TextEditingController controller,
    required Future<List<String>> Function(String) fetchSuggestions,
    required ValueChanged<String> onItemSelected,
  }) {
    return TypeAheadField<String>(
      // Replaces old 'onSuggestionSelected'
      onSelected: (String suggestion) {
        controller.text = suggestion;
        onItemSelected(suggestion);
      },

      // Called each time the user types:
      suggestionsCallback: (pattern) async {
        if (pattern.trim().isEmpty) return [];
        return await fetchSuggestions(pattern);
      },

      // How each item is built in the dropdown
      itemBuilder: (context, String suggestion) {
        return ListTile(title: Text(suggestion));
      },

      // Build the TextField itself (old 'TextFieldConfiguration' is removed)
      builder: (context, textEditingController, focusNode) {
        // Keep the local textEditingController in sync with the main controller
        textEditingController.text = controller.text;
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: labelText,
          ),
          onChanged: (val) {
            controller.text = val;
          },
        );
      },

      // If you want a custom 'no items' UI, or loading UI:
      emptyBuilder: (context) => const ListTile(
        title: Text('Keine Treffer'),
      ),
      loadingBuilder: (context) => const ListTile(
        title: Text('Lade...'),
      ),

      // If you want the suggestions box to appear in-line (so it’s tappable in a BottomSheet)
      // just use a simple transitionBuilder returning suggestionsBox:
      transitionBuilder: (context, suggestionsBox, animationController) {
        return suggestionsBox as Widget;
      },
      // Additional flags
      hideOnEmpty: false,
      hideOnLoading: false,
      hideOnSelect: true, // Hide the box after the user selects something
      retainOnLoading: true,
      hideWithKeyboard: false,
    );
  }

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

    // Remove the entry after a delay (3 seconds, e.g.)
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

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

  void _submitIssue(Map<String, String> issueData) async {
    final uri = Uri.parse('http://wim-solution.sip.local:3006/report-issue');
    final request = http.MultipartRequest('POST', uri);

    issueData.forEach((key, value) {
      if (key != 'imagePath') {
        request.fields[key] = value;
      }
    });

    final imageFile = File(issueData['imagePath']!);
    request.files
        .add(await http.MultipartFile.fromPath('imageFile', imageFile.path));

    final response = await request.send();
    if (response.statusCode == 201) {
      // Successfully created
      // Optionally show a SnackBar or toast in the calling code
    } else {
      final errorMessage = await response.stream.bytesToString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $errorMessage')),
      );
    }
  }

  // ----------------------------------
  // Fetch Suggestions Functions for TypeAhead Fields
  // ----------------------------------

  Future<List<String>> _fetchEmployeeSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse('http://wim-solution.sip.local:3006/employee?search=$query'),
        headers: {
          'accept': 'application/json',
          'X-Api-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map<String>((e) =>
                '${e['employeenumber']} - ${e['firstname']} ${e['lastname']}')
            .toList();
      } else {
        if (kDebugMode) {
          print(
              'Error fetching employee suggestions. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching employee suggestions: $e');
      }
      return [];
    }
  }

  Future<List<String>> _fetchAreaCenterSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://wim-solution.sip.local:3006/salamanderareacenter?search=$query'),
        headers: {
          'accept': 'application/json',
          'X-Api-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['name'].toString()).toList();
      } else {
        if (kDebugMode) {
          print(
              'Error fetching area center suggestions. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching area center suggestions: $e');
      }
      return [];
    }
  }

  Future<List<String>> _fetchLineSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://wim-solution.sip.local:3006/salamanderline?search=$query'),
        headers: {
          'accept': 'application/json',
          'X-Api-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['number'].toString()).toList();
      } else {
        if (kDebugMode) {
          print(
              'Error fetching line suggestions. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching line suggestions: $e');
      }
      return [];
    }
  }

  Future<List<String>> _fetchToolSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse('http://wim-solution.sip.local:3006/projects?search=$query'),
        headers: {
          'accept': 'application/json',
          'X-Api-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['number'].toString()).toList();
      } else {
        if (kDebugMode) {
          print(
              'Error fetching tool suggestions. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching tool suggestions: $e');
      }
      return [];
    }
  }

  Future<List<String>> _fetchMachineSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse('http://wim-solution.sip.local:3006/machines?search=$query'),
        headers: {
          'accept': 'application/json',
          'X-Api-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['number'].toString()).toList();
      } else {
        if (kDebugMode) {
          print(
              'Error fetching machine suggestions. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching machine suggestions: $e');
      }
      return [];
    }
  }

  Future<List<String>> _fetchMaterialSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse('http://wim-solution.sip.local:3006/material?search=$query'),
        headers: {
          'accept': 'application/json',
          'X-Api-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['name'].toString()).toList();
      } else {
        if (kDebugMode) {
          print(
              'Error fetching material suggestions. Status code: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching material suggestions: $e');
      }
      return [];
    }
  }
}

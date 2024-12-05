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
import 'package:flutter_typeahead/flutter_typeahead.dart';

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
  List<String> machines = [];
  List<String> employees = [];
  bool isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecentItems();
    _preloadData();
  }

  void _preloadData() async {
    try {
      final results = await Future.wait([
        _fetchAreaCenters(),
        _fetchLines(),
        _fetchTools(),
        _fetchMachines(),
        _fetchEmployees(),
      ]);

      setState(() {
        areaCenters = results[0];
        lines = results[1];
        tools = results[2];
        machines = results[3];
        employees = results[4];
        isDataLoaded = true; // Ensure this is set after data is loaded
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading data: $e');
      }
    }
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
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchProfileSuggestions(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isDataLoaded) {
      // Show loading indicator
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
          color: Colors.white, // Set the text color to white
          fontSize: 20, // Optionally adjust the font size
          fontWeight: FontWeight.bold, // Optionally adjust the font weight
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
                      .where((String suggestion) =>
                          suggestion
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()) &&
                          RegExp(r"^[a-zA-Z0-9]").hasMatch(suggestion))
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
      print('Tools list loaded with ${tools.length} items');
      print('Machines list loaded with ${machines.length} items');
    }

    // Normalize scannedCode
    String normalizedScannedCode = scannedCode.trim().toLowerCase();

    // Match scanned code with tools and machines
    String? selectedToolBreakdown;
    String? selectedMachineBreakdown;

    List<String> normalizedTools =
        tools.map((e) => e.trim().toLowerCase()).toList();
    List<String> normalizedMachines =
        machines.map((e) => e.trim().toLowerCase()).toList();

    if (normalizedTools.contains(normalizedScannedCode)) {
      int index = normalizedTools.indexOf(normalizedScannedCode);
      selectedToolBreakdown = tools[index];
    } else if (normalizedMachines.contains(normalizedScannedCode)) {
      int index = normalizedMachines.indexOf(normalizedScannedCode);
      selectedMachineBreakdown = machines[index];
    }

    if (kDebugMode) {
      print('Matched tool breakdown: $selectedToolBreakdown');
      print('Matched machine breakdown: $selectedMachineBreakdown');
    }

    // Show the modal and pass the selected values and data
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreateIssueModal(
          scannedCode: scannedCode,
          selectedToolBreakdown: selectedToolBreakdown,
          selectedMachineBreakdown: selectedMachineBreakdown,
          areaCenters: areaCenters,
          lines: lines,
          tools: tools,
          machines: machines,
          employees: employees,
        );
      },
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) async {
      if (!hasScanned && isDataLoaded) {
        setState(() {
          hasScanned = true;
        });

        Vibration.vibrate(duration: 50);

        final scannedData = scanData.code!;
        if (kDebugMode) {
          print('Scanned QR Code: $scannedData');
        }

        // Keep the full scanned URL
        String fullUrl = scannedData;

        // Extract the code from the URL for matching
        String codeToUse;
        try {
          Uri uri = Uri.parse(scannedData);
          codeToUse =
              uri.pathSegments.isNotEmpty ? uri.pathSegments.last : scannedData;
        } catch (e) {
          // If it's not a valid URL, use the scanned data as is
          codeToUse = scannedData;
        }

        if (kDebugMode) {
          print('Extracted code: $codeToUse');
        }

        // Show the modal
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
                  Navigator.pop(context); // Close the modal
                  _navigateToUrl(fullUrl); // Navigate to the full URL
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_alert),
                title: const Text('Störfall anlegen'),
                onTap: () {
                  Navigator.pop(context); // Close the modal
                  _reportIssue(codeToUse); // Use the extracted code
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

  Future<List<String>> _fetchTools() async {
    final response = await http
        .get(Uri.parse('http://wim-solution.sip.local:3006/projects'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      // Assuming the data includes 'number' field
      return data.map((e) => e['number'].toString()).toList();
    } else {
      throw Exception('Failed to fetch tools');
    }
  }

  Future<List<String>> _fetchMachines() async {
    final response = await http
        .get(Uri.parse('http://wim-solution.sip.local:3006/machines'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      // Assuming the data includes 'number' field
      return data.map((e) => e['number'].toString()).toList();
    } else {
      throw Exception('Failed to fetch machines');
    }
  }

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

  Future<void> _fetchProfileSuggestions(String query) async {
    // Implementation of profile suggestions fetching
    // You can fill this method as per your requirements
  }
}

class CreateIssueModal extends StatefulWidget {
  final String scannedCode;
  final String? selectedToolBreakdown;
  final String? selectedMachineBreakdown;
  final List<String> areaCenters;
  final List<String> lines;
  final List<String> tools;
  final List<String> machines;
  final List<String> employees;

  const CreateIssueModal({
    super.key,
    required this.scannedCode,
    this.selectedToolBreakdown,
    this.selectedMachineBreakdown,
    required this.areaCenters,
    required this.lines,
    required this.tools,
    required this.machines,
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
  String? selectedEmployee;
  String? workCardComment;
  String? imagePath;

  // Controllers for typeahead fields
  final TextEditingController employeeController = TextEditingController();
  final TextEditingController areaCenterController = TextEditingController();
  final TextEditingController lineController = TextEditingController();
  final TextEditingController toolController = TextEditingController();
  final TextEditingController machineController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Set initial values based on matched scanned code
    if (widget.selectedToolBreakdown != null) {
      selectedToolBreakdown = widget.selectedToolBreakdown;
      toolController.text = selectedToolBreakdown!;
    }
    if (widget.selectedMachineBreakdown != null) {
      selectedMachineBreakdown = widget.selectedMachineBreakdown;
      machineController.text = selectedMachineBreakdown!;
    }
  }

  @override
  void dispose() {
    employeeController.dispose();
    areaCenterController.dispose();
    lineController.dispose();
    toolController.dispose();
    machineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Störfall anlegen',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          children: [
            // Operable Checkbox
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
                const Text('Operable'),
              ],
            ),

            // Employee Selection
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: employeeController,
                decoration: const InputDecoration(
                  labelText: 'Select Employee',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.employees
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion),
                );
              },
              onSuggestionSelected: (suggestion) {
                employeeController.text = suggestion;
                selectedEmployee = suggestion;
              },
              validator: (value) =>
                  value!.isEmpty ? 'Please select an employee' : null,
              // Removed initialValue
            ),

            // Area Center TypeAhead
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: areaCenterController,
                decoration: const InputDecoration(
                  labelText: 'Select Area Center',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.areaCenters
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion),
                );
              },
              onSuggestionSelected: (suggestion) {
                areaCenterController.text = suggestion;
                selectedAreaCenter = suggestion;
              },
              validator: (value) =>
                  value!.isEmpty ? 'Please select an area center' : null,
              // Removed initialValue
            ),

            // Line TypeAhead
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: lineController,
                decoration: const InputDecoration(
                  labelText: 'Select Line',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.lines
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion),
                );
              },
              onSuggestionSelected: (suggestion) {
                lineController.text = suggestion;
                selectedLine = suggestion;
              },
              validator: (value) =>
                  value!.isEmpty ? 'Please select a line' : null,
              // Removed initialValue
            ),

            // Tool Breakdown TypeAhead
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: toolController,
                decoration: const InputDecoration(
                  labelText: 'Select Tool Breakdown',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.tools
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion),
                );
              },
              onSuggestionSelected: (suggestion) {
                toolController.text = suggestion;
                selectedToolBreakdown = suggestion;
              },
              // Removed initialValue
            ),

            // Machine Breakdown TypeAhead
            TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: machineController,
                decoration: const InputDecoration(
                  labelText: 'Select Machine Breakdown',
                ),
              ),
              suggestionsCallback: (pattern) {
                return widget.machines
                    .where(
                        (e) => e.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion),
                );
              },
              onSuggestionSelected: (suggestion) {
                machineController.text = suggestion;
                selectedMachineBreakdown = suggestion;
              },
              // Removed initialValue
            ),

            // Work Card Comment Text Field
            TextField(
              decoration: const InputDecoration(
                labelText: 'Work Card Comment',
              ),
              onChanged: (value) {
                workCardComment = value;
              },
            ),

            // Image Picker Button
            ElevatedButton(
              onPressed: () async {
                final pickedImage = await _pickImage();
                if (pickedImage != null) {
                  setState(() {
                    imagePath = pickedImage.path;
                  });
                }
              },
              child: const Text('Select or Capture Image'),
            ),
            if (imagePath != null) Text('Selected: $imagePath'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_validateForm(
              operable: operable,
              areaCenter: selectedAreaCenter,
              line: selectedLine,
              employee: selectedEmployee,
              toolBreakdown: toolController.text,
              machineBreakdown: machineController.text,
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
                'workCardComment': workCardComment!,
                'imagePath': imagePath!,
              });
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please fill in all required fields.'),
                ),
              );
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Future<File?> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.camera); // or .gallery
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
    required String? workCardComment,
    required String? imagePath,
  }) {
    bool hasBreakdown = (toolBreakdown != null && toolBreakdown.isNotEmpty) ||
        (machineBreakdown != null && machineBreakdown.isNotEmpty);

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

    // Add text fields
    issueData.forEach((key, value) {
      if (key != 'imagePath') {
        request.fields[key] = value;
      }
    });

    // Add the image file
    final imageFile = File(issueData['imagePath']!);
    request.files
        .add(await http.MultipartFile.fromPath('imageFile', imageFile.path));

    final response = await request.send();
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue submitted successfully!')),
      );
    } else {
      final errorMessage = await response.stream.bytesToString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit the issue: $errorMessage')),
      );
    }
  }
}

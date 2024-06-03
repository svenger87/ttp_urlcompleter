// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'converter_module.dart';
import 'webview_module.dart';
import 'webviewwindows_module.dart';
import 'dart:convert';
import 'package:http/io_client.dart' as http;
import 'package:webdav_client/webdav_client.dart' as webdav;

void main() {
  runApp(const MyApp());
}

//URLs
const String ikOfficeLineConfig =
    'http://ikoffice.sip.local:8080/ikoffice/root/projektverwaltung/linienkonfiguration';
const String ikOfficePZE = 'http://ikoffice.sip.local:8080/ikoffice/root/';
const String prodPlan1w =
    'http://lurchiweb.sip.local/schedule/ZPPLAN.pdf#view=FitH';
const String prodPlan3w =
    'http://lurchiweb.sip.local/schedule/ZPPLAN_3W.pdf#view=FitH';
const String prodPlan1wNextcloud =
    'https://wim-solution.sip.local:8443/s/iBbZrtda7BTT7Qp';
const String prodPlan3wNextcloud =
    'https://wim-solution.sip.local:8443/s/EWxYDYmtKJQ2mfm';
const String bookstack = 'http://bookstack.sip.local';
const String intranet = 'http://lurchiweb.sip.local';
const String ac = 'https://olymp.sip.de';
const String wim = 'https://wim-solution.sip.local:8081';
//const String picklist = 'https://wim-solution.sip.local:8443/s/mYYc2cJyWG795BM';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ttp App',
      theme: ThemeData(
        primaryColor: const Color(0xFF104382),
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF104382),
      ),
      themeMode: ThemeMode.system,
      home: const NumberInputPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class NumberInputPage extends StatefulWidget {
  const NumberInputPage({Key? key}) : super(key: key);

  @override
  _NumberInputPageState createState() => _NumberInputPageState();
}

class _NumberInputPageState extends State<NumberInputPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final TextEditingController _numberController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  QRViewController? controller;
  bool hasScanned = false;
  Timer? scanTimer;

  // Shlink API endpoint
  static const apiUrl =
      'https://wim-solution.sip.local:8081/rest/v2/short-urls?itemsPerPage=10000';

  // API key for authorization
  static const apiKey = 'b2380a66-c965-4177-8bbf-6ecf03fbaa32';

  List<String> recentItems = [];
  List<String> profileSuggestions = [];

  @override
  void initState() {
    super.initState();
    _loadRecentItems();
  }

  void _loadRecentItems() async {
    final prefs = await SharedPreferences.getInstance();
    final savedItems = prefs.getStringList('recentItems') ?? [];
    setState(() {
      recentItems = savedItems;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    _numberController.dispose();
    scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var scaffold = Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/leuchtturm.png',
              height: 36,
              width: 36,
            ),
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
      ),
      drawer: _buildDrawer(context),
      endDrawer: _buildRecentItemsDrawer(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (!Platform
                .isWindows) // Conditionally show QR scanner if not on Windows
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
                    onChanged: (String value) async {
                      await _fetchProfileSuggestions(value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Profilnummer eingeben',
                      hintText: 'Geben Sie eine Profilnummer ein',
                    ),
                  );
                },
              ),
            ),
            // Link 1: PZE
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    const url = ikOfficePZE;
                    if (Platform.isWindows) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WebViewWindowsModule(
                            initialUrl: url,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WebViewModule(url: url),
                        ),
                      );
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/IKOffice.ico',
                        width: 72,
                        height: 72,
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PZE'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Link 2 Linienkonfiguration
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    const url = ikOfficeLineConfig;
                    if (Platform.isWindows) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WebViewWindowsModule(
                            initialUrl: url,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WebViewModule(url: url),
                        ),
                      );
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/IKOffice.ico',
                        width: 72,
                        height: 72,
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Linienkonfiguration'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return scaffold;
  }

  Future<void> _fetchProfileSuggestions(String query) async {
    try {
      // Bypass SSL certificate validation (unsafe)
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
          // Combine user's entered value with suggestions
          final userEnteredValue = query.trim();
          profileSuggestions = [
            userEnteredValue,
            ...data
                .map<String>((item) => item['title']?.toString() ?? '')
                .where((suggestion) => suggestion.isNotEmpty)
                .toList(),
          ];
        });
      } else {
        // Handle non-200 status codes (e.g., API is offline)
        if (kDebugMode) {
          print('Error: ${response.statusCode}');
        }
        // Provide a fallback or default behavior here
      }

      httpClient.close(); // Close the client to release resources
    } catch (e) {
      // Handle network or other errors
      if (kDebugMode) {
        print('Error: $e');
      }
      // Provide a fallback or default behavior here
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) async {
      if (!hasScanned) {
        setState(() {
          hasScanned = true;
        });

        Vibration.vibrate(duration: 50);

        final scannedUrl = scanData.code!;
        if (Platform.isWindows) {
          _openUrl(scannedUrl);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewModule(url: scannedUrl),
            ),
          );
          _addRecentItem(scannedUrl);
        }

        scanTimer = Timer(const Duration(seconds: 10), () {
          setState(() {
            hasScanned = false;
          });
        });
      }
    });
  }

  void _openUrlWithNumber() async {
    final String number = _numberController.text.trim().toUpperCase();
    final BuildContext currentContext = context;

    if (number.isNotEmpty) {
      final url = '$wim/$number';

      if (await canLaunch(url)) {
        if (Platform.isWindows) {
          Navigator.push(
            currentContext, // Use the locally stored BuildContext
            MaterialPageRoute(
              builder: (context) => WebViewWindowsModule(initialUrl: url),
            ),
          );
        } else {
          Navigator.push(
            currentContext, // Use the locally stored BuildContext
            MaterialPageRoute(
              builder: (context) => WebViewModule(url: url),
            ),
          );
          _addRecentItem(url);
        }
      } else {
        if (kDebugMode) {
          print('Could not launch $url');
        }
      }
    }
  }

  void _addRecentItem(String item) {
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

    _saveRecentItems();
  }

  void _saveRecentItems() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('recentItems', recentItems);
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 0.0),
                      child: Image.asset(
                        'assets/leuchtturm.png',
                        width: 36,
                        height: 36,
                      ),
                    ),
                    const Text(
                      'Tools & Links',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 35),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final Uri emailUri = Uri(
                          scheme: 'mailto',
                          path: 'it-support@ttp-papenburg.de',
                        );

                        if (await canLaunch(emailUri.toString())) {
                          await launch(emailUri.toString());
                        } else {
                          // Handle error, if any
                          if (kDebugMode) {
                            print('Could not launch email client');
                          }
                        }
                      },
                      child: const Text(
                        '  it-support@ttp-papenburg.de',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ExpansionTile(
            leading:
                Image.asset('assets/productionplan.png', width: 36, height: 36),
            title: const Text('Produktionspläne'),
            children: [
              ListTile(
                leading: Image.asset(
                  'assets/productionplan.png',
                  width: 36,
                  height: 36,
                ),
                title: const Text('Produktionsplan 1W'),
                onTap: () {
                  if (Platform.isAndroid) {
                    _openUrl(prodPlan1wNextcloud);
                  } else if (Platform.isWindows) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WebViewWindowsModule(
                          initialUrl: prodPlan1w,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WebViewModule(
                          url: prodPlan1w,
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Image.asset(
                  'assets/productionplan.png',
                  width: 36,
                  height: 36,
                ),
                title: const Text('Produktionsplan 3W'),
                onTap: () {
                  if (Platform.isAndroid) {
                    _openUrl(prodPlan3wNextcloud);
                  } else if (Platform.isWindows) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WebViewWindowsModule(
                          initialUrl: prodPlan3w,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WebViewModule(
                          url: prodPlan3w,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          ListTile(
            leading: Image.asset('assets/leuchtturm_blue.png',
                width: 36, height: 36),
            title: const Text('Intranet'),
            onTap: () {
              if (Platform.isWindows) {
                // Use the Windows module
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const WebViewWindowsModule(initialUrl: intranet),
                  ),
                );
              } else {
                // Use the existing WebViewModule for other platforms
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebViewModule(
                      url: intranet,
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Image.asset('assets/ac.png', width: 36, height: 36),
            title: const Text('ActiveCollab'),
            onTap: () {
              if (Platform.isWindows) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebViewWindowsModule(
                      initialUrl: ac,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebViewModule(
                      url: ac,
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Image.asset('assets/bookstack.png', width: 36, height: 36),
            title: const Text('ttpedia'),
            onTap: () {
              if (Platform.isWindows) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebViewWindowsModule(
                      initialUrl: bookstack,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebViewModule(
                      url: bookstack,
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.checklist_rounded),
            title: const Text('Picklisten'),
            onTap: () async {
              const url = 'https://wim-solution.sip.local:8443/public.php';
              const user = 'mYYc2cJyWG795BM';
              const pwd = '';
              const dirPath = '/';

              final client = webdav.newClient(
                url,
                user: user,
                password: pwd,
                debug: true,
              );

              try {
                final list = await client.readDir(dirPath);
                if (kDebugMode) {
                  print(list);
                }
                // Process the list as needed
              } catch (e) {
                if (kDebugMode) {
                  print('Error: $e');
                }
                // Handle error
              }
            },
          ),
          const ExpansionTile(
            leading: Icon(Icons.handyman),
            title: Text('Tools'),
            children: [
              ConverterModule(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItemsDrawer(BuildContext context) {
    return Drawer(
      elevation: 16.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Text(
              'Zuletzt benutzt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: recentItems.length + 1,
              itemBuilder: (context, index) {
                if (index < recentItems.length) {
                  final recentUrl = '$wim/${recentItems[index]}';
                  return ListTile(
                    title: Text(recentItems[index]),
                    onTap: () {
                      if (Platform.isWindows) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                WebViewWindowsModule(initialUrl: recentUrl),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WebViewModule(url: recentUrl),
                          ),
                        );
                      }
                      // Navigator.pop(context); // Remove this line or adjust its placement based on your navigation requirements.
                    },
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextButton(
                      onPressed: () {
                        _clearRecentItems();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        primary: Theme.of(context).primaryColor,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8.0),
                          Text('Zuletzt benutzte löschen',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _clearRecentItems() {
    setState(() {
      recentItems.clear();
    });
    _saveRecentItems();
  }

  void _openUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        enableJavaScript: true,
        forceWebView: true,
      );
    } else {
      if (kDebugMode) {
        print('Could not launch $url');
      }
    }
  }
}

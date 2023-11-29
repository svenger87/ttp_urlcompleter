// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

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

void main() {
  runApp(const MyApp());
}

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

  List<String> recentItems = [];

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
    return Scaffold(
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
                height: MediaQuery.of(context).size.height * 0.4,
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderRadius: 10,
                    borderColor: Theme.of(context).primaryColor,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: MediaQuery.of(context).size.width * 0.6,
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
              child: TextFormField(
                controller: _numberController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Profilnummer eingeben',
                  hintText: 'Geben Sie eine Profilnummer ein',
                ),
                onChanged: (_) {
                  setState(() {
                    hasScanned = false;
                  });
                },
                onFieldSubmitted: (_) => _openUrlWithNumber(),
              ),
            ),
            // Link 1: PZE
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    const url = 'http://172.24.1.30:8080/ikoffice/root/';
                    if (Platform.isWindows) {
                      _openUrl(url);
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

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    const url = 'http://172.24.1.30:8080/ikoffice/root/';
                    if (Platform.isWindows) {
                      _openUrl(url);
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

    if (number.isNotEmpty) {
      final url = 'https://wim-solution.sip.local:8081/$number';

      if (await canLaunch(url)) {
        if (Platform.isWindows) {
          _openUrl(url);
        } else {
          // ignore: use_build_context_synchronously
          Navigator.push(
            context,
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
                      onTap: () {
                        final Uri emailUri = Uri(
                          scheme: 'mailto',
                          path: 'it-support@ttp-papenburg.de',
                        );
                        _openUrl(emailUri.toString());
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
                onTap: () => Platform.isAndroid
                    ? _openUrl(
                        'https://wim-solution.sip.local:8443/s/iBbZrtda7BTT7Qp')
                    : Platform.isWindows
                        ? _openUrl(
                            'http://lurchiweb.sip.local/schedule/ZPPLAN.pdf#view=FitH')
                        : Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WebViewModule(
                                url:
                                    'http://lurchiweb.sip.local/schedule/ZPPLAN.pdf#view=FitH',
                              ),
                            ),
                          ),
              ),
              ListTile(
                leading: Image.asset(
                  'assets/productionplan.png',
                  width: 36,
                  height: 36,
                ),
                title: const Text('Produktionsplan 3W'),
                onTap: () => Platform.isAndroid
                    ? _openUrl(
                        'https://wim-solution.sip.local:8443/s/EWxYDYmtKJQ2mfm')
                    : Platform.isWindows
                        ? _openUrl(
                            'http://lurchiweb.sip.local/schedule/ZPPLAN_3W.pdf#view=FitH')
                        : Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WebViewModule(
                                url:
                                    'http://lurchiweb.sip.local/schedule/ZPPLAN_3W.pdf#view=FitH',
                              ),
                            ),
                          ),
              ),
            ],
          ),
          ListTile(
            leading: Image.asset('assets/leuchtturm_blue.png',
                width: 36, height: 36),
            title: const Text('Intranet'),
            onTap: () => Platform.isWindows
                ? _openUrl('http://lurchiweb.sip.local')
                : Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WebViewModule(
                          url: 'http://lurchiweb.sip.local'),
                    ),
                  ),
          ),
          ListTile(
            leading: Image.asset('assets/ac.png', width: 36, height: 36),
            title: const Text('ActiveCollab'),
            onTap: () => Platform.isWindows
                ? _openUrl('https://olymp.sip.de')
                : Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const WebViewModule(url: 'https://olymp.sip.de'),
                    ),
                  ),
          ),
          ListTile(
            leading: Image.asset('assets/bookstack.png', width: 36, height: 36),
            title: const Text('ttpedia'),
            onTap: () => Platform.isWindows
                ? _openUrl('http://bookstack.sip.local')
                : Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WebViewModule(
                          url: 'http://bookstack.sip.local'),
                    ),
                  ),
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
                  final recentUrl =
                      'https://wim-solution.sip.local:8081/${recentItems[index]}';
                  return ListTile(
                    title: Text(recentItems[index]),
                    onTap: () {
                      if (Platform.isWindows) {
                        _openUrl(recentUrl);
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

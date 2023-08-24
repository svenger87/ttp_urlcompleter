// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WIM Profilnummer',
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

  QRViewController? controller;
  bool hasScanned = false;
  Timer? scanTimer;

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
      appBar: AppBar(
        title: const Text('WIM Profilnummer'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (!kIsWeb)
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
                onPressed: hasScanned || _numberController.text.isNotEmpty
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
        if (await canLaunch(scannedUrl)) {
          await launch(scannedUrl);
        } else {
          if (kDebugMode) {
            print('Could not launch $scannedUrl');
          }
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
    final String number = _numberController.text.trim();

    if (number.isNotEmpty) {
      final url = 'http://wim-solution.sip.local:8081/$number';

      if (await canLaunch(url)) {
        await launch(url);
      } else {
        if (kDebugMode) {
          print('Could not launch $url');
        }
      }
    }
  }

  Widget _buildDrawer() {
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
              children: [
                const Text(
                  'Linkliste',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: 'it-support@ttp-papenburg.de',
                    );
                    _openUrl(emailUri.toString());
                  },
                  child: const Text(
                    'it-support@ttp-papenburg.de',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Image.asset('assets/productionplan.png', width: 36, height: 36),
            title: const Text('Produktionsplan'),
            onTap: () {
              _openUrl('http://lurchiweb.sip.local/schedule/ZPPLAN.pdf');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Image.asset('assets/leuchtturm_blue.png', width: 36, height: 36),
            title: const Text('Intranet'),
            onTap: () {
              _openUrl('http://lurchiweb.sip.local');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Image.asset('assets/ac.png', width: 36, height: 36),
            title: const Text('ActiveCollab'),
            onTap: () {
              _openUrl('https://olymp.sip.de');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Image.asset('assets/bookstack.png', width: 36, height: 36),
            title: const Text('ttp Wiki'),
            onTap: () {
              _openUrl('http://bookstack.sip.local');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _openUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      if (kDebugMode) {
        print('Konnte nicht starten. $url');
      }
    }
  }
}
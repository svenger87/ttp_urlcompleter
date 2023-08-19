import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:vibration/vibration.dart';
import 'dart:async'; // Import Timer class

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
  bool scanEnabled = true;
  bool hasScanned = false;
  Timer? scanTimer; // Timer to re-enable the scanner

  @override
  void dispose() {
    controller?.dispose(); // Dispose QR code controller
    _numberController.dispose();
    scanTimer?.cancel(); // Cancel the timer when disposing
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WIM Profilnummer'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
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
                  primary: Theme.of(context).primaryColor,
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

    controller.scannedDataStream.listen((scanData) {
      if (scanEnabled && !hasScanned) {
        setState(() {
          scanEnabled = false;
          hasScanned = true;
          _numberController.text = scanData.code!;
        });

        Vibration.vibrate(duration: 50);

        _openUrlWithNumber();

        // Start the timer to re-enable the scanner after 10 seconds
        scanTimer = Timer(Duration(seconds: 10), () {
          setState(() {
            hasScanned = false;
          });
        });

        scanEnabled = true;
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
        print('Konnte nicht starten $url');
      }
    }
  }
}

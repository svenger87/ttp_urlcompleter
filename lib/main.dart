import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

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
  final TextEditingController _numberController = TextEditingController();
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  QRViewController? controller;
  bool scanEnabled = true;

  void _openUrlWithNumber() async {
    final String number = _numberController.text.trim();

    if (number.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Profilnummer darf nicht leer sein.'),
            content: const Text('Geben Sie bitte eine Profilnummer ein.'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    final url = 'http://wim-solution.sip.local:8081/$number';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Konnte nicht starten $url');
    }
  }

  @override
  void dispose() {
    controller?.dispose(); // Dispose QR code controller
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/leuchtturm.png'),
        ),
        title: const Text('WIM Profilnummer'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.4, // Adjust the height as needed
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderRadius: 10,
                borderColor: Theme.of(context).primaryColor,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: MediaQuery.of(context).size.width * 0.6, // Adjust the size as needed
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextFormField(
                    controller: _numberController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Profilnummer eingeben',
                      hintText: 'Geben Sie eine Profilnummer ein',
                    ),
                    onFieldSubmitted: (_) => _openUrlWithNumber(),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _openUrlWithNumber,
                    style: ElevatedButton.styleFrom(
                      primary: Theme.of(context).primaryColor,
                    ),
                    child: const Text('Profilverzeichnis öffnen'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
  if (scanEnabled) {
    setState(() {
      _numberController.text = scanData.code!;
      scanEnabled = false; // Disable further scans
    });

    // Trigger haptic feedback
    Vibration.vibrate(duration: 50); // Adjust duration as needed
    Future.delayed(Duration(seconds: 5), () {
        setState(() {
          _numberController.clear(); // Clear the input field
          scanEnabled = true; // Enable scanning again
        });
      });
    }
  });
}
}
import 'package:flutter/material.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String _scanResult = 'Noch nicht gescannt';

  // Diese Methode simuliert den Scanvorgang.
  // Später können Sie hier die Integration mit einem Scanner-Paket vornehmen.
  Future<void> _simulateScan() async {
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _scanResult = 'QR-Code: 1234567890';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_scanResult),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _simulateScan,
            child: const Text('Scan starten'),
          ),
        ],
      ),
    );
  }
}

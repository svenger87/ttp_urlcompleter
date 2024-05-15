import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'webview_module.dart'; // Import the WebViewModule

class PinScreen extends StatefulWidget {
  final String url; // Accept the URL as a parameter

  const PinScreen({Key? key, required this.url}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _PinScreenState createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  bool _pinCorrect = false;

  // Function to verify PIN
  void _verifyPin(String pin) {
    // Your PIN verification logic here
    // For simplicity, I'm hardcoding a PIN
    if (pin == '1234') {
      setState(() {
        _pinCorrect = true;
      });
      _savePinTimestamp(); // Save timestamp when PIN is correct
      _openUrl(); // Open the URL directly after correct PIN
    } else {
      // Handle incorrect PIN
      // You can show an error message or clear PIN input
    }
  }

  // Function to save timestamp when PIN is entered correctly
  Future<void> _savePinTimestamp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('pinTimestamp', DateTime.now().toString());
  }

  // Function to check if PIN was entered within the last 24 hours
  // ignore: unused_element
  Future<bool> _checkPinTimestamp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? pinTimestamp = prefs.getString('pinTimestamp');
    if (pinTimestamp != null) {
      DateTime timestamp = DateTime.parse(pinTimestamp);
      DateTime now = DateTime.now();
      Duration difference = now.difference(timestamp);
      return difference.inHours < 24;
    } else {
      return false; // PIN not entered yet
    }
  }

  // Function to open the URL
  void _openUrl() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WebViewModule(url: widget.url), // Use the URL parameter
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN eingeben'),
        backgroundColor: const Color(0xFF104382), // Set header bar color
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              onChanged: (value) {
                setState(() {
                  _pin = value;
                });
              },
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'PIN eingeben',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _verifyPin(_pin);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF104382), // Set button color
              ),
              child: const Text('Bestätigen'),
            ),
            _pinCorrect
                ? const Text('PIN korrekt!')
                : const SizedBox(), // Show message if PIN is correct
          ],
        ),
      ),
    );
  }
}

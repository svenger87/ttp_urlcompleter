import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PinScreenState createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  bool _pinCorrect = false;
  bool _showError = false; // State variable to control error message visibility

  // Function to verify PIN
  void _verifyPin(String pin) {
    // Your PIN verification logic here
    // For simplicity, I'm hardcoding a PIN
    if (pin == '1234') {
      setState(() {
        _pinCorrect = true;
        _showError = false; // Reset error state if PIN is correct
      });
      _savePinTimestamp(); // Save timestamp when PIN is correct
    } else {
      // Handle incorrect PIN
      // Set state to show error message
      setState(() {
        _showError = true;
      });
    }
  }

  // Function to save timestamp when PIN is entered correctly
  Future<void> _savePinTimestamp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('pinTimestamp', DateTime.now().toString());
  }

  // Function to check if PIN was entered within the last 24 hours
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN eingeben'),
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
                backgroundColor:
                    const Color(0xFF104382), // Set button background color
              ),
              child: const Text('Bestätigen'),
            ),
            _pinCorrect
                ? const Text('PIN korrekt!')
                : _showError // Show error message if PIN is incorrect
                    ? const Text(
                        'Falsche PIN. Bitte versuchen Sie es erneut.',
                        style: TextStyle(
                          color: Color(
                              0xFF104382), // Use the same color as the button
                        ),
                      )
                    : const SizedBox(), // Show message if PIN is correct or no error
          ],
        ),
      ),
    );
  }
}

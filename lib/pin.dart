import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'webview_module.dart';

class PinScreen extends StatefulWidget {
  final String url;

  const PinScreen({Key? key, required this.url}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _PinScreenState createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  bool _pinCorrect = false;
  bool _showWrongPinHint = false;
  List<String> _usernames = [];
  late webdav.Client client;

  final url = 'https://wim-solution.sip.local:8443/public.php';
  final user = 'mYYc2cJyWG795BM';
  final pwd = '';
  final dirPath = '/';

  @override
  void initState() {
    super.initState();
    _loadUsernames();
    _initializeWebDavClient();
  }

  void _initializeWebDavClient() {
    client = webdav.newClient(
      url,
      user: user,
      password: pwd,
      debug: true,
    );
  }

  Future<void> _loadUsernames() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernames = prefs.getStringList('usernames') ?? [];
    });
  }

  Future<void> _saveUsername(String username) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!_usernames.contains(username)) {
      _usernames.add(username);
      await prefs.setStringList('usernames', _usernames);
    }
  }

  void _verifyPin(String pin) {
    if (pin == '1234') {
      setState(() {
        _pinCorrect = true;
      });
      _savePinTimestamp();
      _openUrl();
    } else {
      setState(() {
        _showWrongPinHint = true;
      });
    }
  }

  Future<void> _savePinTimestamp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('pinTimestamp', DateTime.now().toString());
  }

  void _openUrl() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewModule(url: widget.url),
      ),
    );
  }

  Future<void> _promptForCompletion() async {
    String? selectedUser = await _showUserSelectionDialog();
    if (selectedUser != null) {
      await _saveUsername(selectedUser);
      bool isDone = await _showCompletionDialog();
      if (isDone) {
        await _renameAndMoveFile(selectedUser);
      }
    }
  }

  Future<String?> _showUserSelectionDialog() async {
    String? selectedUser;
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select User'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return DropdownButton<String>(
                isExpanded: true,
                value: selectedUser,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedUser = newValue!;
                  });
                },
                items: _usernames.map<DropdownMenuItem<String>>((String user) {
                  return DropdownMenuItem<String>(
                    value: user,
                    child: Text(user),
                  );
                }).toList(),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(selectedUser);
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showCompletionDialog() async {
    bool? isDone = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Is the file done?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
          ],
        );
      },
    );
    return isDone ?? false;
  }

  Future<void> _renameAndMoveFile(String username) async {
    try {
      const String oldFilePath = '/path/to/file'; // Specify the file path
      final String newFilePath =
          '/Done/${username}_${DateTime.now().toIso8601String()}.file_extension'; // Update the file extension

      // Assuming the client has the method to move files, otherwise use copy + delete
      await client.copy(oldFilePath, newFilePath, false);
      await client.remove(oldFilePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File moved to Done folder')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to move file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _promptForCompletion();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PIN eingeben'),
          backgroundColor: const Color(0xFF104382),
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
                  backgroundColor: const Color(0xFF104382),
                ),
                child: const Text('Bestätigen'),
              ),
              _showWrongPinHint
                  ? const Text(
                      'Falsche PIN! Bitte versuchen Sie es erneut.',
                      style: TextStyle(color: Colors.red),
                    )
                  : const SizedBox(),
              _pinCorrect ? const Text('PIN korrekt!') : const SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}

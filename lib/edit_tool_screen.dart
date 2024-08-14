// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'tool_service.dart';
import 'tool.dart';

class EditToolScreen extends StatefulWidget {
  final Tool tool;
  const EditToolScreen({Key? key, required this.tool}) : super(key: key);

  @override
  _EditToolScreenState createState() => _EditToolScreenState();
}

class _EditToolScreenState extends State<EditToolScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _storageLocation;
  bool _isLoading = false;
  bool _hasError = false;
  bool _forceUpdate = false; // Force update flag

  @override
  void initState() {
    super.initState();
    _storageLocation = widget.tool.storageLocation;
  }

  Future<void> _updateTool() async {
    if (!_formKey.currentState!.validate()) return;

    const doNotUpdate = true;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await ToolService().updateTool(
        widget.tool.id,
        _storageLocation,
        doNotUpdate: doNotUpdate,
        forceUpdate: _forceUpdate,
      );

      if (result == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Werkzeug erfolgreich aktualisiert')),
        );
        Navigator.pop(context);
      } else if (result == 'ignored') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Änderung nicht zugelassen! Falls erfolderlich erzwingen!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unbekannter Fehler')),
        );
      }
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update des Werkzeugs fehlgeschlagen')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Werkzeuglagerverwaltung'),
        backgroundColor: const Color(0xFF104382), // Set the desired color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
                ? const Center(child: Text('Error updating tool'))
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          initialValue: _storageLocation,
                          decoration:
                              const InputDecoration(labelText: 'Lagerplatz'),
                          onChanged: (value) {
                            setState(() {
                              _storageLocation = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Bitte Lagerplatz eingeben';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Hint box for "Force Update"
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: const Text(
                            'Verwenden Sie diese Option, um den Lagerplatz zu '
                            'aktualisieren, selbst wenn das Werkzeug als nicht '
                            'aktualisierbar markiert ist. Diese Aktion sollte nur '
                            'durchgeführt werden, wenn Sie sicher sind, dass die '
                            'Änderung notwendig ist.',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Switch to force update
                        SwitchTheme(
                          data: SwitchThemeData(
                            thumbColor: MaterialStateProperty.all(const Color(
                                0xFF104382)), // Color when switch is on
                            trackColor: MaterialStateProperty.all(
                                Color.fromARGB(255, 179, 8, 8).withOpacity(
                                    0.5)), // Color when switch is off
                          ),
                          child: SwitchListTile(
                            title:
                                const Text('Änderung vom Lagerplatz erzwingen'),
                            value: _forceUpdate,
                            onChanged: (value) {
                              setState(() {
                                _forceUpdate = value; // Ensure state is updated
                              });
                            },
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0.0), // Remove default padding
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            onPressed: _updateTool,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF104382)),
                            child: const Text('Lagerplatz speichern'),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

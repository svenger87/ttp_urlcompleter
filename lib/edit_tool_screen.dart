// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/foundation.dart';
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
  bool _isEdited = false; // Track if data has been edited

  @override
  void initState() {
    super.initState();
    _storageLocation = widget.tool.storageLocation;
    _isEdited = false; // Initialize as false
  }

  Future<void> _updateTool() async {
    if (!_formKey.currentState!.validate()) return;

    // Always set do_not_update to 1 when editing
    const doNotUpdate = true;

    if (kDebugMode) {
      print('Tool edited: $_isEdited, doNotUpdate flag: $doNotUpdate');
      print(
          'Updating tool ${widget.tool.id}: storageLocation=$_storageLocation, doNotUpdate=$doNotUpdate');
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await ToolService().updateTool(
          widget.tool.id, _storageLocation,
          doNotUpdate: doNotUpdate);
      if (result == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Werkzeug erfolgreich aktualisiert')));
        Navigator.pop(context);
      } else if (result == 'ignored') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Update des Lagerplatzes ist nicht erlaubt!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Unbekannter Fehler beim Aktualisieren des Werkzeugs')));
      }
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update des Werkzeugs fehlgeschlagen')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Werkzeug bearbeiten')),
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
                              _isEdited = true; // Set to true when editing
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
                        ElevatedButton(
                          onPressed: _updateTool,
                          child: const Text('Lagerplatz speichern'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

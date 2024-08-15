// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

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
  late String _storageStatus;
  bool _isLoading = false;
  bool _hasError = false;
  bool _forceUpdate = false;

  @override
  void initState() {
    super.initState();
    _storageLocation = widget.tool.storageLocation;

    // Normalize _storageStatus to lowercase for case-insensitive handling
    _storageStatus = widget.tool.storageStatus.toLowerCase();

    // Ensure _storageStatus matches one of the dropdown values
    if (_storageStatus != 'in stock' && _storageStatus != 'out of stock') {
      _storageStatus = 'in stock'; // Default to 'in stock' if no match
    }
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
        storageStatus: _storageStatus,
        doNotUpdate: doNotUpdate,
        forceUpdate: _forceUpdate,
      );

      if (result == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Werkzeug erfolgreich aktualisiert')),
        );
        Navigator.pop(context);
      } else if (result == 'ignored') {
        if (_storageLocation.toLowerCase() !=
            widget.tool.storageLocation.toLowerCase()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Lagerplatz wurde nicht aktualisiert! Erzwingen Sie die Änderung, wenn erforderlich.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Werkzeugstatus erfolgreich aktualisiert')),
          );
          Navigator.pop(context);
        }
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

  Future<void> _confirmDeleteTool() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Werkzeug löschen'),
          content: const Text(
              'Möchten Sie dieses Werkzeug wirklich löschen?\nDiese Aktion kann nicht rückgängig gemacht werden.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // User cancels the deletion
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true); // User confirms the deletion
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteTool(); // Proceed with the deletion if confirmed
    }
  }

  Future<void> _deleteTool() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await ToolService().deleteTool(widget.tool.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Werkzeug erfolgreich gelöscht')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Löschen des Werkzeugs fehlgeschlagen')),
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
        backgroundColor: const Color(0xFF104382),
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

                        // Dropdown for storage status with colored indicators
                        DropdownButtonFormField<String>(
                          value: _storageStatus
                              .toLowerCase(), // Ensure value is lowercase
                          items: const [
                            DropdownMenuItem(
                              value: 'in stock',
                              child: Row(
                                children: [
                                  Icon(Icons.circle,
                                      color: Colors.green, size: 12),
                                  SizedBox(width: 8),
                                  Text('Auf Lager'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'out of stock',
                              child: Row(
                                children: [
                                  Icon(Icons.circle,
                                      color: Colors.red, size: 12),
                                  SizedBox(width: 8),
                                  Text('Nicht auf Lager'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _storageStatus =
                                  value!.toLowerCase(); // Normalize on change
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Lagerstatus',
                          ),
                        ),

                        const SizedBox(height: 20),

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

                        SwitchListTile(
                          title:
                              const Text('Änderung vom Lagerplatz erzwingen'),
                          value: _forceUpdate,
                          onChanged: (value) {
                            setState(() {
                              _forceUpdate = value;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        Center(
                          child: ElevatedButton(
                            onPressed: _updateTool,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF104382),
                            ),
                            child: const Text('Lagerplatz speichern'),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Add a delete button
                        Center(
                          child: ElevatedButton(
                            onPressed: _confirmDeleteTool,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Werkzeug löschen'),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

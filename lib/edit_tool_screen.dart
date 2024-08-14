// ignore_for_file: library_private_types_in_public_api

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

  @override
  void initState() {
    super.initState();
    _storageLocation = widget.tool.storageLocation;
  }

  Future<void> _updateTool() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await ToolService().updateTool(widget.tool.id, _storageLocation);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Werkzeug erfolgreich aktualisiert')));
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update des Werkeugs fehlgeschlagen')));
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
                          onChanged: (value) => setState(() {
                            _storageLocation = value;
                          }),
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

// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/tool.dart';
import '../services/tool_service.dart';

class EditToolScreen extends StatefulWidget {
  final Tool tool;
  const EditToolScreen({super.key, required this.tool});

  @override
  // ignore: library_private_types_in_public_api
  _EditToolScreenState createState() => _EditToolScreenState();
}

class _EditToolScreenState extends State<EditToolScreen> {
  final ToolService _toolService = ToolService();
  final _formKey = GlobalKey<FormState>();

  List<String> _freeStorages = [];
  List<Map<String, String>> _users = [];
  String? _selectedStorageOne;
  String? _selectedStorageTwo;

  String? _selectedUsedSpacePitchOne;
  String? _selectedUsedSpacePitchTwo;

  String? _selectedStockStatus;
  String? _selectedUserId;

  bool _isLoading = false;
  bool _storageStateChanged = false;

  @override
  void initState() {
    super.initState();

    // Print the tool data to verify
    if (kDebugMode) {
      print('Tool Data: ${widget.tool.toJson()}');
    }

    _selectedStorageOne = widget.tool.storageLocationOne;
    _selectedStorageTwo = widget.tool.storageLocationTwo;

    // Fetch free storages and then validate the initial values after fetching
    _fetchFreeStorages();
    _fetchUsers();

    // Ensure correct translations for used space
    _selectedUsedSpacePitchOne =
        widget.tool.usedSpacePitchOne?.replaceAll('.', ',') ?? '0,5';
    _selectedUsedSpacePitchTwo =
        widget.tool.usedSpacePitchTwo?.replaceAll('.', ',') ?? '0,5';

    // Use the 'provided' field to determine the stock status and keep the German translation
    _selectedStockStatus = widget.tool.provided ? 'Ausgelagert' : 'Eingelagert';
  }

  Future<void> _fetchFreeStorages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _freeStorages = await _toolService.fetchFreeStorages();
      _freeStorages = _freeStorages.toSet().toList();

      // Validate initial values after fetching free storages
      _validateInitialValues();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fehler beim Laden der freien Lagerplätze')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _validateInitialValues() {
    setState(() {
      // Directly set the storage values from the tool without checking the free storages list
      _selectedStorageOne = widget.tool.storageLocationOne;
      _selectedStorageTwo = widget.tool.storageLocationTwo;
    });
  }

  String _translateStatusToEnglish(String status) {
    if (status == 'Eingelagert') return 'In stock';
    if (status == 'Ausgelagert') return 'Out of stock';
    return status;
  }

  Future<void> _fetchUsers() async {
    try {
      List<Map<String, dynamic>> fetchedUsers = await _toolService.fetchUsers();

      if (kDebugMode) {
        print('Fetched users: $fetchedUsers');
      }

      _users = fetchedUsers.map((user) => user.cast<String, String>()).toList();
      setState(() {});
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching users: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Laden der Benutzerliste')),
      );
    }
  }

  Future<void> _updateTool() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use a non-nullable current date for both providedDate and returnedDate
      DateTime now = DateTime.now();

      bool providedStatus = _selectedStockStatus == 'Ausgelagert';

      // Only set providedById and returnedById if the stock status is changed
      String? providedById = providedStatus ? _selectedUserId : null;
      String? returnedById = !providedStatus ? _selectedUserId : null;

      // Ensure the storage locations are not null or empty
      String storageLocationOne =
          _selectedStorageOne ?? widget.tool.storageLocationOne ?? '';
      String storageLocationTwo =
          _selectedStorageTwo ?? widget.tool.storageLocationTwo ?? '';

      if (storageLocationOne.isEmpty && storageLocationTwo.isEmpty) {
        throw Exception('At least one storage location must not be empty');
      }

      // Log the payload to verify values before sending
      if (kDebugMode) {
        print(jsonEncode({
          'storage_location_one': storageLocationOne,
          'storage_location_two': storageLocationTwo,
          'used_space_pitch_one':
              _selectedUsedSpacePitchOne?.replaceAll(',', '.') ?? '0.5',
          'used_space_pitch_two':
              _selectedUsedSpacePitchTwo?.replaceAll(',', '.') ?? '0.5',
          'storage_status':
              _translateStatusToEnglish(_selectedStockStatus ?? 'Eingelagert'),
          'provided_date': providedStatus ? now.toIso8601String() : null,
          'returned_date': !providedStatus ? now.toIso8601String() : null,
          'provideddby_id': providedById,
          'returnedby_id': returnedById,
          'provided': providedStatus
        }));
      }

      // Call the service to update the tool
      await _toolService.updateTool(
          toolNumber: widget.tool.toolNumber,
          storageLocationOne: storageLocationOne,
          storageLocationTwo: storageLocationTwo,
          usedSpacePitchOne:
              _selectedUsedSpacePitchOne?.replaceAll(',', '.') ?? '0.5',
          usedSpacePitchTwo:
              _selectedUsedSpacePitchTwo?.replaceAll(',', '.') ?? '0.5',
          storageStatus:
              _translateStatusToEnglish(_selectedStockStatus ?? 'Eingelagert'),
          providedDate: now, // No longer nullable
          returnedDate: now, // No longer nullable
          providedById: providedById ?? '',
          returnedById: returnedById ?? '',
          providedStatus: providedStatus);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Werkzeug erfolgreich aktualisiert')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (kDebugMode) {
        print('Error during tool update: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fehler beim Aktualisieren des Werkzeugs')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> stockStatusOptions = ['Eingelagert', 'Ausgelagert'];
    final List<String> usedSpaceValues = List.generate(18, (index) {
      return ((index + 1) * 0.5).toStringAsFixed(1).replaceAll('.', ',');
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF104382),
        title: Text('Werkzeug bearbeiten ${widget.tool.toolNumber}'),
        titleTextStyle: const TextStyle(
          color: Colors.white, // Set the text color to white
          fontSize: 20, // Optionally adjust the font size
          fontWeight: FontWeight.bold, // Optionally adjust the font weight
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildStockStatusIndicator(),
                        const SizedBox(height: 16.0),
                        _buildDropdown(
                          label: 'Lagerplatz 1',
                          value: _selectedStorageOne,
                          items: _freeStorages,
                          onChanged: (value) {
                            setState(() {
                              _selectedStorageOne = value;
                              _storageStateChanged = true;
                            });
                          },
                        ),
                        _buildDropdown(
                          label: 'Lagerplatz 2',
                          value: _selectedStorageTwo,
                          items: _freeStorages,
                          onChanged: (value) {
                            setState(() {
                              _selectedStorageTwo = value;
                              _storageStateChanged = true;
                            });
                          },
                        ),
                        _buildDropdown(
                          label: 'Belegter Platz 1',
                          value: _selectedUsedSpacePitchOne,
                          items: usedSpaceValues,
                          onChanged: (value) {
                            setState(() {
                              _selectedUsedSpacePitchOne = value;
                              _storageStateChanged = true;
                            });
                          },
                        ),
                        _buildDropdown(
                          label: 'Belegter Platz 2',
                          value: _selectedUsedSpacePitchTwo,
                          items: usedSpaceValues,
                          onChanged: (value) {
                            setState(() {
                              _selectedUsedSpacePitchTwo = value;
                              _storageStateChanged = true;
                            });
                          },
                        ),
                        _buildDropdown(
                          label: 'Lagerstatus',
                          value: _selectedStockStatus,
                          items: stockStatusOptions,
                          onChanged: (value) {
                            setState(() {
                              _selectedStockStatus = value;
                              _storageStateChanged = true;
                            });
                          },
                        ),
                        if (_storageStateChanged && _users.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: _selectedUserId,
                            decoration: const InputDecoration(
                                labelText: 'Durchgeführt von'),
                            items: _users
                                .map((user) => DropdownMenuItem<String>(
                                      value: user['user_id'],
                                      child: Text(
                                          '${user['employeenumber']} - ${user['lastname']}'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedUserId = value;
                              });
                            },
                          ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _updateTool,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF104382)),
                          child: const Text('Werkzeug aktualisieren'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        if (value != null && !items.contains(value))
          DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          ),
        ...items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildStockStatusIndicator() {
    bool isOutOfStock =
        widget.tool.provided; // Use the 'provided' field directly

    return Row(
      children: [
        Icon(
          isOutOfStock ? Icons.cancel : Icons.check_circle,
          color: isOutOfStock ? Colors.red : Colors.green,
        ),
        const SizedBox(width: 8),
        Text(
          isOutOfStock ? 'Ausgelagert' : 'Eingelagert',
          style: TextStyle(
            color: isOutOfStock ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

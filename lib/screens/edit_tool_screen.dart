import 'package:flutter/material.dart';
import '../models/tool.dart';
import '../services/tool_service.dart';

class EditToolScreen extends StatefulWidget {
  final Tool tool;
  const EditToolScreen({Key? key, required this.tool}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _EditToolScreenState createState() => _EditToolScreenState();
}

class _EditToolScreenState extends State<EditToolScreen> {
  final ToolService _toolService = ToolService();
  final _formKey = GlobalKey<FormState>();

  List<String> _freeStorages = [];
  String? _selectedStorageOne;
  String? _selectedStorageTwo;

  // Variables to track selected used space pitch for both storages
  String? _selectedUsedSpacePitchOne;
  String? _selectedUsedSpacePitchTwo;

  // Variable to track stock status (in English for backend storage)
  String? _selectedStockStatus;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchFreeStorages();

    // Pre-select values if they exist in the tool data
    _selectedStorageOne = widget.tool.storageLocationOne;
    _selectedStorageTwo = widget.tool.storageLocationTwo;

    // Initialize used space pitch with existing data from the tool
    _selectedUsedSpacePitchOne =
        widget.tool.usedSpacePitchOne?.replaceAll('.', ',') ?? '0,5';
    _selectedUsedSpacePitchTwo =
        widget.tool.usedSpacePitchTwo?.replaceAll('.', ',') ?? '0,5';

    // Initialize stock status (convert English status to German for display)
    _selectedStockStatus = _translateStatusToGerman(widget.tool.storageStatus);
  }

  // Translate stock status from English (backend) to German (UI display)
  String _translateStatusToGerman(String status) {
    if (status == 'In stock') return 'Eingelagert';
    if (status == 'Out of stock') return 'Ausgelagert';
    return status; // Return the original if unknown
  }

// Translate stock status from German (UI input) to English (backend)
  String _translateStatusToEnglish(String status) {
    if (status == 'Eingelagert') return 'In stock';
    if (status == 'Ausgelagert') return 'Out of stock';
    return status; // Return the original if unknown
  }

  // Fetch free storages from the backend
  Future<void> _fetchFreeStorages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _freeStorages = await _toolService.fetchFreeStorages();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _updateTool() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _toolService.updateTool(
        widget.tool.toolNumber,
        _selectedStorageOne ?? '',
        _selectedStorageTwo ?? '',
        usedSpacePitchOne:
            _selectedUsedSpacePitchOne?.replaceAll(',', '.') ?? '0.5',
        usedSpacePitchTwo:
            _selectedUsedSpacePitchTwo?.replaceAll(',', '.') ?? '0.5',
        storageStatus:
            _translateStatusToEnglish(_selectedStockStatus ?? 'Ausgelagert'),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Werkzeug erfolgreich aktualisiert')),
      );

      // Indicate that the tool was successfully updated
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
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

    // Generate list of comma-separated values from 0,5 to 9,0
    final List<String> usedSpaceValues = List.generate(18, (index) {
      return ((index + 1) * 0.5).toStringAsFixed(1).replaceAll('.', ',');
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF104382),
        title: Text('Werkzeug bearbeiten ${widget.tool.toolNumber}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Stock status indicator
                    _buildStockStatusIndicator(),
                    const SizedBox(height: 16.0),

                    // Dropdown for Storage Location One
                    DropdownButtonFormField<String>(
                      value: _freeStorages.contains(_selectedStorageOne)
                          ? _selectedStorageOne
                          : null,
                      hint: const Text('Wähle Lagerplatz 1'),
                      onChanged: (value) {
                        setState(() {
                          _selectedStorageOne = value;
                        });
                      },
                      items: _freeStorages.map((storage) {
                        return DropdownMenuItem<String>(
                          value: storage,
                          child: Text(storage),
                        );
                      }).toList(),
                      decoration:
                          const InputDecoration(labelText: 'Lagerplatz 1'),
                    ),
                    const SizedBox(height: 16.0),

                    // Dropdown for Storage Location Two
                    DropdownButtonFormField<String>(
                      value: _freeStorages.contains(_selectedStorageTwo)
                          ? _selectedStorageTwo
                          : null,
                      hint: const Text('Wähle Lagerplatz 2'),
                      onChanged: (value) {
                        setState(() {
                          _selectedStorageTwo = value;
                        });
                      },
                      items: _freeStorages.map((storage) {
                        return DropdownMenuItem<String>(
                          value: storage,
                          child: Text(storage),
                        );
                      }).toList(),
                      decoration:
                          const InputDecoration(labelText: 'Lagerplatz 2'),
                    ),
                    const SizedBox(height: 16.0),

                    // Dropdown for Used Space Pitch One
                    DropdownButtonFormField<String>(
                      value:
                          usedSpaceValues.contains(_selectedUsedSpacePitchOne)
                              ? _selectedUsedSpacePitchOne
                              : null,
                      decoration:
                          const InputDecoration(labelText: 'Belegter Platz 1'),
                      onChanged: (value) {
                        setState(() {
                          _selectedUsedSpacePitchOne = value!;
                        });
                      },
                      items: usedSpaceValues.map((value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16.0),

                    // Dropdown for Used Space Pitch Two
                    DropdownButtonFormField<String>(
                      value:
                          usedSpaceValues.contains(_selectedUsedSpacePitchTwo)
                              ? _selectedUsedSpacePitchTwo
                              : null,
                      decoration:
                          const InputDecoration(labelText: 'Belegter Platz 2'),
                      onChanged: (value) {
                        setState(() {
                          _selectedUsedSpacePitchTwo = value!;
                        });
                      },
                      items: usedSpaceValues.map((value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16.0),

                    // Dropdown for Stock Status
                    DropdownButtonFormField<String>(
                      value: _selectedStockStatus,
                      decoration:
                          const InputDecoration(labelText: 'Lagerstatus'),
                      onChanged: (value) {
                        setState(() {
                          _selectedStockStatus = value!;
                        });
                      },
                      items: stockStatusOptions.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Update Button
                    ElevatedButton(
                      onPressed: _updateTool,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF104382), // Custom background color
                      ),
                      child: const Text('Werkzeug aktualisieren'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget to display stock status with an icon and color
  Widget _buildStockStatusIndicator() {
    bool isInStock = _selectedStockStatus == 'Eingelagert';

    return Row(
      children: [
        Icon(
          isInStock ? Icons.check_circle : Icons.cancel,
          color: isInStock ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Text(
          isInStock ? 'Eingelagert' : 'Ausgelagert',
          style: TextStyle(
            color: isInStock ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

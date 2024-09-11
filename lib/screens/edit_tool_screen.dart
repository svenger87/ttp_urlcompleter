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

  String? _selectedUsedSpacePitchOne;
  String? _selectedUsedSpacePitchTwo;

  String? _selectedStockStatus;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchFreeStorages();

    _selectedStorageOne = widget.tool.storageLocationOne;
    _selectedStorageTwo = widget.tool.storageLocationTwo;
    _selectedUsedSpacePitchOne =
        widget.tool.usedSpacePitchOne?.replaceAll('.', ',') ?? '0,5';
    _selectedUsedSpacePitchTwo =
        widget.tool.usedSpacePitchTwo?.replaceAll('.', ',') ?? '0,5';
    _selectedStockStatus = _translateStatusToGerman(widget.tool.storageStatus);
  }

  String _translateStatusToGerman(String status) {
    if (status == 'In stock') return 'Eingelagert';
    if (status == 'Out of stock') return 'Ausgelagert';
    return status;
  }

  String _translateStatusToEnglish(String status) {
    if (status == 'Eingelagert') return 'In stock';
    if (status == 'Ausgelagert') return 'Out of stock';
    return status;
  }

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
    final List<String> usedSpaceValues = List.generate(18, (index) {
      return ((index + 1) * 0.5).toStringAsFixed(1).replaceAll('.', ',');
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF104382),
        title: Text('Werkzeug bearbeiten ${widget.tool.toolNumber}'),
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
                        DropdownButtonFormField<String>(
                          value: _selectedStorageOne,
                          hint: const Text('Wähle Lagerplatz 1'),
                          onChanged: (value) {
                            setState(() {
                              _selectedStorageOne = value;
                            });
                          },
                          items: [
                            if (_selectedStorageOne != null &&
                                !_freeStorages.contains(_selectedStorageOne))
                              DropdownMenuItem<String>(
                                value: _selectedStorageOne,
                                child: Text(_selectedStorageOne!),
                              ),
                            ..._freeStorages.map((storage) {
                              return DropdownMenuItem<String>(
                                value: storage,
                                child: Text(storage),
                              );
                            }).toList(),
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Lagerplatz 1'),
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedStorageTwo,
                          hint: const Text('Wähle Lagerplatz 2'),
                          onChanged: (value) {
                            setState(() {
                              _selectedStorageTwo = value;
                            });
                          },
                          items: [
                            if (_selectedStorageTwo != null &&
                                !_freeStorages.contains(_selectedStorageTwo))
                              DropdownMenuItem<String>(
                                value: _selectedStorageTwo,
                                child: Text(_selectedStorageTwo!),
                              ),
                            ..._freeStorages.map((storage) {
                              return DropdownMenuItem<String>(
                                value: storage,
                                child: Text(storage),
                              );
                            }).toList(),
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Lagerplatz 2'),
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedUsedSpacePitchOne,
                          decoration: const InputDecoration(
                              labelText: 'Belegter Platz 1'),
                          onChanged: (value) {
                            setState(() {
                              _selectedUsedSpacePitchOne = value!;
                            });
                          },
                          items: [
                            if (_selectedUsedSpacePitchOne != null &&
                                !usedSpaceValues
                                    .contains(_selectedUsedSpacePitchOne))
                              DropdownMenuItem<String>(
                                value: _selectedUsedSpacePitchOne,
                                child: Text(_selectedUsedSpacePitchOne!),
                              ),
                            ...usedSpaceValues.map((value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ],
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedUsedSpacePitchTwo,
                          decoration: const InputDecoration(
                              labelText: 'Belegter Platz 2'),
                          onChanged: (value) {
                            setState(() {
                              _selectedUsedSpacePitchTwo = value!;
                            });
                          },
                          items: [
                            if (_selectedUsedSpacePitchTwo != null &&
                                !usedSpaceValues
                                    .contains(_selectedUsedSpacePitchTwo))
                              DropdownMenuItem<String>(
                                value: _selectedUsedSpacePitchTwo,
                                child: Text(_selectedUsedSpacePitchTwo!),
                              ),
                            ...usedSpaceValues.map((value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ],
                        ),
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
                        ElevatedButton(
                          onPressed: _updateTool,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF104382),
                          ),
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

// palette_type_form_screen.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/palette_type.dart';
import '../services/api_service.dart';

class PaletteTypeFormScreen extends StatefulWidget {
  final ApiService apiService;
  final PaletteType? paletteType;

  const PaletteTypeFormScreen(
      {super.key, required this.apiService, this.paletteType});

  @override
  _PaletteTypeFormScreenState createState() => _PaletteTypeFormScreenState();
}

class _PaletteTypeFormScreenState extends State<PaletteTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _lhmNummerController;
  late TextEditingController _materialController;
  late TextEditingController _debitorController;
  late TextEditingController _bezeichnungController;
  late TextEditingController _hoeheMmController;
  late TextEditingController _stapelfaehigkeitController;
  late TextEditingController _breiteMmController;
  late TextEditingController _laengeMmController;
  late TextEditingController _platzbedarfController;
  late TextEditingController _bruttogewichtController;
  late TextEditingController _gewichtseinheitController;
  late TextEditingController _buchungsKzController;
  late TextEditingController _lhmKuehneNagelController;
  late TextEditingController _globalInventoryController;
  late TextEditingController _minAvailableController;
  String? _photoPath;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final paletteType = widget.paletteType;
    _lhmNummerController =
        TextEditingController(text: paletteType?.lhmNummer ?? '');
    _materialController =
        TextEditingController(text: paletteType?.material ?? '');
    _debitorController =
        TextEditingController(text: paletteType?.debitor ?? '');
    _bezeichnungController =
        TextEditingController(text: paletteType?.bezeichnung ?? '');
    _hoeheMmController =
        TextEditingController(text: paletteType?.hoeheMm.toString() ?? '');
    _stapelfaehigkeitController =
        TextEditingController(text: paletteType?.stapelfaehigkeit ?? '');
    _breiteMmController =
        TextEditingController(text: paletteType?.breiteMm.toString() ?? '');
    _laengeMmController =
        TextEditingController(text: paletteType?.laengeMm.toString() ?? '');
    _platzbedarfController =
        TextEditingController(text: paletteType?.platzbedarf.toString() ?? '');
    _bruttogewichtController = TextEditingController(
        text: paletteType?.bruttogewicht.toString() ?? '');
    _gewichtseinheitController =
        TextEditingController(text: paletteType?.gewichtseinheit ?? '');
    _buchungsKzController =
        TextEditingController(text: paletteType?.buchungsKz ?? '');
    _lhmKuehneNagelController =
        TextEditingController(text: paletteType?.lhmKuehneNagel ?? '');
    _globalInventoryController = TextEditingController(
        text: paletteType?.globalInventory.toString() ?? '0');
    _minAvailableController = TextEditingController(
        text: paletteType?.minAvailable.toString() ??
            '0'); // Initialize new field
    _photoPath = paletteType?.photo;
  }

  @override
  void dispose() {
    _lhmNummerController.dispose();
    _materialController.dispose();
    _debitorController.dispose();
    _bezeichnungController.dispose();
    _hoeheMmController.dispose();
    _stapelfaehigkeitController.dispose();
    _breiteMmController.dispose();
    _laengeMmController.dispose();
    _platzbedarfController.dispose();
    _bruttogewichtController.dispose();
    _gewichtseinheitController.dispose();
    _buchungsKzController.dispose();
    _lhmKuehneNagelController.dispose();
    _globalInventoryController.dispose();
    _minAvailableController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _photoPath = image.path;
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final paletteType = PaletteType(
        id: widget.paletteType?.id,
        lhmNummer: _lhmNummerController.text,
        material: _materialController.text,
        debitor: _debitorController.text,
        bezeichnung: _bezeichnungController.text,
        hoeheMm: int.tryParse(_hoeheMmController.text) ?? 0,
        stapelfaehigkeit: _stapelfaehigkeitController.text,
        breiteMm: int.tryParse(_breiteMmController.text) ?? 0,
        laengeMm: int.tryParse(_laengeMmController.text) ?? 0,
        platzbedarf: double.tryParse(_platzbedarfController.text) ?? 0.0,
        bruttogewicht: double.tryParse(_bruttogewichtController.text) ?? 0.0,
        gewichtseinheit: _gewichtseinheitController.text,
        buchungsKz: _buchungsKzController.text,
        lhmKuehneNagel: _lhmKuehneNagelController.text,
        photo: _photoPath ?? '',
        globalInventory: int.tryParse(_globalInventoryController.text) ?? 0,
        bookedQuantity: widget.paletteType?.bookedQuantity ?? 0,
        minAvailable: int.tryParse(_minAvailableController.text) ??
            0, // Set the min available value
      );
      try {
        if (widget.paletteType == null) {
          await widget.apiService.createPaletteType(paletteType);
        } else {
          await widget.apiService
              .updatePaletteType(widget.paletteType!.id!, paletteType);
        }
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.paletteType == null
            ? 'Neuen Palette-Typ anlegen'
            : 'Palette-Typ bearbeiten'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _lhmNummerController,
                decoration: const InputDecoration(labelText: 'LHM-Nummer'),
                validator: (value) => null,
              ),
              TextFormField(
                controller: _materialController,
                decoration: const InputDecoration(labelText: 'Material'),
                validator: (value) => null,
              ),
              TextFormField(
                controller: _debitorController,
                decoration: const InputDecoration(labelText: 'Debitor'),
                validator: (value) => null,
              ),
              TextFormField(
                controller: _bezeichnungController,
                decoration: const InputDecoration(labelText: 'Bezeichnung'),
                validator: (value) => null,
              ),
              TextFormField(
                controller: _hoeheMmController,
                decoration: const InputDecoration(labelText: 'Höhe mm'),
                keyboardType: TextInputType.number,
                validator: (value) => null,
              ),
              TextFormField(
                controller: _stapelfaehigkeitController,
                decoration: const InputDecoration(labelText: 'Stapelfähigkeit'),
                validator: (value) => null,
              ),
              TextFormField(
                controller: _breiteMmController,
                decoration: const InputDecoration(labelText: 'Breite mm'),
                keyboardType: TextInputType.number,
                validator: (value) => null,
              ),
              TextFormField(
                controller: _laengeMmController,
                decoration: const InputDecoration(labelText: 'Länge mm'),
                keyboardType: TextInputType.number,
                validator: (value) => null,
              ),
              TextFormField(
                controller: _platzbedarfController,
                decoration: const InputDecoration(labelText: 'Platzbedarf'),
                keyboardType: TextInputType.number,
                validator: (value) => null,
              ),
              TextFormField(
                controller: _bruttogewichtController,
                decoration: const InputDecoration(labelText: 'Bruttogewicht'),
                keyboardType: TextInputType.number,
                validator: (value) => null,
              ),
              TextFormField(
                controller: _gewichtseinheitController,
                decoration: const InputDecoration(labelText: 'Gewichtseinheit'),
                validator: (value) => null,
              ),
              TextFormField(
                controller: _buchungsKzController,
                decoration: const InputDecoration(labelText: 'Buchungs-KZ'),
                validator: (value) => null,
              ),
              TextFormField(
                controller: _lhmKuehneNagelController,
                decoration:
                    const InputDecoration(labelText: 'LHM Kuehne & Nagel'),
                validator: (value) => null,
              ),
              TextFormField(
                controller: _globalInventoryController,
                decoration: const InputDecoration(labelText: 'Gesamtmenge'),
                keyboardType: TextInputType.number,
                validator: (value) => null,
              ),
              TextFormField(
                controller: _minAvailableController,
                decoration:
                    const InputDecoration(labelText: 'Minimale Verfügbarkeit'),
                keyboardType: TextInputType.number,
                validator: (value) => null,
              ),
              const SizedBox(height: 20),
              _photoPath != null && _photoPath!.isNotEmpty
                  ? Image.file(
                      File(_photoPath!),
                      height: 150,
                    )
                  : Container(
                      height: 150,
                      color: Colors.grey[300],
                      child: const Center(child: Text('Kein Bild ausgewählt')),
                    ),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Bild auswählen'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

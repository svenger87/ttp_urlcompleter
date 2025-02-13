// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/api_service.dart';

class CustomerFormScreen extends StatefulWidget {
  final ApiService apiService;
  final Customer? customer;

  const CustomerFormScreen(
      {super.key, required this.apiService, this.customer});

  @override
  _CustomerFormScreenState createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _stadtController;
  late TextEditingController _postleitzahlController;
  late TextEditingController _strasseController;
  late TextEditingController _bundeslandController;
  late TextEditingController _landController;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _nameController = TextEditingController(text: customer?.name ?? '');
    _stadtController = TextEditingController(text: customer?.stadt ?? '');
    _postleitzahlController =
        TextEditingController(text: customer?.postleitzahl ?? '');
    _strasseController = TextEditingController(text: customer?.strasse ?? '');
    _bundeslandController =
        TextEditingController(text: customer?.bundesland ?? '');
    _landController = TextEditingController(text: customer?.land ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stadtController.dispose();
    _postleitzahlController.dispose();
    _strasseController.dispose();
    _bundeslandController.dispose();
    _landController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final customer = Customer(
        id: widget.customer?.id,
        name: _nameController.text,
        stadt: _stadtController.text,
        postleitzahl: _postleitzahlController.text,
        strasse: _strasseController.text,
        bundesland: _bundeslandController.text,
        land: _landController.text,
      );
      try {
        if (widget.customer == null) {
          await widget.apiService.createCustomer(customer);
        } else {
          await widget.apiService
              .updateCustomer(widget.customer!.id!, customer);
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
        title: Text(widget.customer == null
            ? 'Neuen Kunden anlegen'
            : 'Kunde bearbeiten'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Pflichtfeld' : null,
              ),
              TextFormField(
                controller: _stadtController,
                decoration: const InputDecoration(labelText: 'Stadt'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Pflichtfeld' : null,
              ),
              TextFormField(
                controller: _postleitzahlController,
                decoration: const InputDecoration(labelText: 'Postleitzahl'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Pflichtfeld' : null,
              ),
              TextFormField(
                controller: _strasseController,
                decoration: const InputDecoration(labelText: 'Strasse'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Pflichtfeld' : null,
              ),
              TextFormField(
                controller: _bundeslandController,
                decoration: const InputDecoration(labelText: 'Bundesland'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Pflichtfeld' : null,
              ),
              TextFormField(
                controller: _landController,
                decoration: const InputDecoration(labelText: 'Land'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Pflichtfeld' : null,
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

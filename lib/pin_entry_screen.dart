import 'package:flutter/material.dart';

class PinEntryScreen extends StatefulWidget {
  final Function(String) onSubmit;

  const PinEntryScreen({Key? key, required this.onSubmit}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _PinEntryScreenState createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _submitPin() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(_pinController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF104382),
        title: const Text('PIN eingeben'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte PIN eingeben';
                  }
                  if (value.length != 4) {
                    return 'Die PIN hat 4 Stellen';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF104382),
                ),
                child: const Text(
                  'Bestätigen',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

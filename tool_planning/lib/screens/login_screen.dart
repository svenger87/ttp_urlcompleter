// lib/screens/login_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      // Invalid input, return early
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call the authentication API
      await ApiService.authenticateUser(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (kDebugMode) {
        print('Login successful');
      }

      // Pop the LoginScreen and return true to indicate success
      if (!mounted) return; // Ensure the widget is still in the widget tree
      Navigator.of(context).pop(true);
    } catch (e) {
      // Display a user-friendly error message
      String errorMessage =
          'Login fehlgeschlagen. Bitte überprüfen Sie Ihre Anmeldedaten.';
      if (kDebugMode) {
        // In debug mode, show the actual error
        errorMessage = 'Login fehlgeschlagen: $e';
        print('Error during login: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ActiveCollab Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                    labelText: 'Benutzername oder E-Mail'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie Ihren Benutzernamen oder Ihre E-Mail ein.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Passwort'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte geben Sie Ihr Passwort ein.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      child: const Text('Anmelden'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

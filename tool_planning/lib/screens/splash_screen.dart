// screens/splash_screen.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    String? sessionToken = await ApiService.getSessionToken();

    if (sessionToken == null) {
      // Navigate to login screen
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // User is authenticated, proceed to home screen
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // You can show a simple loading indicator while checking authentication
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

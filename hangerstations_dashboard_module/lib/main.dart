import 'package:flutter/material.dart';
import './screens/hangerstations_dashboard_module.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const Dashboard(), // Set Dashboard as the home screen
    );
  }
}

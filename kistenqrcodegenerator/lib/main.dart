// lib/main.dart

import 'package:flutter/material.dart';
import 'pages/qrcode_generator_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kisten QR Code Generator',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const QrCodeGeneratorPage(),
    );
  }
}

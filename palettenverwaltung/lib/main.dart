import 'package:flutter/material.dart';
import 'package:palettenverwaltung/shared/theme.dart';
import 'package:palettenverwaltung/pallet_module.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palettenverwaltung',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      // If you want to automatically switch based on system theme:
      // themeMode: ThemeMode.system,
      home: const PalletModule(),
    );
  }
}

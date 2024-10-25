import 'package:flutter/material.dart';
import 'screens/number_input_page.dart';
import 'shared/theme.dart'; // Import the unified theme

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTP App',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.system, // Use system theme (light/dark)
      home: const NumberInputPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

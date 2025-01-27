// lib/main.dart

import 'package:flutter/material.dart';
import 'screens/einfahr_planer_screen.dart';
import 'constants/constants.dart'; // Import if needed for theme colors

void main() {
  runApp(const ToolPlanningApp());
}

class ToolPlanningApp extends StatelessWidget {
  const ToolPlanningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tool Planning',
      theme: ThemeData.light(), // Define light theme (optional)
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: primaryColor, // Override primary color if needed
        scaffoldBackgroundColor: Colors.grey[900], // Dark background
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white, // White title text
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Define other theme properties as needed
      ),
      themeMode: ThemeMode.dark, // Always use dark theme
      home: const EinfahrPlanerScreen(),
    );
  }
}

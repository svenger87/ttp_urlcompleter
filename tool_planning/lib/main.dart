import 'package:flutter/material.dart';
import 'screens/tool_planning_screen.dart';
import 'screens/login_screen.dart'; // Import the LoginScreen

void main() {
  runApp(const ToolPlanningApp());
}

class ToolPlanningApp extends StatelessWidget {
  const ToolPlanningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tool Planning Module',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF104382),
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F0F0), // Light background
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF104382),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(
            color: Colors.white, // AppBar icon color
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(
                0xFF104382), // Text color for TextButton in light mode
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, // Text color for ElevatedButton
            backgroundColor: const Color(0xFF104382), // Button background color
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(
                0xFF104382), // Text color for OutlinedButton in light mode
            side: const BorderSide(
                color: Color(0xFF104382)), // Border color for OutlinedButton
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF104382), // Global icon color in light mode
        ),
        textTheme: const TextTheme(
          bodyMedium:
              TextStyle(color: Colors.black87), // Body text color in light mode
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF104382),
        scaffoldBackgroundColor: const Color(0xFF303030), // Dark background
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF104382),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor:
                Colors.white, // Text color for TextButton in dark mode
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, // Text color for ElevatedButton
            backgroundColor: const Color(0xFF104382), // Button background color
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor:
                Colors.white, // Text color for OutlinedButton in dark mode
            side: const BorderSide(
                color: Colors
                    .white), // Border color for OutlinedButton in dark mode
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white, // Global icon color in dark mode
        ),
        textTheme: const TextTheme(
          bodyMedium:
              TextStyle(color: Colors.white70), // Body text color in dark mode
        ),
      ),
      themeMode: ThemeMode.system, // Use system theme (light/dark)
      home: const ToolPlanningScreen(), // Start directly with the main screen
      routes: {
        '/login': (context) => const LoginScreen(), // Add the LoginScreen route
        // Add other routes if necessary
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

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
        primaryColor: const Color(0xFF104382),
        primarySwatch: Colors.blue,
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
            foregroundColor: Colors.white, // Text color for TextButton
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
                const Color(0xFF104382), // Text color for OutlinedButton
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white, // Global icon color
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF104382),
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
            foregroundColor: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF104382),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
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

import 'package:flutter/material.dart';
import 'screens/tool_planning_screen.dart';
import 'screens/login_screen.dart';
import 'shared/theme.dart';

void main() {
  runApp(const ToolPlanningApp());
}

class ToolPlanningApp extends StatelessWidget {
  const ToolPlanningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tool Planning Module',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.system, // Use system theme (light/dark)
      home: const ToolPlanningScreen(), // Start directly with the main screen
      routes: {
        '/login': (context) => const LoginScreen(), // Add the LoginScreen route
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

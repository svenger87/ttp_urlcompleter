// lib/main.dart

import 'package:flutter/material.dart';
import 'screens/tool_planning_screen.dart'; // Your existing ToolPlanning
import 'screens/login_screen.dart'; // If you have a login screen
import 'shared/theme.dart'; // Your custom themes, if any

void main() {
  runApp(const ToolPlanningApp());
}

class ToolPlanningApp extends StatelessWidget {
  const ToolPlanningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tool Planning Module',
      theme: appLightTheme, // or your own theme
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/', // Start at Home (which has the drawer)
      routes: {
        '/': (context) => const HomeScreen(), // The drawer scaffold
        '/tool-planning': (context) => const ToolPlanningScreen(),
        '/login': (context) => const LoginScreen(), // If used
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

/// The home screen that just wraps a Drawer for navigation.
/// It can immediately push '/tool-planning' or anything else.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Menu'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Navigation Menu',
                  style: TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Tool Planning'),
              onTap: () {
                Navigator.pop(context); // close drawer
                Navigator.pushNamed(context, '/tool-planning');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Einfahr Planer'),
              onTap: () {
                Navigator.pop(context); // close drawer
                Navigator.pushNamed(context, '/einfahr-planer');
              },
            ),
            // Add more nav items as needed
          ],
        ),
      ),
      body: const Center(
        child: Text(
          'Welcome! Use the Drawer menu to navigate.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

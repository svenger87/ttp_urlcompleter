// main.dart

import 'package:flutter/material.dart';
import 'screens/production_orders_screen.dart'; // Import the new screen
import 'widgets/app_drawer.dart'; // Import your drawer widget

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final appLightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xFF104382),
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: const Color(0xFFF0F0F0),
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
        foregroundColor: Color(0xFF104382),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Color(0xFF104382),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Color(0xFF104382),
        side: const BorderSide(color: Color(0xFF104382)),
      ),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF104382),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.black87),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App Name',
      theme: appLightTheme,
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/production-orders': (context) => ProductionOrdersScreen(),
        // Add other routes if necessary
      },
    );
  }
}

// Your existing HomeScreen
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(), // Reference to your drawer widget
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Center(
        child: Text('Home Screen'),
      ),
    );
  }
}

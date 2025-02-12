// tools_main_screen.dart
import 'package:flutter/material.dart';
import 'tool_inventory_screen.dart';
import '../widgets/tool_forecast_wrapper.dart';
import 'storage_utilization_screen.dart';

class ToolsMainScreen extends StatefulWidget {
  const ToolsMainScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<ToolsMainScreen> {
  int _currentIndex = 0;

  // Create all three screens once and store them in a list.
  final List<Widget> _screens = const [
    ToolInventoryScreen(), // Inventory screen (PIN is requested only once)
    ToolForecastWrapper(), // Forecast screen
    StorageUtilizationScreen() // Storage Utilization screen
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use IndexedStack to keep the state of each screen.
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (newIndex) {
          setState(() {
            _currentIndex = newIndex;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Werkzeuginventar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pending_actions),
            label: 'Bereitstellungsvorschau',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storage),
            label: 'Werkzeuglagerauslastung',
          ),
        ],
      ),
    );
  }
}

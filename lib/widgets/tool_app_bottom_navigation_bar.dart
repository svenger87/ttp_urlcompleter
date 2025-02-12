// app_bottom_navigation_bar.dart
import 'package:flutter/material.dart';
import '../widgets/tool_forecast_wrapper.dart';
import '../screens/tool_inventory_screen.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  const AppBottomNavigationBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == currentIndex) return;
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ToolInventoryScreen()),
            );
            break;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ToolForecastWrapper()),
            );
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory),
          label: 'Werkzeuginventar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.pending_actions),
          label: 'Bereitstellungsorschau',
        ),
      ],
    );
  }
}

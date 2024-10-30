// app_drawer.dart

import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // Drawer Header
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF104382),
            ),
            child: Text(
              'Your App Name',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          // Home Navigation
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          // Production Orders Navigation
          ListTile(
            leading: const Icon(Icons.production_quantity_limits),
            title: const Text('Kartonfertigungsaufträge'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushNamed(context, '/production-orders');
            },
          ),
          // Add other drawer items here
        ],
      ),
    );
  }
}

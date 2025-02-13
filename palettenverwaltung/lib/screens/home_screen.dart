import 'package:flutter/material.dart';
import 'pallet_overview_screen.dart';
import 'customer_management_screen.dart';
import 'palette_type_management_screen.dart';
import 'scan_screen.dart';
import '../services/api_service.dart';
import 'package:palettenverwaltung/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService(baseUrl: baseApiUrl);

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const PalletOverviewScreen(),
      CustomerManagementScreen(apiService: _apiService),
      PaletteTypeManagementScreen(apiService: _apiService),
      const ScanScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Titles for each tab if you want them to change dynamically
    final titles = [
      'Übersicht',
      'Kunden',
      'Paletten-Typen',
      'Scan',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Übersicht',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Kunden',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Paletten-Typen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
        ],
      ),
    );
  }
}

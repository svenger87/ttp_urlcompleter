// storage_utilization_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StorageUtilizationScreen extends StatefulWidget {
  const StorageUtilizationScreen({super.key});

  @override
  _StorageUtilizationScreenState createState() =>
      _StorageUtilizationScreenState();
}

class _StorageUtilizationScreenState extends State<StorageUtilizationScreen> {
  int _maxCapacity = 0;
  int _usedCapacity = 0;
  int _freeCapacity = 0;
  double _usagePercentage = 0.0;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    try {
      final response = await http.get(
        Uri.parse('http://wim-solution.sip.local:3000/storage-utilization'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _maxCapacity =
              double.tryParse(data['maxCapacity'].toString())?.toInt() ?? 0;
          _freeCapacity =
              double.tryParse(data['freeCapacity'].toString())?.toInt() ?? 0;
          _usedCapacity =
              double.tryParse(data['usedCapacity'].toString())?.toInt() ?? 0;
          _usagePercentage =
              double.tryParse(data['usagePercentage'].toString()) ?? 0.0;
          _isLoading = false;
        });

        if (kDebugMode) {
          print('Max Capacity: $_maxCapacity');
          print('Free Capacity: $_freeCapacity');
          print('Used Capacity: $_usedCapacity');
          print('Usage Percentage: $_usagePercentage%');
        }
      } else {
        if (kDebugMode) {
          print('Error: ${response.statusCode}');
        }
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception: $e');
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use the same AppBar style as other screens
      appBar: AppBar(
        title: const Text('Lagerauslastung'),
        backgroundColor: const Color(0xFF104382),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      // No bottomNavigationBar here—it's handled by the main container.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? const Center(child: Text('Error loading storage data'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCapacityInfo(
                          'Maximale Lagerplätze:', _maxCapacity.toString()),
                      _buildCapacityInfo(
                          'Belegte Lagerplätze:', _usedCapacity.toString()),
                      _buildCapacityInfo(
                          'Freie Lagerplätze:', _freeCapacity.toString()),
                      _buildCapacityInfo('Prozentuale Auslastung:',
                          '${_usagePercentage.toStringAsFixed(2)}%'),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: _usagePercentage / 100,
                        minHeight: 20,
                        backgroundColor: Colors.grey[300],
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCapacityInfo(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

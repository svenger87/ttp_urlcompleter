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
      // Fetch and parse the data
      final allStoragesResponse = await http
          .get(Uri.parse('http://wim-solution.sip.local:3000/all-storages'));
      final freeStoragesResponse = await http
          .get(Uri.parse('http://wim-solution.sip.local:3000/free-storages'));

      if (allStoragesResponse.statusCode == 200 &&
          freeStoragesResponse.statusCode == 200) {
        // Parse the 'all-storages' response as List<String>
        final List<String> allStorages = List<String>.from(
          json.decode(allStoragesResponse.body),
        );

        // Debug print for allStorages
        print('allStorages: $allStorages');
        print('Total items in allStorages: ${allStorages.length}');

        // Parse the 'free-storages' response as List<String>
        final List<String> freeStorages = List<String>.from(
          json.decode(freeStoragesResponse.body),
        );

        // Debug print for freeStorages
        print('freeStorages: $freeStorages');
        print('Total items in freeStorages: ${freeStorages.length}');

        // Calculate capacities
        final int freeCapacity =
            freeStorages.where((item) => allStorages.contains(item)).length;
        final int usedCapacity = allStorages.length - freeCapacity;

        // Update the state
        setState(() {
          _maxCapacity = allStorages.length;
          _freeCapacity = freeCapacity;
          _usedCapacity = usedCapacity;
          _usagePercentage =
              _maxCapacity > 0 ? (_usedCapacity / _maxCapacity) * 100 : 0.0;
          _isLoading = false;
        });

        // Print the results
        print('Max Capacity: $_maxCapacity');
        print('Free Capacity: $_freeCapacity');
        print('Used Capacity: $_usedCapacity');
        print('Usage Percentage: $_usagePercentage%');
      } else {
        // Handle non-200 responses
        print(
            'Error: ${allStoragesResponse.statusCode}, ${freeStoragesResponse.statusCode}');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      // Catch and print any exceptions
      print('Exception: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lagerauslastung'),
        backgroundColor: const Color(0xFF104382),
      ),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
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

// tool_forecast_wrapper.dart
import 'package:flutter/material.dart';
import '../services/tool_service.dart';
import '../screens/tool_forecast_screen.dart';

class ToolForecastWrapper extends StatefulWidget {
  const ToolForecastWrapper({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ToolForecastWrapperState createState() => _ToolForecastWrapperState();
}

class _ToolForecastWrapperState extends State<ToolForecastWrapper> {
  final ToolService toolService = ToolService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>>? _forecastData;
  List<Map<String, dynamic>>? _ordersData;
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    try {
      // Fetch forecast data from /tool-forecast
      final forecastResponse = await toolService.fetchToolForecast();
      // Fetch all orders (unfiltered) from /all-orders
      final ordersResponse = await toolService.fetchAllOrders();

      setState(() {
        _forecastData =
            List<Map<String, dynamic>>.from(forecastResponse['data']);
        _lastUpdated = forecastResponse['lastUpdated'];
        _ordersData = List<Map<String, dynamic>>.from(ordersResponse['orders']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Fehler beim Laden der Werkzeugbereitstellungsvorhersage: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Werkzeugvorschau${_lastUpdated != null ? ' (Letzte Aktualisierung: $_lastUpdated)' : ''}',
        ),
        backgroundColor: const Color(0xFF104382),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : ToolForecastScreen(
                  forecastData: _forecastData!,
                  ordersData: _ordersData!,
                  lastUpdated: _lastUpdated!,
                ),
    );
  }
}

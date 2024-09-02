// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/tool_service.dart';

class FreeStoragesScreen extends StatefulWidget {
  const FreeStoragesScreen({super.key});

  @override
  _FreeStoragesScreenState createState() => _FreeStoragesScreenState();
}

class _FreeStoragesScreenState extends State<FreeStoragesScreen> {
  List<String> _freeStorages = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadFreeStorages();
  }

  Future<void> _loadFreeStorages() async {
    try {
      final storages = await ToolService().fetchFreeStorages();
      setState(() {
        _freeStorages = storages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load free storages')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freie Lagerplätze'),
        backgroundColor: const Color(0xFF104382),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? const Center(child: Text('Error loading free storages'))
              : ListView.builder(
                  itemCount: _freeStorages.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_freeStorages[index]),
                      onTap: () {
                        Navigator.pop(context, _freeStorages[index]);
                      },
                    );
                  },
                ),
    );
  }
}

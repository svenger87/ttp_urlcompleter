// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'pin_entry_screen.dart'; // Import the PIN entry screen

class TorsteuerungModule extends StatefulWidget {
  final String initialUrl;

  const TorsteuerungModule({Key? key, required this.initialUrl})
      : super(key: key);

  @override
  _TorsteuerungModuleState createState() => _TorsteuerungModuleState();
}

class _TorsteuerungModuleState extends State<TorsteuerungModule> {
  final String correctPin = '1958'; // Define the correct PIN
  final String doorControlUrl = 'http://10.152.10.52:3000/relay?relay=1';
  final String videoStreamUrl =
      'http://synonvr-ttp:8080/memfs/51866bc4-758c-44e2-8349-82a84ffa6a47.m3u8';

  late VideoPlayerController _videoController;
  bool _isDoorOpening = false;
  bool _isPinVerified = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(videoStreamUrl)
      ..initialize().then((_) {
        setState(() {});
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _verifyPin(String pin) {
    if (pin == correctPin) {
      setState(() {
        _isPinVerified = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falsche PIN')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPinVerified) {
      return PinEntryScreen(onSubmit: _verifyPin);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF104382),
        title: const Text('Torsteuerung'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                top: 50.0,
                bottom: 0.0), // Adjust top and bottom padding as needed
            child: Container(
              width: double.infinity, // Full width by default
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0), // Horizontal padding for the button
              child: ElevatedButton(
                onPressed: _isDoorOpening ? null : () => _toggleDoor(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF104382), // Background color
                ),
                child: _isDoorOpening
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Tor öffnen/schließen',
                        style: TextStyle(color: Colors.white), // Text color
                      ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                  top: 16.0,
                  bottom: 16.0), // Adjust top and bottom padding as needed
              child: Center(
                child: AspectRatio(
                  aspectRatio: _videoController.value.aspectRatio,
                  child: VideoPlayer(_videoController),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleDoor(BuildContext context) async {
    setState(() {
      _isDoorOpening = true;
    });

    try {
      final response = await http.get(Uri.parse(doorControlUrl));
      if (kDebugMode) {
        print('Requested URL: ${Uri.parse(doorControlUrl)}');
      }
      if (kDebugMode) {
        print('Response status code: ${response.statusCode}');
      }
      if (kDebugMode) {
        print('Response body: ${response.body}');
      }

      // Handle response based on status code
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tor öffnet/schließt')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehlgeschlagen!')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling door: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler!')),
      );
    } finally {
      setState(() {
        _isDoorOpening = false;
      });
    }
  }
}

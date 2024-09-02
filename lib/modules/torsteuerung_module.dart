// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../screens/pin_entry_screen.dart';
import 'package:video_player_win/video_player_win.dart';

class TorsteuerungModule extends StatefulWidget {
  final String initialUrl;

  const TorsteuerungModule({Key? key, required this.initialUrl})
      : super(key: key);

  @override
  _TorsteuerungModuleState createState() => _TorsteuerungModuleState();
}

class _TorsteuerungModuleState extends State<TorsteuerungModule> {
  final String correctPin = '1958'; // Define the correct PIN
  final String openDoorUrl =
      'http://10.152.200.9/relay?relay=1'; // URL for opening
  final String closeDoorUrl =
      'http://10.152.200.9/relay?relay=2'; // URL for closing
  final String videoStreamUrl =
      'http://synonvr-ttp:8080/memfs/51866bc4-758c-44e2-8349-82a84ffa6a47.m3u8';

  VideoPlayerController? _videoController;
  WinVideoPlayerController? _winVideoController;
  bool _isDoorActionInProgress = false;
  bool _isPinVerified = false;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoController();
  }

  void _initializeVideoController() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _winVideoController = WinVideoPlayerController.network(videoStreamUrl);
      _winVideoController!.initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        if (mounted) {
          _winVideoController!.play();
        }
      }).catchError((error) {
        if (kDebugMode) {
          print('Error initializing WinVideoPlayerController: $error');
        }
        // Handle error as needed, e.g., show an error message
        setState(() {
          _isVideoInitialized = true; // Set this to true to proceed
        });
      });
    } else {
      _videoController = VideoPlayerController.network(videoStreamUrl);
      _videoController!.initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        if (mounted) {
          _videoController!.play();
        }
      }).catchError((error) {
        if (kDebugMode) {
          print('Error initializing VideoPlayerController: $error');
        }
        // Handle error as needed, e.g., show an error message
        setState(() {
          _isVideoInitialized = true; // Set this to true to proceed
        });
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _winVideoController?.dispose();
    super.dispose();
  }

  void _verifyPin(String pin) {
    if (pin == correctPin) {
      setState(() {
        _isPinVerified = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVideoInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isPinVerified) {
      return PinEntryScreen(onSubmit: _verifyPin);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF104382),
        title: const Text('Torsteuerung Module'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 50.0, bottom: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isDoorActionInProgress
                      ? null
                      : () => _toggleDoor(openDoorUrl, 'Tor öffnet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF104382),
                  ),
                  child: _isDoorActionInProgress
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
                          'Tor öffnen',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
                ElevatedButton(
                  onPressed: _isDoorActionInProgress
                      ? null
                      : () => _toggleDoor(closeDoorUrl, 'Tor schließt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF104382),
                  ),
                  child: _isDoorActionInProgress
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
                          'Tor schließen',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
              child: Center(
                child: AspectRatio(
                  aspectRatio: defaultTargetPlatform == TargetPlatform.windows
                      ? _winVideoController!.value.aspectRatio
                      : _videoController!.value.aspectRatio,
                  child: defaultTargetPlatform == TargetPlatform.windows
                      ? WinVideoPlayer(_winVideoController!)
                      : VideoPlayer(_videoController!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleDoor(String url, String actionMessage) async {
    setState(() {
      _isDoorActionInProgress = true;
    });

    try {
      final response = await http
          .put(Uri.parse(url))
          .timeout(const Duration(seconds: 15)); // Timeout for the request

      if (kDebugMode) {
        print('Requested URL: $url');
        print('Response status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(actionMessage)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehlgeschlagen!')),
        );
      }
    } on TimeoutException catch (_) {
      if (kDebugMode) {
        print('Request to $url timed out.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Zeitüberschreitung beim Öffnen/Schließen des Tores')),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Fehler beim öffnen/schließen des Tores: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler!')),
      );
    } finally {
      setState(() {
        _isDoorActionInProgress = false;
      });
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/number_input_page.dart';
import 'shared/theme.dart'; // Import the unified theme
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform; // Import Platform for desktop detection

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if the platform is desktop (Windows, macOS, Linux)
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    // Initialize window_manager
    await windowManager.ensureInitialized();

    // Define window options
    WindowOptions windowOptions = WindowOptions(
      size: Size(800, 600), // Initial size; can be adjusted
      center: true, // Centers the window on the screen
      title: "TTP App", // Window title
      backgroundColor: Colors.transparent, // Optional: Transparent background
      skipTaskbar: false, // Show in taskbar
      titleBarStyle: TitleBarStyle.normal, // Normal title bar
    );

    // Apply the window options and maximize the window when ready
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show(); // Show the window
      await windowManager.maximize(); // Maximize the window
      await windowManager.focus(); // Focus on the window
    });
  }

  // Run the Flutter application
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTP App',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.system, // Use system theme (light/dark)
      home: const NumberInputPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

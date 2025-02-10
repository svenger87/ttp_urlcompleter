// lib/main.dart

// For Platform detection
import 'package:flutter/material.dart';
// For kIsWeb
import 'package:window_manager/window_manager.dart';
import 'screens/einfahr_planer_screen.dart';
import 'constants/constants.dart'; // Import if needed for theme colors

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Force fullscreen window options
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1920, 1080), // Fullscreen resolution
    center: true,
    title: "Einfahr Planer",
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  // Configure and show the window
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setFullScreen(true); // Force fullscreen mode
  });

  // Force `isStandalone` to true as this is a standalone configuration
  const bool isStandalone = true;

  runApp(const ToolPlanningApp(isStandalone: isStandalone));
}

class ToolPlanningApp extends StatelessWidget {
  final bool isStandalone;

  const ToolPlanningApp({super.key, required this.isStandalone});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tool Planning',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const EinfahrPlanerScreen(
        isFullscreen: true, // Force fullscreen
        isStandalone: true, // Force standalone mode
      ),
    );
  }
}

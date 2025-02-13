import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:palettenverwaltung/shared/theme.dart';

/// Das zentrale Widget, das das Palettenverwaltungsmodul kapselt.
class PalletModule extends StatelessWidget {
  const PalletModule({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palettenverwaltung',
      // Apply the custom themes
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      // If you want automatic switching between light/dark mode:
      // themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

/// Stand-Alone App-Einstiegspunkt, der dasselbe Modul lädt.
class PalletModuleApp extends StatelessWidget {
  const PalletModuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const PalletModule();
  }
}
